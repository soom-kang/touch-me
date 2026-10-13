"""Execute real packaging scripts in isolated copies; never invoke Apple tools.

Run: python3 -m unittest discover -s Tests/PackagingTests -v
The mock image and executable are intentionally not installable artifacts.
"""
import contextlib
import hashlib
import io
import pathlib
import plistlib
import runpy
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = pathlib.Path(__file__).resolve().parents[2]


class PackagingTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="touch-me-packaging-test-")
        self.addCleanup(self.temp.cleanup)
        self.root = pathlib.Path(self.temp.name).resolve()
        shutil.copytree(ROOT / "scripts", self.root / "scripts")
        for name in ("VERSION", "LICENSE"):
            shutil.copy2(ROOT / name, self.root / name)
        self.binary = self.root / "TouchMe"
        self.binary.write_bytes(b"NOT a Mach-O: packaging test fixture")
        self.app = self.root / "dist" / "Touch Me.app"
        self.native_calls = []
        self.image_bytes = b"NOT a DMG: test fixture"
        self.certificate_bytes = b"NOT a certificate: packaging fixture"
        self.identity = hashlib.sha1(self.certificate_bytes).hexdigest()
        self.certificate_digest = hashlib.sha256(self.certificate_bytes).hexdigest()
        self.keychain = self.root / "fixture.keychain"
        self.keychain.write_bytes(b"NOT a Keychain: packaging fixture")
        self.certificate_signed = False
        self.requirement_override = None
        self.ignored_certificate_signing = False

    def native(self, command, **kwargs):
        self.native_calls.append(command)
        stdout = stderr = ""
        if command[0] == "ditto":
            shutil.copytree(command[1], command[2])
        elif command[0] == "hdiutil":
            pathlib.Path(command[-1]).write_bytes(self.image_bytes)
        elif command[0] == "codesign":
            if "--sign" in command:
                self.certificate_signed = (command[command.index("--sign") + 1] != "-"
                                           and not self.ignored_certificate_signing)
            elif "--display" in command:
                if self.certificate_signed:
                    prefix = next(arg.split("=", 1)[1] for arg in command
                                  if arg.startswith("--extract-certificates="))
                    pathlib.Path(prefix + "0").write_bytes(self.certificate_bytes)
                    stdout = (self.requirement_override or
                              'designated => identifier "io.github.soom-kang.touchme" '
                              f'and certificate leaf = H"{self.identity}"\n')
                    stderr = "Signature size=1024\nAuthority=Packaging test fixture\n"
                else:
                    stdout = 'designated => cdhash H"' + "0" * 40 + '"\n'
                    stderr = "Signature=adhoc\n"
        else:
            raise AssertionError(f"Unexpected native command: {command[0]}")
        return subprocess.CompletedProcess(command, 0, stdout=stdout, stderr=stderr)

    def run_script(self, name, *, architecture="arm64", native=None, arguments=()):
        script = self.root / "scripts" / name
        args = [str(script)] + ([str(self.binary)] if name == "bundle-app.py" else [])
        args.extend(arguments)
        with patch.object(sys, "argv", args), \
             patch("subprocess.run", side_effect=native or self.native), \
             patch("subprocess.check_output", return_value=architecture), \
             contextlib.redirect_stdout(io.StringIO()), \
             contextlib.redirect_stderr(io.StringIO()):
            runpy.run_path(str(script), run_name="__main__")

    def bundle(self, arguments=()):
        self.run_script("bundle-app.py", arguments=arguments)

    def signing_arguments(self, identity=None):
        return ["--signing-mode", "self-signed", "--signing-identity", identity or self.identity,
                "--keychain", str(self.keychain)]

    def info(self):
        return plistlib.loads((self.app / "Contents" / "Info.plist").read_bytes())

    def test_release_version_contract(self):
        for version in ("0.8.0-beta.1", "1.2.3", "0.0.0", "2.0.0-rc.1"):
            with self.subTest(version=version):
                (self.root / "VERSION").write_text(version)
                self.bundle()
                self.assertEqual(self.info()["TouchMeReleaseVersion"], version)
                self.assertEqual(self.info()["CFBundleShortVersionString"], version.split("-")[0])

    def test_invalid_versions_fail_before_native_commands(self):
        for version in ("", "01.2.3", "1.02.3", "1.2.03", "1.2", "v1.2.3",
                        "1.2.3-beta.01", "1.2.3-01", "1.2.3-", "../other"):
            with self.subTest(version=version):
                (self.root / "VERSION").write_text(version)
                with self.assertRaisesRegex(SystemExit, "VERSION must contain"):
                    self.bundle()
        self.assertEqual(self.native_calls, [])

    def test_missing_executable(self):
        self.binary.unlink()
        with self.assertRaisesRegex(SystemExit, "Release executable is missing"):
            self.bundle()
        self.assertEqual(self.native_calls, [])

    def test_missing_license(self):
        (self.root / "LICENSE").unlink()
        with self.assertRaisesRegex(SystemExit, "License file is missing"):
            self.bundle()

    def test_bundle_metadata_and_history(self):
        self.bundle()
        info = self.info()
        self.assertEqual(info["CFBundleIdentifier"], "io.github.soom-kang.touchme")
        self.assertEqual(info["LSMinimumSystemVersion"], "26.0")
        self.assertEqual(info["CFBundleLocalizations"], ["ko", "en"])
        self.assertEqual(info["CFBundleVersion"], "1")
        self.bundle()
        self.assertEqual(self.info()["CFBundleVersion"], "2")
        self.assertEqual(len(list((self.root / "dist" / "previous-builds").glob("*.app"))), 1)

    def test_sign_failure_preserves_existing_app(self):
        self.bundle()
        before = (self.app / "Contents" / "Info.plist").read_bytes()
        def fail(command, **kwargs):
            raise subprocess.CalledProcessError(1, command)
        for arguments in ((), self.signing_arguments()):
            with self.subTest(arguments=arguments), self.assertRaises(subprocess.CalledProcessError):
                self.run_script("bundle-app.py", native=fail, arguments=arguments)
            self.assertEqual((self.app / "Contents" / "Info.plist").read_bytes(), before)

    def test_self_signed_identity_selection(self):
        self.bundle(self.signing_arguments())
        signing = next(call for call in self.native_calls if "--sign" in call)
        self.assertEqual(signing[signing.index("--sign") + 1], self.identity)
        self.assertEqual(signing[signing.index("--keychain") + 1], str(self.keychain))
        self.assertIn("--timestamp=none", signing)
        self.assertTrue(self.app.is_dir())

    def test_self_signed_arguments_rejected_before_signing(self):
        cases = (["--signing-mode", "self-signed"],
                 self.signing_arguments("Certificate display name"),
                 self.signing_arguments()[:-1] + ["relative.keychain"],
                 self.signing_arguments()[:-1] + [str(self.root / "missing.keychain")])
        for arguments in cases:
            with self.subTest(arguments=arguments), self.assertRaises(SystemExit):
                self.bundle(arguments)
        self.assertEqual(self.native_calls, [])

    def test_self_signed_identity_mismatch_preserves_existing_app(self):
        self.bundle()
        before = (self.app / "Contents" / "Info.plist").read_bytes()
        for failure in ("certificate", "requirement", "ad_hoc_fallback"):
            with self.subTest(failure=failure):
                self.requirement_override = ('designated => identifier "io.github.soom-kang.touchme"\n'
                                             if failure == "requirement" else None)
                self.ignored_certificate_signing = failure == "ad_hoc_fallback"
                arguments = self.signing_arguments("0" * 40 if failure == "certificate" else None)
                with self.assertRaises(SystemExit):
                    self.bundle(arguments)
                self.assertEqual((self.app / "Contents" / "Info.plist").read_bytes(), before)

    def test_install_notes_and_package_certificate_pin(self):
        self.bundle()
        self.run_script("package-dmg.py")
        ad_hoc_notes = next((self.root / ".build/dmg").glob("*/contents/Install.txt")).read_text()
        self.assertIn("Ad hoc beta", ad_hoc_notes)
        image = next((self.root / "dist").glob("*.dmg"))
        before = (image.read_bytes(), image.with_suffix(".dmg.sha256").read_bytes())
        self.bundle(self.signing_arguments())
        for arguments in ((), ["--expected-certificate", "0" * 64]):
            with self.subTest(arguments=arguments), self.assertRaises(SystemExit):
                self.run_script("package-dmg.py", arguments=arguments)
            self.assertEqual((image.read_bytes(), image.with_suffix(".dmg.sha256").read_bytes()), before)
        self.run_script("package-dmg.py", arguments=["--expected-certificate", self.certificate_digest])
        signed_notes = next(path.read_text() for path in (self.root / ".build/dmg").glob("*/contents/Install.txt")
                            if "Ad hoc beta" not in path.read_text())
        self.assertIn(self.certificate_digest, signed_notes)
        self.assertIn("Developer ID", signed_notes)
        self.bundle()
        with self.assertRaises(SystemExit):
            self.run_script("package-dmg.py", arguments=["--expected-certificate", self.certificate_digest])

    def test_package_checksum_and_applications_link(self):
        import hashlib
        self.bundle()
        self.run_script("package-dmg.py")
        image = next((self.root / "dist").glob("*.dmg"))
        self.assertEqual(image.with_suffix(".dmg.sha256").read_text(),
                         f"{hashlib.sha256(image.read_bytes()).hexdigest()}  {image.name}\n")
        link = next((self.root / ".build" / "dmg").glob("*/contents/Applications"))
        self.assertTrue(link.is_symlink())
        self.assertEqual(str(link.readlink()), "/Applications")
        previous_image = image.read_bytes()
        previous_sidecar = image.with_suffix(".dmg.sha256").read_bytes()
        self.image_bytes = b"NOT a DMG: second fixture version"
        self.run_script("package-dmg.py")
        self.assertNotEqual(image.read_bytes(), previous_image)
        self.assertEqual(image.with_suffix(".dmg.sha256").read_text(),
                         f"{hashlib.sha256(image.read_bytes()).hexdigest()}  {image.name}\n")
        archives = list((self.root / "dist" / "previous-builds").iterdir())
        self.assertEqual(len(archives), 1)
        archived_image = archives[0] / image.name
        archived_sidecar = archived_image.with_suffix(".dmg.sha256")
        self.assertEqual(archived_image.read_bytes(), previous_image)
        self.assertEqual(archived_sidecar.read_bytes(), previous_sidecar)
        self.assertEqual(archived_sidecar.read_text(),
                         f"{hashlib.sha256(archived_image.read_bytes()).hexdigest()}  {archived_image.name}\n")

    def test_non_arm64_architecture_rejected(self):
        self.bundle()
        for architecture in ("x86_64", "x86_64 arm64", ""):
            with self.subTest(architecture=architecture), self.assertRaisesRegex(SystemExit, "arm64 app only"):
                self.run_script("package-dmg.py", architecture=architecture)
        self.assertFalse(list((self.root / "dist").glob("*.dmg")))

    def test_stale_version_rejected(self):
        self.bundle()
        (self.root / "VERSION").write_text("999.0.0")
        with self.assertRaisesRegex(SystemExit, "does not match VERSION"):
            self.run_script("package-dmg.py")

    def test_modified_license_rejected(self):
        self.bundle()
        (self.app / "Contents" / "Resources" / "Licenses.txt").write_text("changed")
        with self.assertRaisesRegex(SystemExit, "does not match LICENSE"):
            self.run_script("package-dmg.py")

    def test_missing_license_resource_rejected(self):
        self.bundle()
        (self.app / "Contents" / "Resources" / "Licenses.txt").unlink()
        with self.assertRaisesRegex(SystemExit, "missing its project license"):
            self.run_script("package-dmg.py")

    def test_wrong_identity_rejected(self):
        self.bundle()
        info = self.info()
        info["CFBundleIdentifier"] = "invalid.fixture"
        (self.app / "Contents" / "Info.plist").write_bytes(plistlib.dumps(info))
        with self.assertRaisesRegex(SystemExit, "expected Touch Me app is missing"):
            self.run_script("package-dmg.py")

    def test_clean_checkout_package_has_actionable_error(self):
        with self.assertRaisesRegex(SystemExit, "run bash scripts/build-app.sh"):
            self.run_script("package-dmg.py")
        self.assertEqual(self.native_calls, [])

    def test_missing_plist_has_actionable_error(self):
        self.bundle()
        (self.app / "Contents" / "Info.plist").unlink()
        self.native_calls.clear()
        with self.assertRaisesRegex(SystemExit, "run bash scripts/build-app.sh"):
            self.run_script("package-dmg.py")
        self.assertEqual(self.native_calls, [])

    def test_malformed_plist_has_actionable_error(self):
        self.bundle()
        info = self.app / "Contents" / "Info.plist"
        for contents in (b"not a plist", b"<?xml version='1.0'?><plist><dict>"):
            with self.subTest(contents=contents):
                info.write_bytes(contents)
                self.native_calls.clear()
                with self.assertRaisesRegex(SystemExit, "rebuild with bash scripts/build-app.sh"):
                    self.run_script("package-dmg.py")
                self.assertEqual(self.native_calls, [])

    def test_non_dictionary_plist_has_actionable_error(self):
        self.bundle()
        (self.app / "Contents" / "Info.plist").write_bytes(plistlib.dumps(["invalid root"]))
        self.native_calls.clear()
        with self.assertRaisesRegex(SystemExit, "must contain a dictionary"):
            self.run_script("package-dmg.py")
        self.assertEqual(self.native_calls, [])

    def test_unreadable_plist_preserves_existing_image(self):
        self.bundle()
        info = self.app / "Contents" / "Info.plist"
        previous = self.root / "dist" / "previous.dmg"
        previous.write_bytes(b"preserve this artifact")
        original_open = pathlib.Path.open
        def guarded_open(path, *args, **kwargs):
            if path == info:
                raise PermissionError("fixture denied read")
            return original_open(path, *args, **kwargs)
        self.native_calls.clear()
        with patch.object(pathlib.Path, "open", guarded_open), \
             self.assertRaisesRegex(SystemExit, "rebuild with bash scripts/build-app.sh"):
            self.run_script("package-dmg.py")
        self.assertEqual(self.native_calls, [])
        self.assertEqual(previous.read_bytes(), b"preserve this artifact")

    def test_dmg_failure_preserves_existing_artifact(self):
        self.bundle()
        self.run_script("package-dmg.py")
        image = next((self.root / "dist").glob("*.dmg"))
        before = image.read_bytes()
        def fail(command, **kwargs):
            if command[0] == "hdiutil":
                raise subprocess.CalledProcessError(1, command)
            return self.native(command, **kwargs)
        with self.assertRaises(subprocess.CalledProcessError):
            self.run_script("package-dmg.py", native=fail)
        self.assertEqual(image.read_bytes(), before)

    def test_staged_checksum_failure_preserves_existing_pair(self):
        self.bundle()
        self.run_script("package-dmg.py")
        image = next((self.root / "dist").glob("*.dmg"))
        sidecar = image.with_suffix(".dmg.sha256")
        before = (image.read_bytes(), sidecar.read_bytes())
        self.image_bytes = b"NOT a DMG: second fixture version"
        original_write = pathlib.Path.write_text

        def denied_checksum(path, *args, **kwargs):
            if path.name == sidecar.name and path != sidecar:
                raise PermissionError("fixture: staged checksum denied")
            return original_write(path, *args, **kwargs)

        with patch.object(pathlib.Path, "write_text", denied_checksum), \
             self.assertRaisesRegex(SystemExit, "Cannot prepare the staged DMG checksum"):
            self.run_script("package-dmg.py")
        self.assertEqual((image.read_bytes(), sidecar.read_bytes()), before)
        self.assertFalse((self.root / "dist" / "previous-builds").exists())

    def test_finalization_rename_failures_restore_existing_pair(self):
        self.bundle()
        self.run_script("package-dmg.py")
        image = next((self.root / "dist").glob("*.dmg"))
        sidecar = image.with_suffix(".dmg.sha256")
        before = (image.read_bytes(), sidecar.read_bytes())
        self.image_bytes = b"NOT a DMG: second fixture version"
        original_rename = pathlib.Path.rename
        history = self.root / "dist" / "previous-builds"

        for boundary in ("archive_sidecar", "archive_image", "promote_image", "promote_sidecar"):
            with self.subTest(boundary=boundary):
                failed = False

                def denied_rename(path, target):
                    nonlocal failed
                    target = pathlib.Path(target)
                    matches = {
                        "archive_sidecar": path == sidecar and target.parent.parent == history,
                        "archive_image": path == image and target.parent.parent == history,
                        "promote_image": target == image and path != image,
                        "promote_sidecar": target == sidecar and path != sidecar,
                    }[boundary]
                    if matches and not failed:
                        failed = True
                        raise PermissionError(f"fixture: {boundary} denied")
                    return original_rename(path, target)

                with patch.object(pathlib.Path, "rename", denied_rename), \
                     self.assertRaisesRegex(SystemExit, "previous output state was restored"):
                    self.run_script("package-dmg.py")
                self.assertTrue(failed)
                self.assertEqual((image.read_bytes(), sidecar.read_bytes()), before)

    def test_incomplete_or_mismatched_previous_pair_is_preserved(self):
        self.bundle()
        self.run_script("package-dmg.py")
        image = next((self.root / "dist").glob("*.dmg"))
        sidecar = image.with_suffix(".dmg.sha256")
        original_pair = (image.read_bytes(), sidecar.read_bytes())

        for state in ("missing_sidecar", "missing_image", "mismatched_checksum"):
            with self.subTest(state=state):
                image.write_bytes(original_pair[0])
                sidecar.write_bytes(original_pair[1])
                if state == "missing_sidecar":
                    sidecar.unlink()
                elif state == "missing_image":
                    image.unlink()
                else:
                    sidecar.write_text(f"{'0' * 64}  {image.name}\n")
                before = tuple(path.read_bytes() if path.exists() else None for path in (image, sidecar))
                self.native_calls.clear()
                with self.assertRaisesRegex(SystemExit, "Cannot replace the previous DMG/checksum pair"):
                    self.run_script("package-dmg.py")
                after = tuple(path.read_bytes() if path.exists() else None for path in (image, sidecar))
                self.assertEqual(after, before)
                self.assertEqual(self.native_calls, [])
                self.assertFalse((self.root / "dist" / "previous-builds").exists())

    def test_rollback_failure_preserves_files_and_reports_recovery_paths(self):
        self.bundle()
        self.run_script("package-dmg.py")
        image = next((self.root / "dist").glob("*.dmg"))
        sidecar = image.with_suffix(".dmg.sha256")
        previous_pair = (image.read_bytes(), sidecar.read_bytes())
        self.image_bytes = b"NOT a DMG: second fixture version"
        original_rename = pathlib.Path.rename
        staging_root = self.root / ".build" / "dmg"
        promotion_failed = False
        rollback_failed = False

        def denied_rename(path, target):
            nonlocal promotion_failed, rollback_failed
            target = pathlib.Path(target)
            if target == sidecar and path.parent.parent == staging_root:
                promotion_failed = True
                raise PermissionError("fixture: sidecar promotion denied")
            if promotion_failed and path == image and target.parent.parent == staging_root:
                rollback_failed = True
                raise PermissionError("fixture: image rollback denied")
            return original_rename(path, target)

        with patch.object(pathlib.Path, "rename", denied_rename), \
             self.assertRaisesRegex(SystemExit, "Rollback failed") as raised:
            self.run_script("package-dmg.py")
        self.assertTrue(promotion_failed and rollback_failed)
        archive = next((self.root / "dist" / "previous-builds").iterdir())
        staged_image = pathlib.Path(next(call[-1] for call in reversed(self.native_calls) if call[0] == "hdiutil"))
        self.assertEqual((archive / image.name).read_bytes(), previous_pair[0])
        self.assertEqual((archive / sidecar.name).read_bytes(), previous_pair[1])
        self.assertEqual(image.read_bytes(), self.image_bytes)
        self.assertFalse(sidecar.exists())
        self.assertTrue(staged_image.with_suffix(".dmg.sha256").is_file())
        for path in (image, sidecar, archive, staged_image.parent):
            self.assertIn(str(path), str(raised.exception))


if __name__ == "__main__":
    unittest.main()
