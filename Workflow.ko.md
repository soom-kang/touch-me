[English](Workflow.md) · [한국어](Workflow.ko.md) · [앱 사용 안내](README.ko.md) · [Homebrew 배포](docs/Homebrew.ko.md)

<!-- meta.contentType: How-to; audience: contributors; goal: build and package Touch Me locally; content plan: environment, modules, build, packaging, checks, recovery, release. -->

# Touch Me 로컬 빌드와 패키징

이 Workflow에 따라 arm64 앱을 빌드하고 번들을 확인한 뒤 개인용 디스크 이미지를 만드세요. 기존 스크립트는 Apple의 로컬 도구와 Python 3를 사용합니다. 추가 dependency 설치와 산출물 공개는 수행하지 않습니다.

## 개발 환경 준비하기

Apple Silicon Mac, macOS 26 이상, 패키지의 Swift 6.0 manifest와 호환되는 Swift 도구, Python 3가 필요합니다. 프로젝트 폴더에서 명령을 실행하세요. 빌드에는 터치 모니터 연결이 필요하지 않습니다.

앱의 식별자와 버전은 다음 값을 유지합니다:

| 항목                  | 값                                   |
| --------------------- | ------------------------------------ |
| 앱과 실행 파일        | `Touch Me.app` / `TouchMe`           |
| Bundle Identifier     | `io.github.soom-kang.touchme`        |
| Release 버전          | `VERSION`에서 읽는 `0.8.0-beta.7`    |
| 번들 버전             | `0.8.0`과 증가하는 숫자 build 번호   |
| 전체 release metadata | `TouchMeReleaseVersion=0.8.0-beta.7` |
| 대상 환경             | `arm64`, macOS 26 이상               |

문서나 패키징을 바꿀 때는 식별자와 저장한 환경설정 형식을 유지하세요. 서명 identity나 설치 경로를 바꾸면 설치 앱의 권한 확인이 필요할 수 있습니다.

## 모듈별 역할 확인하기

패키지는 실행 상태 로직, macOS 장치 접근과 앱 제어를 나눕니다:

| 모듈               | 역할                                                                            |
| ------------------ | ------------------------------------------------------------------------------- |
| `TouchMappingCore` | 좌표 정규화, 화면 좌표 변환과 접촉 상태별 효과 계산                             |
| `TouchMePlatform`  | USB Human Interface Device(HID) 탐색, 화면 선택, P16KT 모드 복구와 macOS 이벤트 |
| `TouchMeApp`       | 메뉴 막대, 설정·시험 창, 환경설정, 로그인 실행과 재개 판단                      |

앱은 확인한 패널 한 대와 조건에 맞는 외부 화면을 사용합니다. 매핑은 장치를 독점 점유하고 필요한 경우 확인한 모드를 켭니다. 중지하거나 정상 종료하면 확인한 연속 연결에서 원래 모드로 복구합니다. 연결 종료를 확인한 경우에는 [journal 계약](docs/qa/abnormal-exit-recovery.md)에 따라 복구를 확인하지 못한 archive를 보존합니다. 복구나 archive 오류는 화면에 남고 종료를 차단할 수 있습니다.

현재 소스에는 앱의 네트워크 통신이나 원시 입력 로그 기능이 없습니다. 환경설정에는 선택한 장치·화면 정보, 재개할 의도와 앱 언어 선택을 저장하며, 터치 이력은 저장하지 않습니다. 기본 언어는 영어입니다. 언어를 바꾸면 앱이 만든 UI를 즉시 갱신하며 세션을 재시작하거나 macOS 언어 설정을 바꾸지 않습니다.

## Beta.7 release 준비 — 2026-10-10

상태는 **PUBLISHED**입니다. Prerelease `v0.8.0-beta.7`을 2026-10-10
14:25:14 KST(05:25:14 UTC)에 숫자 번들 버전 `0.8.0`, build 25로 공개했습니다. 개발 build 24와 설치 앱은
보존하며 로컬 앱 설치나 upgrade는 포함하지 않습니다.

아래 Swift tests 37개와 USB-C cycle 한 번을 개발 실행 파일 SHA-256
`06306a6ed873d314ab565066b42d5a022618ea067a53cd76abceb7333f2e41f7`에 연결해
재사용합니다. 매핑 코드를 유지하며 build 25의 새 GUI·실기기 acceptance는 없습니다.

| Release 검사 | 현재 상태 |
| --- | --- |
| 재사용한 source tests / build 24 USB-C cycle | `PASS`(37개) / `PASS_USER_REPORTED`(1회) |
| 새 build 25, 패키징·tests와 실제 Cask syntax·style | `PASS`; 빌드·패키징 각 1회, tests 18개, Cask 파일 1개에서 offenses 없음 |
| Source·tag·prerelease와 익명 public DMG·sidecar | `PUBLISHED` / 정확한 bytes 확인 `PASS` |
| 공개·별도 clone·설치된 Tap revision | `PASS`; `7c07d49`와 검토한 Cask 일치, 설치된 Tap clean fast-forward 완료 |
| 이전 beta.1–beta.6 공개 기록 | `PASS`; release 6개·asset 12개·tag/peeled refs 12개의 metadata 보존 |
| `brew audit --cask --online soom-kang/touch-me/touch-me` | `BLOCKED`; 승인한 보류에 따라 trust 설정과 우회 변수를 변경하지 않음 |
| Build 25 GUI·실기기, 설치·upgrade·Gatekeeper | `NOT_RUN`; release 범위 밖 |

