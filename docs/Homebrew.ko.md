[English](Homebrew.md) · [한국어](Homebrew.ko.md) · [개발 Workflow](../Workflow.ko.md) · [앱 사용 안내](../README.ko.md)

# Touch Me Homebrew beta 배포 준비

이 문서는 개인 Tap의 `0.8.0-beta.1` 배포를 준비하는 절차입니다. 현재 산출물은 로컬 ad hoc 앱, DMG, checksum과 Cask 초안입니다. Source·Tap 공개, tag push, release 게시, Cask trust와 설치는 별도 승인을 받은 뒤 진행합니다. 아래 예정 저장소의 공개 상태는 확인하지 않았습니다.

## 배포 기준

| 항목 | 합의한 값 |
| --- | --- |
| 예정 Source repository | `soom-kang/touch-me` |
| 예정 Tap repository | `soom-kang/homebrew-touch-me` |
| Tap / Cask token | `soom-kang/touch-me` / `touch-me` |
| Release 버전 / tag | `0.8.0-beta.1` / `v0.8.0-beta.1` |
| Asset | `touch-me-0.8.0-beta.1-arm64.dmg`과 `.sha256` 파일 |
| 앱 / 식별자 | `Touch Me.app` / `io.github.soom-kang.touchme` |
| 최소 환경 | Apple Silicon, macOS 26(Tahoe) 이상 |
| 장치 범위 | ZEUSLAP P16KT 한 대, USB `0x0457:0x0819`, 조건에 맞는 외부 화면 |
| 서명 | Ad hoc; Developer ID 서명과 notarization 없음 |
| 초안 / 향후 Tap 파일 | `packaging/homebrew/touch-me.rb.in` / `Casks/touch-me.rb` |

