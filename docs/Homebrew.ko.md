[English](Homebrew.md) · [한국어](Homebrew.ko.md) · [개발 Workflow](../Workflow.ko.md) · [앱 사용 안내](../README.ko.md)

# Touch Me Homebrew beta 배포

Beta.7과 기존 Tap 갱신을 공개하고 확인했습니다. 로컬 앱 설치와 upgrade는
이번 공개 범위 밖입니다. Beta.6와 이전 배포 기록은 아래에
보존합니다.

## Beta.7 release 준비 — 2026-10-10

상태는 **PUBLISHED**입니다. Prerelease `v0.8.0-beta.7`을 2026-10-10
14:25:14 KST(05:25:14 UTC)에 build 25와
`touch-me-0.8.0-beta.7-arm64.dmg`·`.sha256` 파일로 공개했습니다. 이번 작업은
public release와 기존 Tap만 갱신하며 설치 앱과 환경설정은 보존합니다.

Source의 Swift tests 37개와 개발 build 24 USB-C cycle
(`PASS_USER_REPORTED`)을 재사용합니다. 실행 파일 hash는
[Workflow](../Workflow.ko.md#usb-c-재연결-후보--2026-10-10)에 보존합니다.
새 build 25 GUI·실기기, 설치·upgrade·Gatekeeper는 `NOT_RUN`입니다.

1. 생성할 `Install.txt`를 포함해 beta.7 metadata와 양언어 문서를 확정합니다.
   빌드·패키징을 각각 한 번 수행하고 기존 packaging tests 18개를 실행합니다.
   Release 입력을 동결하고 번들 metadata·서명·라이선스·아이콘, arm64,
   DMG 무결성·sidecar와 읽기 전용 mount 내부 identity를 확인합니다.
2. 검토한 source·tag·prerelease를 공개하며 이전 asset을 대치하지 않습니다.
   익명 public DMG·sidecar의 bytes·hash·내부 metadata를 동결한 후보와
   비교한 뒤 Tap을 변경합니다.
3. 실제 `Casks/touch-me.rb`, beta.7 정확한 버전의 prerelease allowlist와
   Tap 양언어 안내를 갱신합니다. Cask Ruby syntax·style을 통과해야 하며
   공개한 Tap revision과 asset 식별 일치를 확인합니다.

Online audit는 승인한 보류에 따라 **BLOCKED**입니다. 기존 trust를 유지하고
trust 설정이나 우회 환경변수를 바꾸지 않습니다. 이번 범위에서
`brew audit --cask --online soom-kang/touch-me/touch-me`를 실행하거나 beta.6의
과거 audit PASS를 beta.7 결과로 사용하지 않습니다. 필수 asset·Cask 검사 통과
후 이 예외를 기록한 상태로 공개 작업을 마칠 수 있습니다. 로컬 빌드·패키징과
packaging tests 18개, 실제 Cask syntax·style은 통과했습니다(파일 1개, offenses 없음).
Source·tag commit `f8210f4318f726c9943db1de7fa82e634d132a10`과 frozen inputs
28개가 일치합니다. 익명 public DMG·sidecar raw bytes·크기·digest와 checksum
내용이 동결한 release와 일치합니다. DMG는 524,843 bytes이며 SHA-256은
`74bf81ff7e7d1a0a1966146022b7e60841451897fee25a2dbe1449b31113da90`입니다.
2026-10-10 14:28:27 KST(05:28:27 UTC) checkpoint에서 공개 Tap·별도 clone·설치된
Tap은 모두 `7c07d4967e94e0591229410f8952bb49c2b7e102`와 일치했습니다. 설치된
Tap은 `3c3ab9e`에서 clean fast-forward를 마쳤습니다. 파일 4개가 공개 clone과
일치하며 Cask는 source template과 일치합니다. 앱 설치·upgrade나 trust 변경은
없었습니다. 실제 결과는
[beta.7 release notes](releases/v0.8.0-beta.7.md)에 기록합니다.
아래 beta.4 명령은 과거 예시로 보존합니다.

## 로컬 USB-C 재연결 후보 — 2026-10-10

이 개발 snapshot은 beta.7 release 준비 전의 기록입니다. 재연결 source 변경은 공개 beta.6에 포함되지 않습니다. 완료한 개발 작업에서는 `VERSION`, release asset, Tap과 설치 앱 번들을 변경하지 않았습니다. 로컬 test·build 결과는 공개나 Homebrew acceptance와 구분해 [Workflow](../Workflow.ko.md#usb-c-재연결-후보--2026-10-10)에 기록합니다. 2026-10-10에 후보의 시작 → USB-C 분리·재연결 → 자동 재개 → 두 위치 탭 → 중지 1회가 `PASS_USER_REPORTED`로 승인한 로컬 acceptance 범위를 충족했습니다. 새 Homebrew 검증 결과는 아닙니다.

후보는 같은 부팅에서 정확히 기록된 HID와 USB 서비스가 모두 종료됐고 소유자 조건을 통과한 경우에만 이전 기록을 `disconnected-<nonce>.json`으로 보존합니다. Sync한 `reconnect-required.json`으로 재실행 후에도 새 모드 확인 조건을 유지합니다. 원래 `(2,0)`이라 모드 변경 기록이 없던 세션에도 이 조건을 적용합니다. 이는 원래 모드 복구를 확인하지 못한 기록이며 이전 모드 값을 새 연결에 쓰지 않습니다. `(0,0)`이면 안전 조건을 확인한 자동 시작을 허용하고 `(2,0)`이면 안내 후 직접 시작해야 합니다. 직접 시작 후 중지해도 현재 모드를 유지합니다.

현재 앱과 산출물을 보존하고 앱 전환에는 정상 종료를 사용하세요. 복구나 기록 처리 때문에 종료가 막히면 증거를 보존하고 전환 절차를 먼저 합의합니다. 별도로 승인한 기존 앱 종료 한 번과 로컬 후보 실행은 [Workflow](../Workflow.ko.md#usb-c-재연결-후보--2026-10-10)에 기록했으며 일반적인 강제 종료를 허용한 것은 아닙니다. Cask에는 기록 초기화, 강제 종료나 복구 hook이 없습니다. 업그레이드를 진행하려고 복구 기록을 삭제하지 마세요. 공개 beta.6의 연속 연결 복구 조건은 그대로이며 같은 포트 재연결로 우회할 수 없습니다.

## 공개한 beta.6 — 2026-10-09

Release source·tag `7a663f5bd70fcfc73d8b44ea78abeeb69ac4b40e`의 [beta.6 prerelease](https://github.com/soom-kang/touch-me/releases/tag/v0.8.0-beta.6)를 18:38:18 KST에 공개했습니다. Beta.5 이후 실행 코드 변경 없이 QA 완료 기록을 포함해 재배포합니다. 18:38:33 KST 익명 DMG·sidecar 확인에서 build 24의 455,405-byte 산출물과 [기록한 digest](releases/v0.8.0-beta.6.md)가 일치했습니다. Public·설치된 Tap revision은 `3c3ab9e95c3ad6991d7397fa6b436c2f46e5aa7f`이며 설치된 Tap은 clean하게 fast-forward했습니다. 실제 Cask Ruby syntax와 Homebrew style은 파일 한 개에서 offenses 없이 통과했습니다.

일반 `brew audit --cask --online soom-kang/touch-me/touch-me`는 `--new`나 검사 제외 없이 18:39:35 KST에 exit 0으로 통과했습니다. 기존 선택 Cask trust는 유지했으며 Tap 전체는 trusted 상태가 아닙니다. 설치된 beta.5 앱은 보존합니다. Beta.5 build 23 acceptance는 회귀 근거로만 인용합니다. Beta.6 설치·GUI·Gatekeeper·실기기 사용·Homebrew upgrade는 `NOT_RUN`입니다.

## 공개한 beta.5 — 2026-10-09

Source·tag `4ead3d1acec3beb43a1f09261b308ef9fdef0e81`의 [beta.5 prerelease](https://github.com/soom-kang/touch-me/releases/tag/v0.8.0-beta.5)를 공개했습니다. 익명 다운로드로 455,408-byte DMG·sidecar가 [build 23 digest](releases/v0.8.0-beta.5.md)와 일치한 것을 확인했습니다. Tap main과 설치된 Tap `31cdb32c1e1415401c26fd338842bf811471b531`은 clean이며 검토한 Cask와 일치합니다. Beta.4 asset은 보존했습니다.

공개 beta.4 → beta.5 업그레이드 단계는 성공했다고 출력됐고 Applications build 23의 실행 파일·서명·라이선스·아이콘이 일치했습니다. 이후 cleanup에서 작업 한정 `HOMEBREW_NO_INSTALL_FROM_API`로 예상 밖의 core clone이 시작됐습니다. 확인한 Homebrew PID를 16:48:57 KST에 중단했으며 업그레이드 성공 뒤 전체 command는 exit 130이었습니다. 자동 정리 후 core path·clone process가 없음을 확인했고 reset·untap은 필요하지 않았습니다.

QA01은 합의한 공개 업그레이드 범위에서 `PASS`입니다. 설치 build 23·두 권한·두 위치 탭·Stop/정상 Quit는 `PASS_USER_REPORTED`입니다. 18:03:47 KST에 TouchMe process·recovery record가 없었으며 18:04:26 KST의 새 읽기 전용 세션에서 같은 boot·HID/USB registry identity·location·descriptor의 현재 `(0,0)`이 사전 original/journal pair와 일치함을 관측했습니다. 이 세션은 arm→exit만 수행했고 feature writes 0, exit 0입니다. [Acceptance 기록](qa/beta5-native-acceptance.md)을 확인하세요.

## Beta.5 준비

### 과거 공개 전 checkpoint — 16:24 KST

2026-10-09 공개 전 기록은 **READY_FOR_RELEASE_REVIEW / NOT_PUBLISHED**입니다.
후보 `0.8.0-beta.5`, build 23의 source 컴파일, 집중 backend 검사 9개,
서명·metadata·라이선스·아이콘, 입력 비교 28개, DMG 무결성과 로컬 Cask·Tap
검사는 통과했습니다. 원래 모드 0·같은 부팅·계속 연결된 P16KT 조건에서
SIGKILL·재실행 한 번으로 이전 기록을 복구·삭제한 뒤 매핑을 재개했고,
Stop·Quit 후 `(0,0)`을 확인했습니다. 진단 feature write는 없었습니다.
정상 사용·재실행과 충돌 후 제스처는 `PASS_USER_REPORTED`입니다. 과거 build
22의 실패는 [acceptance 기록](qa/beta5-native-acceptance.md)에 보존합니다.

예정 tag는 `v0.8.0-beta.5`이며 asset은
`touch-me-0.8.0-beta.5-arm64.dmg`와 `.sha256` 파일입니다. Build 23의 산출물
식별과 엄격한 복구 정책은 [release notes](releases/v0.8.0-beta.5.md)에 있습니다.
로컬 Cask 초안만으로 공개 Tap이나 다운로드 가능 상태를 판정하지 않습니다.

검토·승인 뒤 다음 순서로 진행합니다:

1. Frozen compilation/package 입력과 release commit을 비교합니다. 기존 앱,
   환경설정, tag와 asset을 보존합니다.
2. 검토한 DMG·sidecar를 공개하고 다운로드한 bytes·내부 앱을 build 23 기록과
   비교합니다. 확인한 버전·checksum으로 기존 Tap을 갱신하며 과거 asset 대치나
   `:no_check`로 불일치를 우회하지 않습니다.
3. Beta.5 asset과 Tap 갱신 확인 후 아래 설치·업그레이드 안내를 사용합니다.
   Beta.4 → beta.5 공개 업그레이드 acceptance는 별도 기록하며 QA01은 열려 있고
   이 기록에서 해당 검사는 `NOT_RUN`입니다.

이 시점에는 release commit·push, tag, 공개와 Tap 갱신을 수행하지 않았습니다.
신규 설치·Gatekeeper, 권한 off/on, 잠금·절전, 실제 로그아웃·로그인, 제거와
더 넓은 crash/device recovery는 `NOT_RUN`입니다. 기존 권한을 유지하고 필요한
경우에만 재승인합니다. Retry 때 같은 연결을 유지하며 같은 포트 재연결만으로
journal 복구를 허용하지 않습니다.

## 과거 공개 beta.4 기준

| 항목 | 값 |
| --- | --- |
| Source repository | [soom-kang/touch-me](https://github.com/soom-kang/touch-me) |
| Tap repository | `soom-kang/homebrew-touch-me` |
| Tap / Cask token | `soom-kang/touch-me` / `touch-me` |
| Release 버전 / tag | `0.8.0-beta.4` / `v0.8.0-beta.4` |
| Asset | `touch-me-0.8.0-beta.4-arm64.dmg`과 `.sha256` 파일 |
| 앱 / 식별자 | `Touch Me.app` / `io.github.soom-kang.touchme` |
| 최소 환경 | Apple Silicon, macOS 26(Tahoe) 이상 |
| 장치 범위 | ZEUSLAP P16KT 한 대, USB `0x0457:0x0819`, 조건에 맞는 외부 화면 |
| 서명 | Ad hoc; Developer ID 서명과 notarization 없음 |
| 로컬 초안 / Tap 파일 | `packaging/homebrew/touch-me.rb.in` / `Casks/touch-me.rb` |

새 빌드의 release 버전은 `VERSION`에서 읽습니다. 공개 beta.4 번들에는 숫자 형식의 `CFBundleShortVersionString=0.8.0`, `CFBundleVersion=21`과 `TouchMeReleaseVersion=0.8.0-beta.4`를 기록했습니다. 앱 About과 설정에는 전체 release 버전을 표시합니다. [Apple 버전 형식](https://developer.apple.com/help/glossary/version-number/)

하나의 앱이 영어와 한국어를 포함합니다. 저장한 선택이 없으면 영어로 시작하고 설정에서 선택한 언어를 유지합니다. Cask에는 언어별 다운로드를 넣지 않습니다.

다음 versioned asset URL을 사용합니다:

```text
https://github.com/soom-kang/touch-me/releases/download/v0.8.0-beta.4/touch-me-0.8.0-beta.4-arm64.dmg
```

Cask의 SHA-256은 실제 업로드한 DMG와 일치해야 합니다. GitHub에서는 asset 대치가 가능하므로 공개한 버전의 파일을 대치하지 않는 원칙으로 관리하세요. 공개 후 source, 서명이나 DMG가 바뀌면 새 버전과 checksum을 사용합니다. 불일치를 `:no_check`로 우회하거나 기존 release asset을 대치하지 않습니다.

## 과거 beta.4 배포 절차

다음 페이즈는 beta.4 배포 기록과 당시 승인 범위를 보존합니다. 버전별 명령을 현재 source에서 실행하거나 과거 승인을 후보 acceptance 결과로 사용하지 마세요.

### Phase 0 — Source 확인과 변경 전 상태 보존

**입력:** source checkout, 인증한 GitHub 접근과 기존 산출물. 지침과 build scripts를 읽습니다. 변경 전에 Git 상태, 로컬·원격 revision, tag와 release를 확인합니다.

```bash
git status --short
git remote -v
git rev-parse HEAD
git ls-remote --heads --tags origin
gh repo view soom-kang/touch-me --json nameWithOwner,visibility,defaultBranchRef
gh release list --repo soom-kang/touch-me
```

**Beta.1 초기 사전 확인 기록:** 2026-10-07에 로컬 `main`이 `5e2520f7f3bacdd85507a383d0c08da3555a1c5d`에서 clean 상태였고 원격 `main`과 일치했습니다. Source repository는 public이었으며 release는 없었습니다. 예정한 Tap은 찾을 수 없다는 응답을 반환했습니다. 이는 beta.1 공개 전의 기록입니다.

**Beta.2 당시 시작 기준(2026-10-07):** source `main`은 `abbfece6ea621b13bd9832b53976ce0acd67f839`였고 beta.1과 public Tap이 이미 있었습니다.

**Beta.3 당시 시작 기준(2026-10-08):** source `main`은 `c8b78c89e77ca6636db429cff46db9db68aebf9b`에서 clean 상태였고 공개 source와 일치했습니다. Beta.2 prerelease와 public `soom-kang/homebrew-touch-me` Tap이 있었고, Tap 원격 `main`은 `fb0cea082d066bf0d34559eec6348ae09c0a5e8d`였습니다.

**Beta.4 시작 기준(2026-10-09):** source `main`은 `91142b7bb1137452ae6618b09cea5488e1c8849e`와 미커밋 제스처 관련 6개 파일에서 시작합니다. Beta.1·beta.2·beta.3가 공개돼 있고 Tap 원격 `main`은 `55d661ae2d5a4409db7d720d4988556592769970`입니다. 기존 tag와 asset을 모두 보존합니다. 게시 전에 원격 상태를 다시 확인하고, 별도 checkout에서 기존 Tap을 갱신합니다. Tap을 다시 만들지 않습니다.

**완료 조건:** 소유권, release 대상과 변경할 파일 범위가 명확합니다. **중단 조건:** 원격 불일치, 기존 tag·release 충돌, 예상하지 못한 Tap 변경, 보존할 수 없는 변경이나 마운트된 대치 대상 이미지가 있습니다. 정상 추출하며 강제 추출하지 않습니다.

### Phase 1 — Source·라이선스·배포 문서 정렬

**입력:** 검토한 제스처 관련 6개 파일과 release metadata·문서 갱신. 한 손가락 탭은 손을 뗄 때 클릭하며, 화면 좌표 8단위를 초과해 이동하면 드래그를 시작합니다. 드래그 전에 두 번째 접촉이 감지되면 대기 중인 클릭을 취소하고 스크롤합니다. 진행 중인 드래그는 첫 접촉을 추적하며, 스크롤 뒤나 첫 접촉 해제 뒤에는 모든 접촉이 해제될 때까지 기다립니다. 저작권 2026 Soom Kang인 프로젝트 `LICENSE`와 번들의 `Licenses.txt`를 유지합니다. 기존 다이어그램, bundle identifier, 환경설정 형식과 다른 장치·lifecycle 계약은 유지하고 기존 UI의 제스처 안내를 갱신합니다. README, Workflow와 이 문서의 두 언어를 함께 검토합니다. 변경 사항과 실제 검증 범위는 [beta.4 release notes](releases/v0.8.0-beta.4.md)에 기록합니다.

**완료 조건:** 배포 문서와 번들 입력이 일치하고 최종 diff에는 요청한 변경만 있습니다. **중단 조건:** source 누락, 해결되지 않은 권리 관계나 관련 없는 변경으로 release를 검토할 수 없습니다. 이전에 만든 산출물이 현재 번들 입력과 일치한다고 가정하지 않습니다.

### Phase 2 — 후보 빌드와 확정

**입력:** 별도 release checkout의 검토한 source와 `VERSION=0.8.0-beta.4`. 기존 build 20 앱을 해당 checkout의 `dist/Touch Me.app`에 복사해 build 번호 기준으로 사용하며, 빌드 한 번으로 build 21을 생성해야 합니다. 제스처 수정 후 기존 Swift tests 14개가 통과했고 build 20의 제스처 확인은 직접 event·process 증거 없이 `PASS_USER_REPORTED`로 기록합니다. 제스처 코드가 유지되는 동안 이 결과를 재사용합니다. 패키징 계약은 유지하며 새 tests나 검증 인프라를 추가하거나 전체 suite를 반복하지 않습니다. 해당 checkout 루트에서 빌드·패키징을 각각 한 번 실행합니다:

```bash
bash scripts/build-app.sh
python3 scripts/package-dmg.py
hdiutil verify dist/touch-me-0.8.0-beta.4-arm64.dmg
(cd dist && shasum -a 256 -c touch-me-0.8.0-beta.4-arm64.dmg.sha256)
```

기존 scripts는 warnings-as-errors release 컴파일, 번들 생성, strict ad hoc 서명 검증과 식별자·버전·라이선스 내용 일치·arm64 패키징 검사를 수행합니다. [Workflow](../Workflow.ko.md)에 따라 `Info.plist`를 확인하고 번들 아이콘을 source와 비교합니다. Build 21을 확인하고 정확한 checksum을 [beta.4 release notes](releases/v0.8.0-beta.4.md)에 기록한 뒤 해당 digest를 로컬 Cask 초안에 넣습니다. Build 21 실기기, Gatekeeper와 Homebrew 설치 검사는 `NOT_RUN`이며 과거 결과로 대신하지 않습니다. 최종 Cask의 style은 Phase 4에서 검사합니다.

Cask에는 `app "Touch Me.app"`, arm64/Tahoe 조건, beta 수동 관리용 `livecheck` skip과 설치 안내를 둡니다. 자동 실행 hooks, 권한 변경, `zap`, 언어별 다운로드와 auto-update 주장은 넣지 않습니다. [Cask Cookbook](https://docs.brew.sh/Cask-Cookbook)

**완료 조건:** 컴파일, 패키징, strict 서명, metadata, 라이선스·아이콘, arm64, DMG 무결성과 checksum 검사가 통과하고 초안은 확정한 후보와 일치하며 문서 내용도 같습니다. **중단 조건:** 이 검사 중 하나라도 실패합니다. 이전 산출물을 보존하고 수정으로 영향을 받은 검사만 반복합니다. 확인 목적으로 성공한 빌드를 다시 실행하지 마세요. 재빌드는 build 번호, 서명과 DMG bytes를 바꿀 수 있습니다.

### Phase 3 — 검토한 Source·tag·prerelease 게시

**입력:** 확정한 후보, 최종 diff와 두 언어의 release notes. Notes에는 기능, 지원 범위, ad hoc 서명과 실제 검증 한계를 기록합니다. 의도한 source, 라이선스, 문서와 Cask 초안만 검토하고 commit합니다. 생성한 앱·DMG는 Git에 넣지 않습니다. 확정한 release checkout과 최종 source commit 사이에서 Sources, Package, VERSION, scripts, 라이선스·아이콘을 포함한 모든 컴파일·패키징 입력을 비교합니다. 입력이 다른 commit에 확정 DMG를 연결하지 않습니다. 검토한 commit을 source `main`에 push하고 원격 revision이 일치하는지 확인한 뒤 tag를 만듭니다.

Git 게시 명령은 해당 commit이 있는 source checkout에서 실행합니다. 아래 asset 경로는 확정한 release checkout 기준입니다. 다른 폴더에서 게시하면 작업 checkout의 실행 중인 `dist` 대신 release DMG와 checksum의 절대 경로를 사용합니다.

```bash
git push origin main
git tag -a v0.8.0-beta.4 "$(git rev-parse HEAD)" -m 'Touch Me v0.8.0-beta.4'
git push origin refs/tags/v0.8.0-beta.4
gh release create v0.8.0-beta.4 \
  --repo soom-kang/touch-me --verify-tag --prerelease --latest=false \
  --title 'Touch Me v0.8.0-beta.4' \
  --notes-file docs/releases/v0.8.0-beta.4.md \
  dist/touch-me-0.8.0-beta.4-arm64.dmg \
  dist/touch-me-0.8.0-beta.4-arm64.dmg.sha256
```

검토한 notes 파일 경로를 사용합니다. Annotated tag를 commit으로 해석한 결과가 검토한 revision과 일치해야 합니다. Tag나 release가 이미 있으면 commit과 asset을 확인하고 일치하는 미완료 작업만 이어갑니다. 공개한 tag·asset은 강제 대치하거나 삭제하지 않습니다. 별도 검증 폴더로 두 공개 asset을 다운로드하고 업로드한 `.sha256`을 검증해 확정 후보의 digest와 비교합니다. Release가 prerelease인지도 확인합니다.

**완료 조건:** 원격 source와 tag가 검토한 commit을 가리키고 공개 다운로드 bytes가 일치하며 release notes가 검증 범위를 정확히 설명합니다. **중단 조건:** source·tag 일치, 공개 다운로드나 checksum을 확인하지 못합니다. Asset이 없거나 불일치하면 Tap을 공개하지 않습니다.

### Phase 4 — 기존 Tap 갱신과 공개

**입력:** 검증한 공개 prerelease와 최종 Cask 초안. 기존 public `soom-kang/homebrew-touch-me` repository는 별도 checkout을 사용합니다. 저장소를 다시 만들거나 source 프로젝트에 Git 저장소를 중첩하지 않습니다. 변경 전에 Git 상태와 원격 revision을 확인합니다. `Casks/touch-me.rb`, 영문·한글 설치 안내와 다음 버전 한정 예외 파일 `audit_exceptions/github_prerelease_allowlist.json`을 갱신하고 프로젝트 MIT license를 보존합니다:

```json
{
  "touch-me": "0.8.0-beta.4"
}
```

이 예외는 의도한 beta 버전이 GitHub prerelease 검사를 통과하도록 합니다. `all`, `any`, 전역 signing 예외와 prerelease 검사를 제외하는 audit 명령은 사용하지 않습니다. Beta release마다 해당 버전을 명시적으로 갱신합니다.

최종 초안을 `Casks/touch-me.rb`로 복사하고 검증한 공개 DMG와 버전·URL·hash를 비교합니다. 공개 전에 절대 경로로 style을 실행합니다:

```bash
brew style /absolute/path/to/homebrew-touch-me/Casks/touch-me.rb
```

Tap diff를 검토한 뒤 해당 파일만 commit하고 공개합니다. 작은 Tap에 CI나 테스트 인프라를 추가하지 않습니다.

**완료 조건:** 공개 Tap에 검토한 Cask, 버전 한정 예외, 영문·한글 안내와 license가 있으며 로컬 style이 통과합니다. **중단 조건:** Tap에 검토하지 않은 변경이나 history가 있거나 checksum이 다르거나 style 오류가 해결되지 않았습니다. Source release는 유지하며 Tap 공개만 중단합니다.

### Phase 5 — 기존 Tap 동기화와 online audit

**입력:** 공개한 Tap과 검증한 공개 asset. 2026-10-08에 선택한 Cask의 기존 trust를 확인했으며 Tap 전체는 trusted 상태가 아니었습니다. 이 범위를 유지합니다. 설치된 Tap이 clean 상태이고 remote가 바뀌지 않았는지 확인한 뒤 검토한 공개 revision으로 fast-forward하고, 결과 HEAD를 비교한 다음 audit를 실행합니다:

```bash
TASK_TAP_PATH="$(brew --repo soom-kang/touch-me)"
git -C "$TASK_TAP_PATH" status --short
git -C "$TASK_TAP_PATH" pull --ff-only
git -C "$TASK_TAP_PATH" rev-parse HEAD
brew audit --cask --online soom-kang/touch-me/touch-me
```

Audit에는 설치된 Cask 이름을 사용합니다. Homebrew 7.0.9는 `.rb` 경로를 넘기는 `brew audit`를 지원하지 않으며, 외부 checkout에는 버전 한정 prerelease 예외를 읽는 설치 Tap context도 없습니다. 별도 checkout은 편집과 Phase 4 style 검사에 사용합니다. 기존 개별 Cask trust가 사라졌다면 trust를 바꾸지 않고 해당 단계를 중단해 합의합니다.

2026-10-07에 확인한 Homebrew 7.0.8의 관련 계약을 2026-10-08에 로컬 소스에서 다시 확인했으며, 이번 release를 위해 2026-10-09에 Homebrew 7.0.9도 확인했습니다. 비공식 Tap의 일반 online audit은 signing 검사를 건너뜁니다. `--new`는 signing 검사를 요청하므로 이번 ad hoc beta 경로에 사용하지 않습니다. Tap의 버전 한정 예외로 의도한 prerelease를 처리하며 다른 일반 audit 검사는 유지합니다. Homebrew가 바뀌면 이 동작을 다시 확인합니다. 관련 upstream 코드는 [Cask audit](https://github.com/Homebrew/brew/blob/7.0.9/Library/Homebrew/cask/audit.rb), [audit command](https://github.com/Homebrew/brew/blob/7.0.9/Library/Homebrew/dev-cmd/audit.rb)와 [GitHub release 검사](https://github.com/Homebrew/brew/blob/7.0.9/Library/Homebrew/utils/shared_audits.rb)입니다.

**완료 조건:** 기존 개별 Cask trust를 유지한 채 일반 online audit이 성공하고 release·Tap URL, source revision, build 번호, checksum과 실행 결과를 기록했습니다. **중단 조건:** Tap 동기화가 실패하거나 trust가 없거나 audit에 설명되지 않은 실패가 있습니다. 검사 제외로 숨기지 않습니다. 이번 release 작업은 여기서 종료합니다. Homebrew 설치, Gatekeeper 승인, GUI 언어 전환, 실기기 매핑과 로그인 실행은 `NOT_RUN`이며 audit이 해당 동작을 검증하지는 않습니다. 기존 `/Applications/Touch Me.app`은 그대로 둡니다.

## 공개 후 설치·업데이트·제거

다음은 공개한 beta.7과 확인한 Tap Cask의 설치 안내입니다. 이번 release 작업에서는 로컬 앱 설치나 upgrade를 실행하지 않았습니다. Beta.6 작업에서는 당시 설치된 beta.5 앱을 유지했습니다. 전체 이름으로 설치하면 Tap 전체 대신 선택한 Cask에 trust가 적용됩니다. [Tap Trust](https://docs.brew.sh/Tap-Trust)

```bash
brew install --cask soom-kang/touch-me/touch-me
```

`/Applications/Touch Me.app`을 수동 설치했다면 **로그인 시 시작**을 끄고 **매핑 중지 → 정상 종료**를 수행합니다. 연속 연결의 모드 복구나 종료가 확인된 연결의 기록 보존을 확인하세요. 기존 앱을 Applications 밖으로 옮겨 보존한 뒤 Homebrew로 설치합니다. 강제 덮어쓰기는 사용하지 않고 환경설정은 유지합니다. 복구에 실패하면 중단합니다.

Ad hoc beta는 공증하지 않았습니다. 출처와 checksum을 확인한 뒤 첫 실행을 시도하세요. macOS가 공식 승인 경로를 제공하면 **시스템 설정 → 개인정보 보호 및 보안 → 확인 없이 열기**에서 사용자가 직접 승인합니다. 관리 환경이나 손상·악성 경고로 진행할 수 없으면 중단하고 원인을 확인합니다. 이 절차는 Gatekeeper 승인을 보장하지 않습니다. [Apple 첫 실행 안내](https://support.apple.com/en-us/102445)

시스템 설정에서 **입력 모니터링**과 **손쉬운 사용**을 허용한 뒤 앱을 새로 조회합니다. Ad hoc 앱을 업데이트하면 권한 승인을 다시 해야 할 수 있으므로 매핑 전에 두 항목을 확인합니다. Cask의 `unsigned_accessibility`는 손쉬운 사용 재승인을 안내하며 권한을 부여하거나 quarantine을 변경하지 않습니다.

업데이트 전 **매핑 중지 → 정상 종료**와 연결이나 종료가 확인된 기록의 안전한 정리를 확인한 뒤 실행합니다:

```bash
brew update
brew upgrade --cask soom-kang/touch-me/touch-me
```

제거 전 **로그인 시 시작**을 끄고 같은 중지·종료 절차와 안전한 정리를 확인한 뒤 실행합니다:

```bash
brew uninstall --cask soom-kang/touch-me/touch-me
```

제거 후에도 앱 환경설정은 남습니다. `zap`, 자동 process kill과 장치 복구 hook은 없습니다. 복구나 기록 처리에 실패하면 업데이트·제거를 중단하고 현재 연결을 유지한 채 복구 재시도를 수행합니다. 불확실한 기록과 오류를 보존하세요. 연결 종료가 확인되면 기록 보존을 허용하지만 이전 모드를 새 연결에 쓰지는 않습니다.

## 결과 기록과 향후 서명 작업

Release 담당자는 `Asia/Seoul` 기준 날짜와 함께 source revision, tag, build 번호, DMG SHA-256, Homebrew 버전, 실행한 명령과 결과를 기록합니다. 산출물, Homebrew audit, GUI, 실기기와 로그인 실행 결과를 구분합니다. [Workflow](../Workflow.ko.md#변경에-맞는-최소-검증-선택하기)의 build 8–12는 과거 기록으로 보존하며 이후 후보의 동작을 검증한 근거로 사용하지 않습니다. Credential이나 민감한 개인 정보는 기록하지 않습니다.

향후 Developer ID 배포는 별도 승인한 서명·공증 준비와 최종 다운로드·설치 앱의 검증이 필요합니다. Credential 접근 절차는 이 문서에 넣지 않고 해당 release의 검증을 이번 ad hoc beta와 구분해 기록합니다.