`scripts/package-dmg.py`의 양언어 `Install.txt` 안내를 포함한 release 입력을
확정한 뒤 빌드·패키징을 각각 한 번 수행합니다. 입력을 release commit과 비교해
동결하고 새 번들·DMG를 검증합니다. Public 다운로드 bytes와 sidecar를 확인한
뒤 기존 Tap을 갱신합니다. Audit 보류와 별개로 Cask syntax·style과 public asset
식별은 필수입니다. 실제 revision·hash·결과는
[beta.7 release notes](docs/releases/v0.8.0-beta.7.md)에 기록합니다.
Beta.6 당시 online audit PASS는 과거 근거로만 보존합니다.

로컬 build 25의 컴파일·strict 서명·metadata·라이선스·아이콘·arm64 검사는
통과했습니다. 패키징은 한 번 통과했고 기존 packaging tests 18개도 통과했습니다.
Frozen inputs 28개가 일치했습니다. DMG 무결성·sidecar, 읽기 전용 mount 내부
identity(정확한 파일 5개), 양언어 설치 안내, Applications symlink와 정상 detach도
통과했습니다.

| 동결한 public 산출물 | 확인한 식별 |
| --- | --- |
| Build 25 실행 파일 SHA-256 | `b0ea3a8daecbb45cb75fb680941401e4ab679e9da7a8fe44c742975d38e309d4` |
| DMG 크기 / SHA-256 | 524,843 bytes / `74bf81ff7e7d1a0a1966146022b7e60841451897fee25a2dbe1449b31113da90` |

기존 Command Line Tools linker search-path 경고는 검사를 막지 않았습니다.
첫 상대 경로의 `hdiutil verify`는 경로 오류로 실패했고 정확한 절대 경로로
재시도해 통과했습니다. 산출물 변경이나 추가 패키징은 없었습니다.
2026-10-10 익명 public DMG·sidecar 확인은 통과했습니다. Raw bytes·크기·digest와
checksum 내용이 동결한 release와 일치합니다. Release 입력 28개는 source·tag
commit `f8210f4318f726c9943db1de7fa82e634d132a10`과 일치합니다.
Annotated tag object는 `0ea81d53133a218f661160db533e43d84a6e3177`입니다.
2026-10-10 14:28:27 KST(05:28:27 UTC) checkpoint에서 공개 Tap·별도 clone·설치된
Tap의 revision은 모두 `7c07d4967e94e0591229410f8952bb49c2b7e102`였습니다.
`/opt/homebrew/Library/Taps/soom-kang/homebrew-touch-me`는 `3c3ab9e`에서
`fetch`와 `merge --ff-only`로 fast-forward했고 clean 상태를 유지했습니다.
파일 4개가 공개 clone과 일치하며 Cask는 source template과 일치합니다.
Tap checkout만 갱신했으며 앱 설치·upgrade나 trust 변경은 없었습니다.

## USB-C 재연결 후보 — 2026-10-10

이 개발 검증 snapshot은 beta.7 release 준비 전 재연결 변경의 결과입니다. 당시 `VERSION`, 기존 active record schema와 `SavedMapping`을 유지했습니다. 공개 beta.6와 이전 acceptance 기록도 당시 확인 범위를 보존합니다. 완료한 개발 작업에는 commit·push·release·Tap 갱신·DMG 패키징을 포함하지 않았으며 beta.7 release 범위는 위에 구분했습니다.

모드를 변경한 active record가 있으면 독점 lease, 같은 부팅, 정확한 nonce와 현재 소유자 또는 종료가 확인된 이전 소유자를 확인합니다. 정확한 이전 HID와 USB 서비스가 모두 종료됐음을 확인해야 하며 조회 오류는 연결 해제로 보지 않습니다. `disconnected-<nonce>.json` → `reconnect-required.json` → active record 제거 순서로 저장하고 sync합니다. Archive는 복구를 확인하지 못한 기록이며 이전 모드 값을 새 연결에 쓰지 않습니다.

Active record 없이 당시 읽은 `(0,0)`이나 `(2,0)`이 유지된 경우에는 정확한 값, 식별과 소유자를 포함한 guard를 먼저 저장한 뒤 archive를 저장합니다. 재실행에서 유효한 guard에 대응하는 archive가 없으면 장치 쓰기 없이 파일 근거로 canonical archive를 보완합니다.

실패한 단계는 다른 기록을 덮어쓰지 않고 재시도합니다. 시작 중 guard 제거 sync에 실패하면 rollback 전에 guard를 다시 영구 저장합니다. 저장 문제가 남으면 오류를 표시하고 정리를 차단합니다.

자동 시작은 장치를 독점으로 연 뒤 저장한 USB 위치, descriptor, 지원 패널 한 대, 화면 UUID, 현재 좌표, 권한과 세션을 확인합니다. 새로 읽은 `(0,0)`만 자동 시작을 허용합니다. `(2,0)`은 안내 후 직접 시작해야 하며 중지 뒤에도 `(2,0)`을 유지합니다. 재연결 확인 기록은 재실행 후에도 유지하고 새 기본 모드 journal이 준비되거나 직접 시작을 승인한 뒤에만 해제합니다. 완료 전 케이블 대기 의도는 메모리에만 둡니다.

