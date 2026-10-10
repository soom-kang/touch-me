#!/usr/bin/env python3
"""Package the local app and installation notes. No publishing or credentials."""
from pathlib import Path
from xml.parsers.expat import ExpatError
import hashlib
import plistlib
import re
import subprocess
import uuid

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


VERSION, SHORT_VERSION = read_release_version()
APP = ROOT / "dist" / "Touch Me.app"
OUTPUT = ROOT / "dist" / f"touch-me-{VERSION}-arm64.dmg"
WORK = ROOT / ".build" / "dmg" / str(uuid.uuid4())
STAGING = WORK / "contents"
IMAGE = WORK / OUTPUT.name

try:
    with (APP / "Contents" / "Info.plist").open("rb") as stream:
        info = plistlib.load(stream)
except FileNotFoundError as error:
    raise SystemExit("Release app metadata is missing; run bash scripts/build-app.sh") from error
except (OSError, plistlib.InvalidFileException, ValueError, ExpatError) as error:
    raise SystemExit(f"Cannot read valid app Info.plist; rebuild with bash scripts/build-app.sh: {error}") from error
if not isinstance(info, dict):
    raise SystemExit("App Info.plist must contain a dictionary; rebuild with bash scripts/build-app.sh")
if info.get("CFBundleIdentifier") != "io.github.soom-kang.touchme":
    raise SystemExit("The expected Touch Me app is missing; run bash scripts/build-app.sh")
if info.get("TouchMeReleaseVersion") != VERSION or info.get("CFBundleShortVersionString") != SHORT_VERSION:
    raise SystemExit(f"The app does not match VERSION {VERSION}; run bash scripts/build-app.sh")
license_resource = APP / "Contents" / "Resources" / "Licenses.txt"
if not license_resource.is_file():
    raise SystemExit("The app is missing its project license; rebuild the app")
if license_resource.read_text(encoding="utf-8") != (ROOT / "LICENSE").read_text(encoding="utf-8").rstrip() + "\n":
    raise SystemExit("The app's project license does not match LICENSE; rebuild the app")
subprocess.run(["codesign", "--verify", "--strict", str(APP)], check=True)
architecture = subprocess.check_output(["lipo", "-archs", str(APP / "Contents" / "MacOS" / "TouchMe")], text=True).strip()
if architecture != "arm64":
    raise SystemExit("This personal image is for the arm64 app only")