Release 버전은 `VERSION`에서 읽습니다. 번들에는 숫자 형식의 `CFBundleShortVersionString=0.8.0`, 증가하는 숫자 `CFBundleVersion`과 `TouchMeReleaseVersion=0.8.0-beta.1`을 기록합니다. 앱 About과 설정에는 전체 release 버전을 표시합니다. [Apple 버전 형식](https://developer.apple.com/help/glossary/version-number/)

하나의 앱이 영어와 한국어를 포함합니다. 저장한 선택이 없으면 영어로 시작하고, 설정에서 변경한 언어를 유지합니다. Cask에서는 언어를 선택하거나 언어별 산출물을 설치하지 않습니다.

초안은 다음 versioned asset URL을 사용합니다:

```text
https://github.com/soom-kang/touch-me/releases/download/v0.8.0-beta.1/touch-me-0.8.0-beta.1-arm64.dmg
```

SHA-256은 실제 업로드한 DMG와 일치해야 합니다. 경로는 고정하지만 GitHub asset 자체는 대치할 수 있습니다. 공개한 버전의 파일은 대치하지 않는 원칙으로 관리하세요. 공개 후 source, 서명이나 DMG bytes가 바뀌면 새 release 버전과 checksum을 사용합니다. 불일치를 `:no_check`로 우회하지 않습니다.

## 페이즈별 실행

### Phase 0 — 변경 전 상태 보존

**입력:** 로컬 프로젝트와 기존 앱·DMG. 지침, build scripts와 파일 목록을 확인합니다. Git metadata가 있으면 `git status --short`를 실행합니다. 이번 준비 시작 시에는 Git 저장소가 없었습니다. 프로젝트 밖에 원본 사본을 보존하고 변경 예정 범위를 기록합니다. 로컬 준비에 Git 초기화는 포함하지 않습니다.

**완료 조건:** 기존 파일과 산출물을 이번 변경과 구분할 수 있습니다. **중단 조건:** 기존 변경을 보존할 수 없거나 대치할 이미지가 마운트돼 있습니다. 정상 추출하며 강제 추출하지 않습니다.

### Phase 1 — 앱 언어 선택 추가

**입력:** 기존 bilingual 문구와 환경설정. 설정 상단에 English / 한국어를 추가하고 값이 없거나 잘못됐으면 영어를 사용합니다. 설정, 메뉴, 기존 상태·오류와 열린 시험 창을 즉시 갱신하되 실행 상태와 대상 선택을 유지합니다. macOS 대화상자, 시스템 오류 상세와 화면 제품명은 기존 표시를 유지합니다.

**완료 조건:** 하나의 앱·세션 모델을 유지하고 macOS 언어 설정과 별개로 언어를 저장합니다. GUI 확인 전에는 같은 Bundle Identifier의 다른 앱이 종료됐고 P16KT가 분리됐는지 확인합니다. 영어 기본값, 양방향 전환, 기존 메시지, 열린 시험 창, 문구 잘림과 재실행 후 선택을 확인합니다. **GUI 중단 조건:** 두 격리 조건 중 하나라도 확인할 수 없으면 `NOT_RUN`으로 기록합니다. 검증을 위해 매핑 환경설정이나 개인정보 보호 권한을 초기화하지 않습니다.

### Phase 2 — 로컬 후보 빌드와 확정

**입력:** 검토한 source와 `VERSION=0.8.0-beta.1`. 프로젝트 루트에서 실행합니다:

```bash
bash scripts/build-app.sh
python3 scripts/package-dmg.py
(cd dist && shasum -a 256 -c touch-me-0.8.0-beta.1-arm64.dmg.sha256)
```

기존 scripts는 warnings-as-errors를 적용한 release 컴파일, 번들 생성, strict ad hoc 서명 검증과 식별자·버전·고지·arm64 패키징 검사를 수행합니다. [Workflow](../Workflow.ko.md)에 따라 `Info.plist`와 번들 고지를 확인합니다. Build 번호와 checksum을 기록합니다. Release metadata가 이전 버전이면 package 명령이 거부해야 합니다.

**완료 조건:** 두 scripts와 checksum 검증을 통과하고 확정한 파일을 보존합니다. **중단 조건:** 컴파일, metadata, 서명, 아키텍처, 고지나 checksum 검사가 실패합니다. 이전 정상 산출물을 보존하고 원인을 수정한 뒤 영향을 받은 검사만 반복합니다. 이미 성공한 빌드를 확인 목적으로 다시 실행하지 마세요. 재빌드는 build 번호, 서명이나 DMG bytes를 바꿔 확정한 checksum을 무효화합니다.

### Phase 3 — 로컬 Cask 초안과 문서 확정

**입력:** 최종 후보의 checksum과 합의한 배포 기준. 초안의 `sha256`에 실제 digest를 넣습니다. `.rb.in` 확장자를 유지해 Tap에서 사용하는 `Casks/touch-me.rb`와 구분합니다.

```bash
ruby -c packaging/homebrew/touch-me.rb.in
```

이 문서의 두 언어와 변경한 README·Workflow를 전체 검토합니다. 버전, asset 이름, URL, 지원 범위와 승인 경계가 일치해야 합니다. Cask에는 `app "Touch Me.app"`, arm64/Tahoe 조건, beta 수동 관리용 `livecheck` skip과 설치 안내를 둡니다. 자동 실행 hooks, 권한 변경, `zap`, 언어별 다운로드와 auto-update 주장은 넣지 않습니다. [Cask Cookbook](https://docs.brew.sh/Cask-Cookbook)

**완료 조건:** Ruby syntax 통과, 최종 후보와 digest 일치, 문서 일치입니다. **중단 조건:** 후보가 바뀌거나 digest가 다르거나 미게시 URL을 사용 가능하다고 표현합니다. 여기까지가 이번 준비 범위입니다. Homebrew style, online audit과 설치는 후속 페이즈까지 `NOT_RUN`입니다.

### Phase 4 — 승인한 Source와 prerelease 게시

**입력:** Git 초기화, 검토한 commit, remote 생성, push와 게시의 명시적 승인; 확정한 후보; 서명·지원 범위와 실제 검증 결과를 담은 승인한 release notes.

예정 저장소의 소유권과 존재 여부를 먼저 확인합니다. 없다면 승인받은 public repository `soom-kang/touch-me`를 생성합니다. 로컬 Git이 여전히 없을 때만 초기화합니다. `.gitignore`의 `.build`, `dist`, `.DS_Store`를 확인하고 검토한 source, 라이선스 고지, 문서와 Cask 초안만 stage합니다. Staged diff에 무관한 파일이나 민감 정보가 없는지 확인한 뒤 사용자가 요청한 commit을 수행합니다. 승인한 remote를 연결하고 검토한 commit을 push합니다. Force나 hooks 우회는 사용하지 않습니다.

Commit과 remote 확인 후 release 명령은 다음과 같습니다:

```bash
git tag v0.8.0-beta.1
git push origin v0.8.0-beta.1
gh release create v0.8.0-beta.1 \
  --repo soom-kang/touch-me --verify-tag --prerelease \
  --title 'Touch Me v0.8.0-beta.1' \
  --notes-file /path/to/approved-release-notes.md \
  dist/touch-me-0.8.0-beta.1-arm64.dmg \
  dist/touch-me-0.8.0-beta.1-arm64.dmg.sha256
```

Release-notes 경로는 승인한 파일로 바꿉니다. Tag나 release가 이미 존재하면 내용을 확인하고 불일치 시 중단합니다. 덮어쓰지 않습니다. 별도 검증 폴더로 공개 asset을 다운로드하고 업로드한 `.sha256`으로 검증합니다. 확정한 후보와 digest가 같고 release가 prerelease로 표시되는지 확인합니다.

**완료 조건:** 공개 tag가 검토한 source를 가리키고 다운로드 bytes와 release notes의 검증 범위가 정확합니다. **중단 조건:** 소유권, 승인, source/tag 일치, 공개 다운로드나 checksum을 확인하지 못합니다. Asset이 없거나 불일치하면 Tap을 공개하지 않습니다.

### Phase 5 — Tap 공개와 설치 검증

**입력:** 검증한 공개 release와 Tap repository·push·Cask trust·로컬 설치에 대한 명시적 승인. `soom-kang/homebrew-touch-me`는 별도 checkout을 사용하며 source 프로젝트에 Git 저장소를 중첩하지 않습니다. 최종 초안을 `Casks/touch-me.rb`로 복사하고 공개 DMG와 버전·URL·hash를 비교한 뒤 검토한 Tap 변경만 게시합니다.

공개 후 해당 Cask만 trust하고 검사합니다:

```bash
brew tap soom-kang/touch-me
brew trust --cask soom-kang/touch-me/touch-me
brew style --cask soom-kang/touch-me/touch-me
brew audit --cask --online soom-kang/touch-me/touch-me
```

2026-10-07에 Homebrew 7.0.8 코드를 확인했습니다. 비공식 Tap의 일반 online audit은 signing 검사를 건너뛰고 `--new`는 signing 검사를 요청합니다. 별도의 `github_prerelease_version` 검사는 의도한 GitHub prerelease를 거부할 수 있습니다. 먼저 일반 검사 결과를 보존하세요. Beta 정책만 예외일 때 다음의 제한된 결과를 별도로 기록합니다:

```bash
brew audit --cask --online --except=github_prerelease_version soom-kang/touch-me/touch-me
```

이를 전체 audit 통과라고 보고하거나 다른 실패를 숨기거나 signing 조건을 전역으로 끄지 않습니다. Homebrew가 바뀌면 이 동작을 다시 확인합니다. 개인 Tap audit은 Gatekeeper 승인의 근거가 아닙니다. 확인한 upstream 코드는 [Cask audit](https://github.com/Homebrew/brew/blob/7.0.8/Library/Homebrew/cask/audit.rb), [audit command](https://github.com/Homebrew/brew/blob/7.0.8/Library/Homebrew/dev-cmd/audit.rb)와 [GitHub release 검사](https://github.com/Homebrew/brew/blob/7.0.8/Library/Homebrew/utils/shared_audits.rb)입니다.

아래 절차로 충돌을 해결한 뒤에만 설치합니다. 실제 다운로드, 설치, 첫 실행, 언어 선택, 개인정보 보호 권한과 P16KT 동작을 각각 기록합니다. 설치 성공만으로 매핑을 검증했다고 판정하지 않습니다.

**완료 조건:** 정확한 공개 산출물이 설치되고 설치 앱의 실제 결과가 선언한 지원 범위를 뒷받침합니다. **중단 조건:** 설명되지 않은 style/audit 오류, 충돌 앱, 장치 복구 실패, Gatekeeper의 손상·악성 경고나 설치 앱 검사 실패입니다. 증거와 정상 후보를 보존하며 보안 설정 변경으로 자동 복구하지 않습니다.

## 공개 후 설치·업데이트·제거

다음은 후속 명령이며 Tap의 공개 상태를 증명하지 않습니다. 전체 이름으로 설치하면 Tap 전체 대신 선택한 Cask에 trust가 적용됩니다. [Tap Trust](https://docs.brew.sh/Tap-Trust)

```bash
brew install --cask soom-kang/touch-me/touch-me
```

`/Applications/Touch Me.app`을 수동 설치했다면 **로그인 시 시작**을 끄고 **매핑 중지 → 정상 종료**를 수행합니다. 장치 모드 복구 완료를 확인하세요. 기존 앱을 Applications 밖으로 옮겨 보존한 뒤 Homebrew로 설치합니다. 강제 덮어쓰기는 사용하지 않고 환경설정은 유지합니다. 복구에 실패하면 중단합니다.

Ad hoc beta는 공증하지 않았습니다. 출처와 checksum을 확인한 뒤 첫 실행을 시도하세요. macOS가 공식 승인 경로를 제공하면 **시스템 설정 → 개인정보 보호 및 보안 → 확인 없이 열기**에서 사용자가 직접 승인합니다. 관리 환경이나 손상·악성 경고로 진행할 수 없으면 중단하고 원인을 확인합니다. 이 절차는 Gatekeeper 승인을 보장하지 않습니다. [Apple 첫 실행 안내](https://support.apple.com/en-us/102445)

시스템 설정에서 **입력 모니터링**과 **손쉬운 사용**을 허용한 뒤 앱을 새로 조회합니다. Ad hoc 앱을 업데이트하면 권한 승인을 다시 해야 할 수 있으므로 매핑 전에 두 항목을 확인합니다. Cask의 `unsigned_accessibility`는 손쉬운 사용 재승인을 안내하며 권한을 부여하거나 quarantine을 변경하지 않습니다.

업데이트 전 **매핑 중지 → 정상 종료**와 모드 복구를 확인한 뒤 실행합니다:

```bash
brew update
brew upgrade --cask soom-kang/touch-me/touch-me
```

제거 전 **로그인 시 시작**을 끄고 같은 중지·종료 절차와 모드 복구를 확인한 뒤 실행합니다:

```bash
brew uninstall --cask soom-kang/touch-me/touch-me
```

제거 후에도 앱 환경설정은 남습니다. `zap`, 자동 process kill과 장치 복구 hook은 없습니다. 복구에 실패하면 같은 USB 포트에 패널을 다시 연결해 중지가 성공할 때까지 업데이트·제거를 중단합니다.

## 결과 기록과 향후 서명 작업

Release 담당자는 `Asia/Seoul` 기준 날짜와 함께 source revision, tag, build 번호, DMG SHA-256, Homebrew 버전, 실행한 명령과 결과를 기록합니다. 후보 GUI, 실기기, 로그인 실행과 Homebrew 결과를 구분합니다. [Workflow](../Workflow.ko.md#변경에-맞는-최소-검증-선택하기)의 build 8·9는 과거 기록으로 보존하며 이번 후보의 근거로 사용하지 않습니다. Credential이나 민감한 개인 정보는 기록하지 않습니다.

향후 Developer ID 배포는 별도 승인한 서명·공증 준비와 최종 다운로드·설치 앱의 검증이 필요합니다. Credential 접근 절차는 이 문서에 넣지 않고 해당 release의 검증을 이번 ad hoc beta와 구분해 기록합니다.