케이블이 없는 동안 기존 1초 timer를 사용합니다. 장치가 처음 다시 나타나면 고정된 10초 준비 확인 구간을 시작하며 중복 알림으로 연장하지 않습니다. 중지, 대상 선택이나 정상 종료는 대기를 취소합니다. 화면 변경 알림이 HID 제거보다 먼저 도착하면 기존 2초 분류와 1초 poll로 정확한 이전 서비스의 종료를 확인합니다. 일반 잠금·절전 복구 규칙은 유지합니다.

기존 targets와 `bash scripts/test.sh`로 집중 검증하고 `bash scripts/build-app.sh`로 후보를 한 번 빌드합니다. 이후 승인한 후보 cycle **시작 → 분리 → 재연결 → 자동 재개 → 두 위치 탭 → 중지**를 확인합니다. 기존 앱과 산출물을 보존합니다. 앱 전환에는 정상 종료를 사용하며 종료가 막히면 기록을 보존하고 구체적인 전환 절차를 합의합니다. 이전 프로세스가 없음을 확인한 뒤 후보를 실행합니다. 로컬 검사만으로 실기기 cycle 성공을 판정하지 않습니다.

| 후보 검사 | 현재 결과 |
| --- | --- |
| Swift 컴파일과 기존 tests | `PASS`: 37개(Platform 24개, Core 13개), 앱 컴파일 포함 |
| 후보 앱 빌드와 strict 서명 | `PASS`: `bash scripts/build-app.sh` 1회, 컴파일·번들 생성과 내장 strict 서명 검증, exit 0 |
| 기존 앱 종료와 로컬 후보 실행 | 정상 종료 `BLOCKED_USER_REPORTED`; 별도 승인한 1회 전환과 후보 실행 `PASS` |
| 승인한 USB-C cycle과 두 위치 탭 | 2026-10-10 `PASS_USER_REPORTED`: 시작 → 같은 USB-C 분리·재연결 → 자동 재개 → 두 위치 탭 → 중지 1회; 승인한 acceptance 범위 충족 |
| 새 release, Homebrew 설치나 upgrade | 수행하지 않음; 범위 밖 |

개발 checkpoint 당시 source checkout의 후보는 `dist/Touch Me.app`이며
release `0.8.0-beta.6`, 숫자 번들 버전 `0.8.0`, build 24였습니다(이전 로컬
build 23 → 24). 설치 앱도 beta.6/build 24로 표시돼 아래 경로와 hash로
구분했습니다. 별도 beta.7 release checkout에는 현재 build 25가 있으며
아래 표는 개발 checkpoint의 식별입니다:

| 실행 파일 | SHA-256 |
| --- | --- |
| `dist/Touch Me.app/Contents/MacOS/TouchMe` | `06306a6ed873d314ab565066b42d5a022618ea067a53cd76abceb7333f2e41f7` |
| `/Applications/Touch Me.app/Contents/MacOS/TouchMe` | `7a2bcd46e4ec2e0a507ebe4b0230c6ad993f9ce92a287c102d1048c483432945` |

사용자가 복구 오류 때문에 설치 앱의 정상 종료가 막혔다고 보고했습니다.
별도 1회 승인에 따라 정확한 경로와 PID 973을 확인·재확인한 뒤 `SIGKILL`을
한 번 실행하고 프로세스 부재를 확인했습니다. Active record의 직전·직후
SHA-256은 동일하며 내용은 로그에 남기지 않았습니다. 설치 앱 번들은 보존했습니다.
이 승인은 해당 전환 한 번에만 적용합니다.

최초 CUA 조회는 `native pipe closed`로 실패했습니다. 이어 sandbox에서 실행을
시도했을 때 후보 실행 파일이 존재하고 실행 권한이 있는데도 `-10827`이 반환됐습니다.
승인한 재시도는 성공했고 `dist` 후보 PID 53203만 실행 중임을 확인했습니다.
13:24:13.214의 `MappingRecovery` 로그는 조회 전에 종료된 이전 연결을 보존하는
경로가 실행됐음을 확인합니다. 이는 실행·경로 근거이며 독립적인 모드 쓰기 횟수나
실기기 cycle 결과는 아닙니다. 일반 사용에서는 계속 정상 종료를 사용합니다.

2026-10-10에 사용자가 요청한 cycle에서 자동 재개, 두 위치 탭과 중지가 모두
성공했다고 확인했습니다. 집중 tests와 후보 빌드 통과 결과를 함께 적용해 승인한
완료 범위를 충족했습니다. 모드 값을 직접 읽거나 장치 모드 쓰기 횟수를 독립적으로
측정하지는 않았습니다. 원래 모드 2의 실기기 동작, 재부팅, 잠금·절전 회귀와
더 넓은 crash recovery는 이 후보에서 검증하지 않았습니다.

첫 test 컴파일은 `try` 누락으로 실패했고 수정 후 36개가 통과했습니다.
리뷰 보완 후 안정된 source의 최종 37개 PASS를 현재 결과로 사용합니다.
기존 Command Line Tools의 `Developer/usr/lib`와
`Developer/Library/Frameworks` 누락 linker 경고는 있었으나 실패는 없었습니다.
최종 문서 diff는 `git diff --check`를 통과했으며 후보 빌드 후 문서 변경으로
다시 빌드하지 않습니다. 별도 packaging tests, DMG 생성, Homebrew·release와
Gatekeeper는 이번 범위에서 실행하지 않았습니다. 실기기 결과는 위에서 사용자가
확인한 cycle 한 번으로 한정합니다.

