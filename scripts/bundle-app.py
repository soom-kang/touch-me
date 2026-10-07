#!/usr/bin/env python3
"""Bundle the local executable. No credentials or external dependencies."""
import plistlib
import re
import shutil
import subprocess
import sys
import uuid
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


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
if len(sys.argv) > 1:
    EXECUTABLE = Path(sys.argv[1]).resolve()
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
# Ad hoc signing is local packaging only; it does not prove public distribution.
subprocess.run(["codesign", "--sign", "-", "--identifier", info["CFBundleIdentifier"], str(STAGING_APP)], check=True)
subprocess.run(["codesign", "--verify", "--strict", str(STAGING_APP)], check=True)
APP.parent.mkdir(parents=True, exist_ok=True)
if APP.exists():
    history = APP.parent / "previous-builds"
    history.mkdir(exist_ok=True)
    APP.rename(history / ("Touch Me-" + str(uuid.uuid4()) + ".app"))
STAGING_APP.rename(APP)
print(f"Built local app: {APP}")
