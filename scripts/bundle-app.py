#!/usr/bin/env python3
"""Bundle the local executable with ad hoc or a pinned signing certificate."""
import argparse
import hashlib
import plistlib
import re
import shutil
import subprocess
import uuid
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("executable", nargs="?", help="Release executable; defaults to the existing build locations")
parser.add_argument("--signing-mode", choices=("ad-hoc", "self-signed"), default="ad-hoc")
parser.add_argument("--signing-identity", help="Exact 40-character certificate SHA-1 fingerprint for codesign")
parser.add_argument("--keychain", help="Absolute path to the existing dedicated signing Keychain")
args = parser.parse_args()
if args.signing_mode == "self-signed":
    if not args.signing_identity or not re.fullmatch(r"[0-9a-fA-F]{40}", args.signing_identity):
        parser.error("self-signed mode requires --signing-identity with exactly 40 hexadecimal characters")
    if not args.keychain or not Path(args.keychain).is_absolute() or not Path(args.keychain).is_file():
        parser.error("self-signed mode requires --keychain with an absolute path to an existing file")
    args.signing_identity = args.signing_identity.lower()
elif args.signing_identity is not None or args.keychain is not None:
    parser.error("--signing-identity and --keychain require --signing-mode self-signed")


def read_release_version():
    try:
        version = (ROOT / "VERSION").read_text(encoding="utf-8").strip()
    except OSError as error:
        raise SystemExit(f"Cannot read VERSION: {error}") from error
    match = re.fullmatch(r"(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(?:-([0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*))?", version)
    if match is None or any(part.isdigit() and len(part) > 1 and part.startswith("0")
                            for part in (match.group(4) or "").split(".")):
        raise SystemExit("VERSION must contain x.y.z or x.y.z-prerelease without numeric leading zeros")
    return version, ".".join(match.group(index) for index in (1, 2, 3))


RELEASE_VERSION, SHORT_VERSION = read_release_version()
APP = ROOT / "dist" / "Touch Me.app"
STAGING_APP = ROOT / ".build" / "bundles" / str(uuid.uuid4()) / "Touch Me.app"
if args.executable:
    EXECUTABLE = Path(args.executable).resolve()
else:
    candidates = [ROOT / ".build" / "out" / "Products" / "Release" / "TouchMe",
                  ROOT / ".build" / "arm64-apple-macosx" / "release" / "TouchMe"]
    EXECUTABLE = next((p for p in candidates if p.is_file()), candidates[0])
if not EXECUTABLE.is_file():
    raise SystemExit("Release executable is missing; run bash scripts/build-app.sh")

license_files = [ROOT / "LICENSE"]
for path in license_files:
    if not path.is_file():
        raise SystemExit(f"License file is missing: {path.name}")
license_text = "\n\n".join(path.read_text(encoding="utf-8").rstrip() for path in license_files) + "\n"

binary_dir = STAGING_APP / "Contents" / "MacOS"
resources = STAGING_APP / "Contents" / "Resources"
binary_dir.mkdir(parents=True, exist_ok=True)
resources.mkdir(parents=True, exist_ok=True)
shutil.copy2(EXECUTABLE, binary_dir / "TouchMe")
icon = ROOT / "Resources" / "TouchMe.icns"
if icon.is_file():
    shutil.copy2(icon, resources / icon.name)
build_number = 1
previous_info = APP / "Contents" / "Info.plist"
if previous_info.is_file():
    with previous_info.open("rb") as stream:
        previous = plistlib.load(stream)
    build_number = int(previous.get("CFBundleVersion", "0")) + 1
info = {
    "CFBundleName": "Touch Me",
    "CFBundleDisplayName": "Touch Me",
    "CFBundleExecutable": "TouchMe",
    "CFBundleIdentifier": "io.github.soom-kang.touchme",
    "CFBundlePackageType": "APPL",
    "CFBundleShortVersionString": SHORT_VERSION,
    "TouchMeReleaseVersion": RELEASE_VERSION,
    "CFBundleVersion": str(build_number),
    "CFBundleDevelopmentRegion": "en",
    "CFBundleLocalizations": ["ko", "en"],
    "LSMinimumSystemVersion": "26.0",
    "LSUIElement": True,
    "NSHighResolutionCapable": True,
}
if icon.is_file():
    info["CFBundleIconFile"] = icon.name
with (STAGING_APP / "Contents" / "Info.plist").open("wb") as stream:
    plistlib.dump(info, stream, sort_keys=True)
(resources / "Licenses.txt").write_text(license_text, encoding="utf-8")
sign_command = ["codesign", "--sign", args.signing_identity or "-",
                "--identifier", info["CFBundleIdentifier"]]
if args.signing_mode == "self-signed":
    sign_command.extend(["--keychain", args.keychain, "--timestamp=none"])
subprocess.run(sign_command + [str(STAGING_APP)], check=True)
subprocess.run(["codesign", "--verify", "--strict", str(STAGING_APP)], check=True)
if args.signing_mode == "self-signed":
    prefix = STAGING_APP.parent / "signing-certificate-"
    signature = subprocess.run(
        ["codesign", "--display", "--verbose=4", "--requirements", "-",
         "--extract-certificates=" + str(prefix), str(STAGING_APP)],
        check=True, capture_output=True, text=True)
    try:
        certificate = Path(str(prefix) + "0").read_bytes()
    except OSError as error:
        raise SystemExit(f"Cannot read the embedded signing certificate; existing app was preserved: {error}") from error
    if hashlib.sha1(certificate).hexdigest() != args.signing_identity:
        raise SystemExit("The embedded signing certificate does not match --signing-identity; existing app was preserved")
    requirement = re.fullmatch(
        r'designated => identifier "' + re.escape(info["CFBundleIdentifier"]) +
        r'" and certificate leaf = H"([0-9a-fA-F]{40})"', signature.stdout.strip())
    if ("Signature=adhoc" in signature.stderr or requirement is None or
            requirement.group(1).lower() != args.signing_identity):
        raise SystemExit("Expected the default identifier-and-certificate requirement; existing app was preserved")
    print(f"Signing certificate SHA-256: {hashlib.sha256(certificate).hexdigest()}")
APP.parent.mkdir(parents=True, exist_ok=True)
if APP.exists():
    history = APP.parent / "previous-builds"
    history.mkdir(exist_ok=True)
    APP.rename(history / ("Touch Me-" + str(uuid.uuid4()) + ".app"))
STAGING_APP.rename(APP)
print(f"Built local app: {APP}")