확인 범위는 [lifecycle 정책](docs/qa/lifecycle-policy.md), [journal 계약](docs/qa/abnormal-exit-recovery.md)과 [자동 테스트 범위](docs/qa/automated-tests.md)를 따릅니다. 별도 검증 framework는 추가하지 않습니다.

## 앱 빌드와 번들 확인하기

과거 beta.6는 QA 완료 기록을 재배포했으며 beta.5 이후 실행 코드 변경은 없었습니다. 빌드·패키징 각 한 번으로 build 24를 생성했고 frozen inputs 28개 일치, numeric version `0.8.0`, macOS 26+/arm64, strict 서명과 라이선스·아이콘 검사를 통과했습니다. 로컬과 설치된 beta.5 build 23의 hash는 보존했습니다. Build 23 실기기 PASS는 beta.6 acceptance가 아닌 회귀 근거입니다. [Beta.6 release notes](docs/releases/v0.8.0-beta.6.md)를 확인하세요.

Release 실행 파일을 빌드하고 아이콘과 프로젝트 라이선스를 번들에 포함하세요. 최초 beta.5 준비는 설치된 build 21을 번호의 기준으로 build 22를 한 번 생성했습니다. Journal 도입 전인 이 산출물은 과거 기록으로 보존합니다. 합의한 recovery journal의 build 23을 생성했고 strict 서명, arm64, metadata, 라이선스·아이콘과 frozen inputs 28개 검사가 통과했습니다. 패키징도 통과했습니다. Build 23 정상 사용·재실행 확인은 `PASS_USER_REPORTED`입니다. 조건부 SIGKILL·재실행 한 번에서 매핑 재개 전 이전 기록을 복구했고 Stop·Quit 뒤 `(0,0)`을 확인했습니다. 이전 산출물을 보존하며 재빌드는 번호를 다시 증가시킵니다:

```bash
bash scripts/build-app.sh
```

스크립트는 `dist/Touch Me.app`을 만들고 이전 로컬 번들의 build 번호를 증가시킵니다. 이전 앱은 `dist/previous-builds`에 보존합니다. Ad hoc 서명 후 `codesign --verify --strict`로 검증합니다.

디스크 이미지를 만들기 전에 번들 metadata와 라이선스 리소스를 확인하세요:

```bash
plutil -p 'dist/Touch Me.app/Contents/Info.plist'
cat 'dist/Touch Me.app/Contents/Resources/Licenses.txt'
cmp Resources/TouchMe.icns 'dist/Touch Me.app/Contents/Resources/TouchMe.icns'
```

`Licenses.txt`에는 프로젝트 `LICENSE`를 넣습니다. 라이선스 파일이 없으면 번들 생성을 중단합니다. Ad hoc 서명 검증은 로컬 번들의 무결성을 확인하며, Developer ID 서명이나 notarization의 근거가 되지는 않습니다.

## 개인용 디스크 이미지 만들기

서명한 앱, Applications 바로가기와 두 언어의 설치 안내를 패키징하세요:

```bash
python3 scripts/package-dmg.py
```

스크립트는 앱의 식별자, `VERSION`과 release metadata의 일치, 라이선스 리소스 존재 여부, 서명과 arm64 아키텍처를 확인합니다. 이전 버전 번들이면 새 release 파일명을 붙이지 않고 패키징을 중단합니다. 산출물은 다음과 같습니다:

| 산출물                                        | 용도                    |
| --------------------------------------------- | ----------------------- |
| `dist/Touch Me.app`                           | 로컬 서명한 앱 번들     |
| `dist/touch-me-0.8.0-beta.7-arm64.dmg`        | 로컬 beta 후보 이미지   |
| `dist/touch-me-0.8.0-beta.7-arm64.dmg.sha256` | SHA-256 checksum        |

Release checkout의 기존 이미지는 `dist/previous-builds`로 옮깁니다. DMG 무결성과 checksum을 확인하세요:

과거 확인한 beta.6 DMG는 build 24를 포함하며 455,405 bytes입니다. Digest는
[후보 기록](docs/releases/v0.8.0-beta.6.md)에 있습니다. DMG 무결성·sidecar,
읽기 전용 mount 내부 identity와 정상 detach 검사를 통과했습니다. Beta.5 build
23과 과거 build 22의 checksum은 새 산출물을 검증하는 근거로 사용할 수 없습니다.

```bash
hdiutil verify dist/touch-me-0.8.0-beta.7-arm64.dmg
(cd dist && shasum -a 256 -c touch-me-0.8.0-beta.7-arm64.dmg.sha256)
```

![소스와 라이선스로 로컬 서명 앱을 만들고 개인용 디스크 이미지와 SHA-256 checksum을 생성하는 흐름입니다.](docs/assets/packaging.ko.png)

[편집 가능한 다이어그램](docs/assets/packaging.ko.html)

마운트한 이미지는 대치하지 마세요. 먼저 정상 추출하세요. 사용 중이면 대치를 중단하고 해당 이미지를 사용하는 앱을 닫으세요. 강제 추출은 사용하지 않습니다.

