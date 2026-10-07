"""Execute real packaging scripts in isolated copies; never invoke Apple tools.

Run: python3 -m unittest discover -s Tests/PackagingTests -v
The mock image and executable are intentionally not installable artifacts.
"""
import contextlib
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

    def native(self, command, **kwargs):
        self.native_calls.append(command)
        if command[0] == "ditto":
            shutil.copytree(command[1], command[2])
        elif command[0] == "hdiutil":
            pathlib.Path(command[-1]).write_bytes(b"NOT a DMG: test fixture")
        elif command[0] != "codesign":
            raise AssertionError(f"Unexpected native command: {command[0]}")
        return subprocess.CompletedProcess(command, 0)

    def run_script(self, name, *, architecture="arm64", native=None):
        script = self.root / "scripts" / name
        args = [str(script)] + ([str(self.binary)] if name == "bundle-app.py" else [])
        with patch.object(sys, "argv", args), \
             patch("subprocess.run", side_effect=native or self.native), \
             patch("subprocess.check_output", return_value=architecture), \
             contextlib.redirect_stdout(io.StringIO()):
            runpy.run_path(str(script), run_name="__main__")

    def bundle(self):
        self.run_script("bundle-app.py")

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
        with self.assertRaises(subprocess.CalledProcessError):
            self.run_script("bundle-app.py", native=fail)
        self.assertEqual((self.app / "Contents" / "Info.plist").read_bytes(), before)

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


if __name__ == "__main__":
    unittest.main()
