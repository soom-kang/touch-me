[English](Homebrew.md) · [한국어](Homebrew.ko.md) · [개발 Workflow](../Workflow.ko.md) · [앱 사용 안내](../README.ko.md)

# Touch Me Homebrew beta 배포

이 문서는 `0.8.0-beta.1`을 GitHub prerelease와 개인 Tap의 ad hoc beta Cask로 공개하는 절차입니다. 2026-10-07 release 작업은 검토한 source 갱신, tag, release asset, Tap 공개와 online audit까지 진행합니다. 각 페이즈의 검사가 통과하면 다음으로 진행하며, 실패하거나 새 결정이 필요하면 중단합니다. Cask 설치, 기존 Applications 앱 대치, GUI와 실기기 확인은 별도 후속 작업입니다.

## 배포 기준

| 항목 | 값 |
| --- | --- |
| Source repository | [soom-kang/touch-me](https://github.com/soom-kang/touch-me) |
| Tap repository | `soom-kang/homebrew-touch-me` |
| Tap / Cask token | `soom-kang/touch-me` / `touch-me` |
| Release 버전 / tag | `0.8.0-beta.1` / `v0.8.0-beta.1` |
| Asset | `touch-me-0.8.0-beta.1-arm64.dmg`과 `.sha256` 파일 |
| 앱 / 식별자 | `Touch Me.app` / `io.github.soom-kang.touchme` |
| 최소 환경 | Apple Silicon, macOS 26(Tahoe) 이상 |
| 장치 범위 | ZEUSLAP P16KT 한 대, USB `0x0457:0x0819`, 조건에 맞는 외부 화면 |
| 서명 | Ad hoc; Developer ID 서명과 notarization 없음 |
| 로컬 초안 / Tap 파일 | `packaging/homebrew/touch-me.rb.in` / `Casks/touch-me.rb` |

Release 버전은 `VERSION`에서 읽습니다. 번들에는 숫자 형식의 `CFBundleShortVersionString=0.8.0`, 증가하는 숫자 `CFBundleVersion`과 `TouchMeReleaseVersion=0.8.0-beta.1`을 기록합니다. 앱 About과 설정에는 전체 release 버전을 표시합니다. [Apple 버전 형식](https://developer.apple.com/help/glossary/version-number/)

하나의 앱이 영어와 한국어를 포함합니다. 저장한 선택이 없으면 영어로 시작하고 설정에서 선택한 언어를 유지합니다. Cask에는 언어별 다운로드를 넣지 않습니다.

다음 versioned asset URL을 사용합니다:

```text
https://github.com/soom-kang/touch-me/releases/download/v0.8.0-beta.1/touch-me-0.8.0-beta.1-arm64.dmg
```

Cask의 SHA-256은 실제 업로드한 DMG와 일치해야 합니다. GitHub에서는 asset 대치가 가능하므로 공개한 버전의 파일을 대치하지 않는 원칙으로 관리하세요. 공개 후 source, 서명이나 DMG가 바뀌면 새 버전과 checksum을 사용합니다. 불일치를 `:no_check`로 우회하거나 기존 release asset을 대치하지 않습니다.

## 페이즈별 실행

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

2026-10-07 사전 확인에서는 로컬 `main`이 `5e2520f7f3bacdd85507a383d0c08da3555a1c5d`에서 clean 상태였고 원격 `main`과 일치했습니다. Source repository는 public이었으며 release는 없었습니다. 예정한 Tap은 찾을 수 없다는 응답을 반환했습니다. 이는 시작 시점의 확인 결과이며 게시 전에 원격 상태를 다시 조회합니다. 관련 없는 변경과 이전 앱·DMG를 보존하고, 이미 있는 source repository를 다시 초기화하지 않습니다.

**완료 조건:** 소유권, release 대상과 변경할 파일 범위가 명확합니다. **중단 조건:** 원격 불일치, 기존 tag·release 충돌, 예상하지 못한 Tap, 보존할 수 없는 변경이나 마운트된 대치 대상 이미지가 있습니다. 정상 추출하며 강제 추출하지 않습니다.

### Phase 1 — Source·라이선스·배포 문서 정렬

**입력:** 검토한 언어·버전 구현과 요청한 문서 정리. 저작권 2026 Soom Kang인 프로젝트 `LICENSE`를 유지합니다. 해당 라이선스를 `Licenses.txt`에 포함하고 앱 메뉴, 설치 안내와 다이어그램의 내용을 맞춥니다. 기존 UI와 매핑 동작을 유지합니다. README, Workflow와 이 문서의 두 언어를 함께 검토합니다.

**완료 조건:** 배포 문서와 번들 입력이 일치하고 최종 diff에는 요청한 변경만 있습니다. **중단 조건:** source 누락, 해결되지 않은 권리 관계나 관련 없는 변경으로 release를 검토할 수 없습니다. 이전에 만든 산출물이 현재 번들 입력과 일치한다고 가정하지 않습니다.

### Phase 2 — 후보 빌드와 확정

**입력:** 검토한 source와 `VERSION=0.8.0-beta.1`. 프로젝트 루트에서 실행합니다:

```bash
bash scripts/build-app.sh
python3 scripts/package-dmg.py
(cd dist && shasum -a 256 -c touch-me-0.8.0-beta.1-arm64.dmg.sha256)
```

기존 scripts는 warnings-as-errors release 컴파일, 번들 생성, strict ad hoc 서명 검증과 식별자·버전·라이선스 리소스·arm64 패키징 검사를 수행합니다. [Workflow](../Workflow.ko.md)에 따라 `Info.plist`와 `Licenses.txt`를 확인합니다. Build 번호와 정확한 checksum을 기록하고 해당 digest를 로컬 Cask 초안에 넣습니다.

```bash
ruby -c packaging/homebrew/touch-me.rb.in
```

Cask에는 `app "Touch Me.app"`, arm64/Tahoe 조건, beta 수동 관리용 `livecheck` skip과 설치 안내를 둡니다. 자동 실행 hooks, 권한 변경, `zap`, 언어별 다운로드와 auto-update 주장은 넣지 않습니다. [Cask Cookbook](https://docs.brew.sh/Cask-Cookbook)

**완료 조건:** 컴파일, 패키징, checksum과 Ruby syntax가 통과하고 초안은 확정한 후보와 일치하며 문서 내용도 같습니다. **중단 조건:** metadata, 서명, 아키텍처, 라이선스나 checksum 검사가 실패합니다. 이전 산출물을 보존하고 수정으로 영향을 받은 검사만 반복합니다. 확인 목적으로 성공한 빌드를 다시 실행하지 마세요. 재빌드는 build 번호, 서명과 DMG bytes를 바꿀 수 있습니다.

### Phase 3 — 검토한 Source·tag·prerelease 게시

**입력:** 확정한 후보, 최종 diff와 두 언어의 release notes. Notes에는 기능, 지원 범위, ad hoc 서명과 실제 검증 한계를 기록합니다. 의도한 source, 라이선스, 문서와 Cask 초안만 검토하고 commit합니다. 생성한 앱·DMG는 Git에 넣지 않습니다. 검토한 commit을 source `main`에 push하고 원격 revision이 일치하는지 확인한 뒤 tag를 만듭니다.

```bash
git push origin main
git tag -a v0.8.0-beta.1 "$(git rev-parse HEAD)" -m 'Touch Me v0.8.0-beta.1'
git push origin refs/tags/v0.8.0-beta.1
gh release create v0.8.0-beta.1 \
  --repo soom-kang/touch-me --verify-tag --prerelease \
  --title 'Touch Me v0.8.0-beta.1' \
  --notes-file /path/to/reviewed-release-notes.md \
  dist/touch-me-0.8.0-beta.1-arm64.dmg \
  dist/touch-me-0.8.0-beta.1-arm64.dmg.sha256
```

검토한 notes 파일 경로를 사용합니다. Annotated tag를 commit으로 해석한 결과가 검토한 revision과 일치해야 합니다. Tag나 release가 이미 있으면 commit과 asset을 확인하고 일치하는 미완료 작업만 이어갑니다. 공개한 tag·asset은 강제 대치하거나 삭제하지 않습니다. 별도 검증 폴더로 두 공개 asset을 다운로드하고 업로드한 `.sha256`을 검증해 확정 후보의 digest와 비교합니다. Release가 prerelease인지도 확인합니다.

**완료 조건:** 원격 source와 tag가 검토한 commit을 가리키고 공개 다운로드 bytes가 일치하며 release notes가 검증 범위를 정확히 설명합니다. **중단 조건:** source·tag 일치, 공개 다운로드나 checksum을 확인하지 못합니다. Asset이 없거나 불일치하면 Tap을 공개하지 않습니다.

### Phase 4 — Tap 생성과 공개

**입력:** 검증한 공개 prerelease와 최종 Cask 초안. Public `soom-kang/homebrew-touch-me` repository는 별도 checkout을 사용하며 source 프로젝트에 Git 저장소를 중첩하지 않습니다. Tap에는 `Casks/touch-me.rb`, 지원 범위와 설치 안내를 담은 짧은 README, 프로젝트 MIT license와 다음 버전 한정 예외 파일 `audit_exceptions/github_prerelease_allowlist.json`을 둡니다:

```json
{
  "touch-me": "0.8.0-beta.1"
}
```

이 예외는 의도한 beta 버전이 GitHub prerelease 검사를 통과하도록 합니다. `all`, `any`, 전역 signing 예외와 prerelease 검사를 제외하는 audit 명령은 사용하지 않습니다. Beta release마다 해당 버전을 명시적으로 갱신합니다.

최종 초안을 `Casks/touch-me.rb`로 복사하고 검증한 공개 DMG와 버전·URL·hash를 비교합니다. 공개 전에 절대 경로로 style을 실행합니다:

```bash
brew style /absolute/path/to/homebrew-touch-me/Casks/touch-me.rb
```

Tap diff를 검토한 뒤 해당 파일만 commit하고 공개합니다. 작은 Tap에 CI나 테스트 인프라를 추가하지 않습니다.

**완료 조건:** 공개 Tap에 검토한 Cask, 버전 한정 예외, README와 license가 있으며 로컬 style이 통과합니다. **중단 조건:** Tap에 예상하지 못한 history가 있거나 checksum이 다르거나 style 오류가 해결되지 않았습니다. Source release는 유지하며 Tap 공개만 중단합니다.

### Phase 5 — 개별 Cask trust와 online audit

**입력:** 공개한 Tap과 검증한 공개 asset. 로컬 trust를 선택한 Cask 범위에 적용합니다:

```bash
brew tap soom-kang/touch-me
brew trust --cask soom-kang/touch-me/touch-me
brew audit --cask --online soom-kang/touch-me/touch-me
```

2026-10-07에 Homebrew 7.0.8 코드를 확인했습니다. 비공식 Tap의 일반 online audit은 signing 검사를 건너뜁니다. `--new`는 signing 검사를 요청하므로 이번 ad hoc beta 경로에 사용하지 않습니다. Tap의 버전 한정 예외로 의도한 prerelease를 처리하며 다른 일반 audit 검사는 유지합니다. Homebrew가 바뀌면 이 동작을 다시 확인합니다. 관련 upstream 코드는 [Cask audit](https://github.com/Homebrew/brew/blob/7.0.8/Library/Homebrew/cask/audit.rb), [audit command](https://github.com/Homebrew/brew/blob/7.0.8/Library/Homebrew/dev-cmd/audit.rb)와 [GitHub release 검사](https://github.com/Homebrew/brew/blob/7.0.8/Library/Homebrew/utils/shared_audits.rb)입니다.

**완료 조건:** 개별 Cask trust와 일반 online audit이 성공하고 release·Tap URL, source revision, build 번호, checksum과 실행 결과를 기록했습니다. **중단 조건:** trust나 audit에 설명되지 않은 실패가 있습니다. 검사 제외로 숨기지 않습니다. 이번 release 작업은 여기서 종료합니다. Homebrew 설치, Gatekeeper 승인, GUI 언어 전환, 실기기 매핑과 로그인 실행은 `NOT_RUN`이며 audit이 해당 동작을 검증하지는 않습니다. 기존 `/Applications/Touch Me.app`은 그대로 둡니다.

## 공개 후 설치·업데이트·제거

다음은 사용자 설치 안내이며 공개·audit 작업과 별개입니다. 전체 이름으로 설치하면 Tap 전체 대신 선택한 Cask에 trust가 적용됩니다. [Tap Trust](https://docs.brew.sh/Tap-Trust)

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

Release 담당자는 `Asia/Seoul` 기준 날짜와 함께 source revision, tag, build 번호, DMG SHA-256, Homebrew 버전, 실행한 명령과 결과를 기록합니다. 산출물, Homebrew audit, GUI, 실기기와 로그인 실행 결과를 구분합니다. [Workflow](../Workflow.ko.md#변경에-맞는-최소-검증-선택하기)의 build 8–10은 과거 기록으로 보존하며 이후 후보의 동작을 검증한 근거로 사용하지 않습니다. Credential이나 민감한 개인 정보는 기록하지 않습니다.

향후 Developer ID 배포는 별도 승인한 서명·공증 준비와 최종 다운로드·설치 앱의 검증이 필요합니다. Credential 접근 절차는 이 문서에 넣지 않고 해당 release의 검증을 이번 ad hoc beta와 구분해 기록합니다.