## 변경에 맞는 최소 검증 선택하기

바뀐 동작에 맞춰 검증하세요. 결함이나 새로운 호환성 주장이 있을 때만 검사를 추가합니다:

| 변경                                | 최소 확인                                                                        |
| ----------------------------------- | -------------------------------------------------------------------------------- |
| 문서 또는 이미지                    | 변경한 문서 전체 읽기; 링크, 번역과 이미지 렌더링 확인                           |
| 라이선스 메뉴 또는 패키징           | Release 빌드 1회; 라이선스 리소스, 서명, 디스크 이미지와 checksum 확인           |
| 앱 언어                             | Release 빌드 1회; 안전한 환경에서 영어 기본값, 양방향 즉시 전환과 선택 유지 확인 |
| 좌표 또는 제스처 로직               | `bash scripts/test.sh` 실행; 대상 패널에서 해당 제스처 확인                      |
| 장치 열기, 모드 복구 또는 lifecycle | 대상 패널의 독점 점유, 입력 해제와 복구 확인                                     |
| 서명, 로그인 실행 또는 호환 범위    | 변경한 환경에서 설치 앱 확인                                                     |

최초 beta.5 build 22는 기존 Swift targets와 빌드·패키징 각 한 번의 결과를 사용했습니다. 정상 smoke는 `PASS_USER_REPORTED`이며 승인된 SIGKILL 한 번과 재실행·Stop·Quit 후 원래 모드 복구는 `FAIL`이었습니다. 진단 복구로 `(0,0)`을 확인했습니다. 이후 합의한 journal을 source에 구현했고 모든 targets 컴파일, 집중 DeviceMode 검사 3개·journal 검사 6개, 후보 build 23과 패키징이 통과했습니다. Build 23 정상 사용, Stop·Quit 후 재실행 때 중지 유지와 매핑 중 Quit 후 재실행 때 재개는 `PASS_USER_REPORTED`입니다. 별도 정상 Quit 경로 뒤 16:20:05 KST의 조회에서 `(0,0)`을 확인했지만 직전 매핑은 직접 관찰하지 못했습니다. 추가 승인된 SIGKILL 한 번 뒤 `(2,0)`과 같은 기록이 남았고 재실행 후보가 재개 전 복구·기록 삭제를 확인한 다음 Stop·Quit 후 `(0,0)`을 직접 읽었습니다. TMQA003은 이 원래 모드 0·같은 부팅·계속 연결된 장치 조건에서 PASS입니다. 충돌 후 재개·두 위치 탭·오류 없음·Stop·Quit은 `PASS_USER_REPORTED`입니다. 신규 설치, 권한 off/on, 잠금·절전, 실제 로그아웃·로그인과 제거는 계속 제외합니다. 공개 전 checkpoint에서는 공개 검토를 기다렸고 공개 Homebrew 업그레이드 acceptance는 `NOT_RUN`이었습니다. [beta.5 acceptance 기록](docs/qa/beta5-native-acceptance.md)에 완료한 공개 업그레이드 범위를 추가했습니다.

2026-10-09 beta.5 준비에서는 계획 단계의 `bash scripts/test.sh` PASS 24개(Platform 11개, Core 13개)를 재실행 없이 사용했습니다. `bash scripts/build-app.sh`와 `python3 scripts/package-dmg.py`를 각각 한 번 실행해 build 22와 419,445-byte DMG를 생성했습니다. 컴파일, strict ad hoc 서명, bundle metadata, 라이선스·아이콘, arm64, 입력 manifest 27개 일치, `hdiutil verify`와 SHA-256 sidecar 검사를 통과했습니다. 이는 로컬 결과이며 실기기 매핑이나 공개를 증명하지 않습니다. Checksum과 남은 검사는 [후보 기록](docs/releases/v0.8.0-beta.5.md)을 확인하세요.

기존 core tests는 순수 로직을 검증합니다. HID 접근, 장치 모드 복구, 권한이나 실기기 동작은 검증하지 않습니다. 제스처 수정 후 기존 Swift tests 14개가 모두 통과했고 build 20의 제스처 확인은 `PASS_USER_REPORTED`입니다. 이 결과는 build 21의 직접 실기기 검증이 아닙니다. 승인된 beta.4 배포는 제스처 코드가 유지되는 동안 이 결과를 재사용합니다. 새 tests나 검증 인프라를 추가하거나 전체 suite를 반복하지 않습니다. 빌드·패키징 각 한 번, strict 서명, metadata, 라이선스·아이콘, arm64, DMG 무결성·checksum, Cask style, 공개 다운로드와 online audit를 확인합니다. Build 21 실기기, Gatekeeper와 Homebrew 설치 검사는 `NOT_RUN`입니다. 관련 source 변경이 있을 때만 성공한 빌드를 다시 실행하세요. 재빌드는 build 번호, 서명과 DMG bytes를 바꿀 수 있습니다. Beta.4 산출물·게시 결과는 [release notes](docs/releases/v0.8.0-beta.4.md)에 기록합니다.