STAGING.mkdir(parents=True)
subprocess.run(["ditto", str(APP), str(STAGING / "Touch Me.app")], check=True)
(STAGING / "Applications").symlink_to("/Applications")
(STAGING / "Install.txt").write_text(f"""Touch Me {VERSION} · Ad hoc beta candidate

1. Drag Touch Me.app to Applications, eject the image, and open the installed app.
   macOS may block this ad hoc build. If you trust the source, follow Apple's
   approval procedure in System Settings > Privacy & Security > Open Anyway:
   https://support.apple.com/en-us/102445
2. Allow Touch Me in System Settings > Privacy & Security > Input Monitoring
   and Accessibility.
3. Stop other touch mappers and connect the P16KT by USB-C.
4. Select its display and open the test window on the P16KT.
5. Confirm the target and start mapping.

English is the default app language. Select English or 한국어 with the Language
picker at the top of settings. The choice applies immediately and is saved.

Use one finger to tap or drag and two fingers to scroll vertically or horizontally.
Quitting while running preserves the intent to resume on next launch.
Resume requires the saved display, USB location and both permissions to match.
A pending mode change is restored only on its verified continuous attachment.
If both recorded HID/USB services have ended on the same boot and ownership is
verified, the app can preserve the old record without writing its mode to a new
connection. This archive does not confirm restoration of the old mode.
During the same app run, reconnecting the single supported panel at the saved
USB location and display can resume mapping after fresh device and safety checks.
A freshly read (0,0) permits automatic Start. (2,0) requires informed manual Start;
Stop then keeps that current mode. Uncertain recovery or record handling blocks
mapping and remains visible in settings.
Stop stays stopped. Launch at login is off by default.
Use the same USB port for the saved panel; confirm the target after changing ports.

Before updating, stop mapping and quit normally. If restoration or record
handling blocks Quit, stop the update and preserve the app and recovery records.
For a restoration failure on the current continuous attachment, keep the panel
connected and use Retry restore. The same USB port alone does not authorize an
old-mode write on a new connection.
To uninstall, disable launch at login, stop mapping, quit, and move the app to Trash.
Resolve pending restoration or record handling before quitting or removing it.
This beta uses ad hoc signing without a Developer ID signature or Apple
notarization. macOS may require first-launch approval and renewed privacy
permissions after an update. Check both permissions before starting mapping.
Open License in the app menu to read the project MIT license.

Touch Me {VERSION} · Ad hoc beta 후보

1. Touch Me.app을 Applications로 끌어 복사합니다.
2. DMG를 추출하고 Applications에서 Touch Me를 엽니다.
   macOS가 ad hoc 빌드 실행을 차단할 수 있습니다. 출처를 신뢰하는 경우
   시스템 설정 > 개인정보 보호 및 보안 > 확인 없이 열기에서 Apple의 승인
   절차를 따릅니다: https://support.apple.com/en-us/102445
3. 시스템 설정의 입력 모니터링과 손쉬운 사용에서 Touch Me를 허용합니다.
4. 다른 터치 매핑 프로그램을 중지하고 P16KT를 USB-C로 연결합니다.
5. 대상 화면을 선택하고 시험 창이 P16KT에 표시되는지 확인한 뒤 매핑을 시작합니다.

앱의 기본 언어는 영어입니다. 설정 상단의 Language에서 English 또는 한국어를
선택합니다. 선택은 즉시 적용되며 다음 실행에도 유지됩니다.

한 손가락으로 탭·드래그하고 두 손가락으로 위아래·좌우 스크롤합니다.
실행 중 종료하면 다음 실행에서 재개할 의도를 저장합니다.
저장한 화면·USB 위치가 일치하고 두 권한이 허용돼야 재개합니다.
남은 모드 변경은 확인한 동일 연속 연결에서만 원복합니다.
같은 부팅에서 기록된 HID/USB 서비스가 모두 종료되고 소유권이 확인되면
옛 기록을 보존할 수 있습니다. 옛 모드를 새 연결에 쓰지 않으며,
기록 보존이 옛 모드의 원복을 확인했다는 뜻은 아닙니다.
같은 앱 실행 중 지원 패널 한 대를 저장한 USB 위치와 화면에 다시 연결하면
장치와 안전 조건을 새로 확인한 뒤 매핑을 재개할 수 있습니다.
새로 읽은 모드가 (0,0)이면 자동 시작합니다. (2,0)이면 안내를 확인하고 직접
시작해야 하며 중지 후에도 현재 모드를 유지합니다.
복구나 기록 처리가 불확실하면 매핑을 차단하고 설정에 이유를 표시합니다.
중지하면 중지 상태를 유지합니다.
로그인 시작은 기본 off이며 설정에서 켜거나 끌 수 있습니다.
저장한 P16KT는 같은 USB 포트에 연결하세요. 포트를 바꾸면 화면을 다시 확인하고 시작하세요.

업데이트 전에 매핑을 중지하고 정상 종료합니다. 복구나 기록 처리로 종료가
막히면 업데이트를 중단하고 앱과 복구 기록을 보존합니다.
현재 연속 연결의 원복에 실패하면 연결을 유지한 채 ‘복구 재시도’를 누릅니다.
같은 USB 포트에 돌아왔다는 이유만으로 옛 모드를 새 연결에 쓰지 않습니다.
삭제할 때는 로그인 시작을 끄고 매핑을 중지한 뒤 앱을 종료하고 휴지통으로 옮깁니다.
이 beta는 Developer ID 서명과 Apple 공증 없이 ad hoc 서명을 사용합니다.
macOS의 첫 실행 승인과 업데이트 후 권한 재승인이 필요할 수 있습니다.
매핑을 시작하기 전에 두 권한을 확인하세요.
남은 원복이나 기록 처리를 해결한 뒤 종료하거나 삭제합니다.
프로젝트 MIT 라이선스는 앱 메뉴의 ‘라이선스’에서 확인합니다.
""", encoding="utf-8")
subprocess.run(["hdiutil", "create", "-volname", "Touch Me", "-srcfolder", str(STAGING),
                "-format", "UDZO", "-fs", "HFS+", str(IMAGE)], check=True)
if OUTPUT.exists():
    history = OUTPUT.parent / "previous-builds"
    history.mkdir(exist_ok=True)
    OUTPUT.rename(history / f"touch-me-{VERSION}-{uuid.uuid4()}.dmg")
IMAGE.rename(OUTPUT)
checksum = hashlib.sha256()
with OUTPUT.open("rb") as stream:
    for chunk in iter(lambda: stream.read(1024 * 1024), b""):
        checksum.update(chunk)
digest = checksum.hexdigest()
OUTPUT.with_suffix(".dmg.sha256").write_text(f"{digest}  {OUTPUT.name}\n", encoding="utf-8")
print(f"Built local beta DMG: {OUTPUT}")