언어 확인용 후보 앱을 열기 전에 같은 Bundle Identifier의 다른 앱이 종료됐고 P16KT가 분리됐는지 확인하세요. 확인할 수 없으면 GUI 검증은 `NOT_RUN`으로 기록합니다. 기존 앱이 활성화되거나 저장한 매핑이 재개되는 동작은 후보 검증으로 보지 않습니다. 설정과 메뉴, 이미 열린 시험 창을 확인하고 언어 전환 후 대상 확인과 시험 기록이 유지돼야 합니다. 아래 build 8·9 기록은 과거 검증으로 유지합니다.

보존한 요약은 2026-10-07 build 8의 사용자 보고를 정리합니다. 단독 제스처, 종료·재개, 중지 상태 유지, 로그인 항목 전환과 Finder 설치가 대상입니다. 별도로 패키지, 서명, checksum과 프로세스를 확인한 기록도 있습니다. 이 기록은 재생성한 앱의 새 실기기 검증이 아닙니다. 실제 로그아웃·로그인은 `NOT_RUN`, 자동 재개 후 가로 스크롤은 `NOT_RETESTED`입니다.

2026-10-07의 문서·라이선스 정리에서 build 9를 생성했습니다. Release 컴파일, strict ad hoc 서명 검증, 라이선스 리소스의 정확한 내용, arm64 아키텍처, 두 언어의 설치 안내, 디스크 이미지의 읽기 전용 확인과 SHA-256 검증을 통과했습니다. 패키지의 실행 파일·아이콘은 로컬 앱과 일치했습니다. 매핑 로직을 유지했으므로 core tests와 실기기 확인은 반복하지 않았습니다. 새 앱의 라이선스 메뉴를 여는 동작도 실행하지 않았습니다.

### v0.8.0-beta.1 로컬 준비

2026-10-07(`Asia/Seoul`)의 언어·버전 준비에서 build 10을 생성했습니다. 번들에는 `CFBundleShortVersionString=0.8.0`과 `TouchMeReleaseVersion=0.8.0-beta.1`을 기록했습니다. `bash scripts/build-app.sh`의 warnings-as-errors release 컴파일과 strict ad hoc 서명 검증을 통과했습니다. 번들의 라이선스와 아이콘 내용도 source와 일치했습니다. Command Line Tools의 framework/library search path가 없다는 linker 경고가 있었지만 빌드는 완료됐습니다.

첫 `python3 scripts/package-dmg.py`는 제한된 실행 환경에서 `hdiutil create`에 실패했으며, 로컬 디스크 이미지 접근을 허용한 뒤 성공했습니다. 설치 안내에서 게시 시점에 따라 낡는 문구를 제거한 후 같은 build 10 앱으로 패키징만 반복했습니다. 해당 DMG는 `hdiutil verify`와 SHA-256 검사를 통과했습니다. `ruby -c packaging/homebrew/touch-me.rb.in`이 통과했고 당시 초안의 digest는 해당 후보와 일치했습니다. 임시 입력으로 누락·잘못된 `VERSION`과 이전 버전의 번들 metadata가 산출물 대치 전에 거부되는 것을 확인했습니다. 이 검사는 build 10 준비 기록입니다. 이후 release 후보의 checksum과 패키징 결과는 별도로 기록합니다. 이전 앱·DMG 산출물은 보존했습니다.

GUI 언어 전환, 재실행 후 선택 유지, 열린 시험 창과 문구 잘림은 `NOT_RUN`입니다. USB registry 조회가 실패해 P16KT의 물리적 분리를 확인하지 못했습니다. 기존 Touch Me process는 없었으며 후보 앱을 실행하지 않았습니다. Source 검토로 언어 변경이 모델을 재시작하거나 매핑·로그인 동작을 호출하지 않고 표시만 갱신하는 것을 확인했습니다. Core 로직은 유지해 tests를 반복하지 않았으며 test 파일·dependency는 추가하지 않았습니다. Homebrew style/audit/install, 다운로드한 앱의 Gatekeeper 처리, 실기기 매핑과 로그인 실행도 `NOT_RUN`입니다. 로컬 빌드·서명 결과는 이 동작의 검증을 대신하지 않습니다.

### v0.8.0-beta.1 release 후보

2026-10-07(`Asia/Seoul`) release 준비에서 build 11을 생성했습니다. Release build 한 번으로 warnings-as-errors 컴파일과 strict ad hoc 서명 검증을 통과했습니다. 번들의 `Licenses.txt`는 프로젝트 `LICENSE`와 정확히 일치했습니다. 이전 번들은 라이선스 내용 불일치로 staging 전에 거부됐고, 새 앱은 패키징, arm64 검사, `hdiutil verify`와 SHA-256 검사를 통과했습니다.

확정한 DMG SHA-256은 `eb255a5296921c93c2cd8d9de98b7424fc380e7b3a24e713c682df0cf500b618`입니다. 로컬 Cask 초안과 Tap Cask에 같은 digest를 넣었습니다. Ruby syntax 검사를 통과했습니다. 첫 Homebrew style 실행에는 도구 cache 접근이 필요했고, 이후 검사에서 Cask 설명의 불필요한 platform 이름을 지적했습니다. 설명을 수정한 뒤 같은 파일을 다시 검사해 오류 없이 통과했습니다. 영문·한글 패키징 그림은 기존 디자인으로 다시 렌더링하고 잘림을 확인했습니다. 지원 범위와 검증 경계는 [release notes](docs/releases/v0.8.0-beta.1.md)를 확인하세요.

이번 후보의 GUI, Gatekeeper, 실기기, 로그인 실행과 Homebrew 설치 검사는 `NOT_RUN`입니다. Source·Tap 게시와 online audit은 runbook 페이즈에 따라 진행하며, 실제 결과는 로컬 산출물 검사와 구분해 기록합니다.

### v0.8.0-beta.2 release 후보

2026-10-07(`Asia/Seoul`)에 기존 Python packaging suite의 첫 실행에서 18개 중 17개가 통과했습니다. 권한 실패 fixture는 macOS의 `/var` 경로 별칭을 사용했지만 패키징은 `/private/var`로 해석해 mock이 의도한 실패를 재현하지 못했습니다. Fixture의 임시 root를 resolve하도록 맞춘 뒤 재실행한 suite는 18개 모두 통과했습니다. 기존 Swift suite는 한 번 실행해 14개 모두 통과했습니다. 새 tests나 검증 인프라는 추가하지 않았습니다.

Release build 한 번으로 build 12를 생성했습니다. 숫자 번들 버전은 `0.8.0`, 전체 release metadata는 `TouchMeReleaseVersion=0.8.0-beta.2`입니다. Release 컴파일, strict ad hoc 서명 검증, 정확한 번들 라이선스·아이콘 내용, arm64 패키징, `hdiutil verify`와 SHA-256 검사를 통과했습니다. Command Line Tools의 framework/library search path가 없다는 linker 경고는 빌드를 막지 않았습니다. 확정한 DMG SHA-256은 `b667c7ba2518b966fec2fdc4b92152d66db58b0758460e5c5f4daa42cd5d3469`입니다. 이는 로컬 산출물 결과이며 게시, Cask style과 online audit 결과는 별도로 기록합니다. GUI, Gatekeeper, 실기기, 로그인 실행과 Homebrew 설치 검사는 `NOT_RUN`입니다. 변경 사항과 검증 경계는 [release notes](docs/releases/v0.8.0-beta.2.md)를 확인하세요.

### v0.8.0-beta.3 배포 준비

2026-10-08(`Asia/Seoul`)에 별도 checkout에서 빌드·패키징을 각각 한 번 실행해 `TouchMeReleaseVersion=0.8.0-beta.3`인 build 19를 생성했습니다. 실행 중인 개발 build 18과 Applications 앱은 보존했습니다. 컴파일·번들 입력 23개는 작업 checkout과 일치했습니다. Release 컴파일, strict ad hoc 서명 검증, bundle metadata, 정확한 라이선스·아이콘 내용, arm64 아키텍처, `hdiutil verify`와 SHA-256 검사를 통과했습니다. 확정한 DMG SHA-256은 `7f3b500c8efa0d7195e54f581fd0cc4d0fb6265ff54464b39ce6eeb9e7dfef76`입니다. Homebrew style은 실제 Tap의 `Casks/touch-me.rb` 한 파일을 검사해 오류 없이 통과했습니다. Release 준비를 위한 새 tests나 기존 전체 suite 재실행은 추가하지 않았습니다.

이는 로컬 산출물과 style 결과입니다. 공개 다운로드와 online audit 결과는 [공개 beta.3 release](https://github.com/soom-kang/touch-me/releases/tag/v0.8.0-beta.3)에 별도로 기록합니다. 위의 테스트·산출물 기록은 과거 결과로 유지하며 beta.3 산출물이나 설치 검증의 근거로 사용하지 않습니다. Release 앱을 설치하거나 실행해 GUI, Gatekeeper, 실기기나 로그인 실행을 새로 확인하지 않았습니다.

## 실패 시 작업 범위 유지하기

빌드나 패키징이 실패하면 새 산출물 전달을 중단합니다. 보고된 로컬 원인을 수정하고 실패한 명령만 다시 실행하세요. 대체 산출물의 검증을 마칠 때까지 이전에 사용할 수 있던 산출물을 유지합니다.

승인받은 장치 시험 중 모드 복구가 실패하면 현재 연결을 유지하고 복구 재시도를 누르세요. 연결이 바뀌었다고 이전 모드 쓰기를 허용하지는 않습니다. 재연결 후보는 위 조건에서 종료된 연결의 기록을 보존할 수 있지만 원래 모드 복구 성공은 아닙니다. 확인이 불확실하면 기록과 오류를 보존하세요. 실패를 숨기거나, 다른 장치로 바꾸거나, 저장한 재개 의도를 덮어써서 복구했다고 판정하지 마세요.

정리를 마친 폴더에는 `.build`와 `dist/previous-builds`가 없을 수 있습니다. 다음 빌드에서 다시 생성합니다. 삭제 전 정확한 생성 경로와 마운트 상태를 확인하고 외부 폴더를 가리키는 링크는 따라가지 마세요.

## 검토한 릴리즈 공개하기

2026-10-09 beta.6 공개 후 기록: release source·tag `7a663f5bd70fcfc73d8b44ea78abeeb69ac4b40e`의 [prerelease](https://github.com/soom-kang/touch-me/releases/tag/v0.8.0-beta.6)를 18:38:18 KST에 공개했습니다. 18:38:33 KST 익명 DMG·sidecar 확인에서 build 24의 455,405-byte 산출물과 일치했습니다. Public Tap `3c3ab9e95c3ad6991d7397fa6b436c2f46e5aa7f`를 push했고 설치된 Tap도 clean하게 fast-forward했습니다. 실제 Cask의 Ruby syntax·style과 일반 `brew audit --cask --online soom-kang/touch-me/touch-me`가 통과했습니다. Audit은 `--new`나 검사 제외 없이 18:39:35 KST에 exit 0으로 완료됐고 선택한 Cask trust는 유지했습니다. 설치된 beta.5 앱은 보존합니다. Beta.6 설치·GUI·Gatekeeper·실기기 사용·Homebrew upgrade는 `NOT_RUN`이며 beta.5 build 23 결과는 회귀 근거로만 인용합니다. [Beta.6 release notes](docs/releases/v0.8.0-beta.6.md)를 확인하세요.

### 과거 beta.5 공개와 acceptance

2026-10-09 공개 후 기록: source·tag `4ead3d1acec3beb43a1f09261b308ef9fdef0e81`과 [beta.5 prerelease](https://github.com/soom-kang/touch-me/releases/tag/v0.8.0-beta.5)를 공개했습니다. 익명 DMG·sidecar 다운로드는 확정한 build 23과 일치했고 이전 beta.4 asset은 보존했습니다. Tap과 설치된 Tap은 `31cdb32c1e1415401c26fd338842bf811471b531`입니다. 공개 Homebrew 업그레이드 단계와 설치 산출물 검사는 통과했습니다. 이후 자동 core clone을 16:48:57 KST에 중단했고 자동 정리를 확인했으며 전체 command는 exit 130이었습니다.

QA01은 합의한 공개 업그레이드 범위에서 `PASS`입니다. 설치 build 23·두 권한·두 위치 탭·Stop/정상 Quit는 `PASS_USER_REPORTED`입니다. 18:03:47 KST에 TouchMe process·recovery record가 없었으며 18:04:26 KST의 새 읽기 전용 세션에서 같은 boot·HID/USB registry identity·location·descriptor의 현재 `(0,0)`이 사전 original/journal pair와 일치함을 관측했습니다. 이 세션은 arm→exit만 수행했고 feature writes 0, exit 0입니다. [Acceptance 기록](docs/qa/beta5-native-acceptance.md)을 확인하세요.

### 과거 공개 전 checkpoint — 16:24 KST

2026-10-09 공개 전 기록은 `READY_FOR_RELEASE_REVIEW / NOT_PUBLISHED`입니다. Build 23은 제한된 TMQA003 acceptance를 통과했고 QA01 공개 업그레이드는 `NOT_RUN`입니다. 당시 release commit·push, tag, 공개와 Tap 갱신은 수행하지 않았습니다. 승인 뒤 frozen source/package 입력과 release commit을 비교하고 검토한 asset을 공개·다운로드 검증한 다음 Tap을 갱신합니다. 이전 asset과 환경설정을 보존하며 공개 업그레이드 acceptance는 이후 수행합니다. [Release notes](docs/releases/v0.8.0-beta.5.md)와 [Homebrew 준비](docs/Homebrew.ko.md#beta5-준비)를 확인하세요.

### 과거 beta.4 배포 범위

승인된 `0.8.0-beta.4` prerelease는 기존 개인 Tap `soom-kang/homebrew-touch-me`의 ad hoc beta Cask를 갱신합니다. Source repository는 [soom-kang/touch-me](https://github.com/soom-kang/touch-me)입니다. 2026-10-09 시작 기준은 source `main`의 `91142b7bb1137452ae6618b09cea5488e1c8849e`와 미커밋 제스처 관련 6개 파일입니다. Beta.1–beta.3가 공개돼 있고 Tap 원격 `main`은 `55d661ae2d5a4409db7d720d4988556592769970`입니다. 기존 tag와 asset을 보존합니다. 이번 승인은 검토한 source·release 문서 갱신, source·Tap의 commit·push, 새 tag·prerelease와 기존 Tap 갱신, online audit까지 포함합니다. Tag 생성 전 확정한 release checkout의 컴파일·패키징 입력을 최종 source commit과 비교합니다. 각 단계의 검사가 통과하면 다음으로 진행하고, 새로운 중요한 결정이 필요하거나 검사에 실패하면 해당 단계를 중단합니다.

[Homebrew 배포](docs/Homebrew.ko.md)에서 release 페이즈, checksum 확정, 첫 실행과 Tap 검사를 확인하세요. Ad hoc beta는 공증하지 않으며 Gatekeeper 승인을 주장하지 않습니다. 향후 Developer ID 배포는 서명·공증을 준비하고 최종 설치 산출물의 권한과 장치 동작을 다시 확인해야 합니다.

Tap 공개 후 clean 상태의 설치 Tap을 검토한 공개 revision으로 fast-forward하고, 기존 개별 Cask trust로 해당 이름의 Cask를 audit합니다. Trust 범위를 넓히거나 앱을 설치·업그레이드하지 않습니다. Homebrew 설치, `/Applications/Touch Me.app` 대치, GUI·실기기 확인, 개인정보 보호 설정 변경과 로그인 항목 등록은 이번 release 실행 범위 밖입니다. 이후 실행은 해당 작업의 승인 범위에 따라 진행하세요. Credential은 명령, 로그와 문서에 기록하지 않습니다.

Touch Me에는 [프로젝트 MIT License](LICENSE)를 적용합니다.
