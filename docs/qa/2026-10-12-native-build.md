# Touch Me local native build — 2026-10-12

**수정 앱과 DMG를 각각 1개 생성했고 상태 보존 범위의 native 검증을 마쳤습니다.**
사용자는 GUI 실행 대신 이 범위에서 마치는 것으로 합의했습니다. 설치 앱 교체,
복구 기록 변경과 권한 설정 변경은 수행하지 않았습니다.

## Candidate identity

이 후보는 수정된 working tree에서 만든 **로컬 QA 산출물**입니다. 공개 beta.7과 같은
version/build 표기를 사용하지만 executable과 DMG bytes가 다릅니다. 공개 checksum,
Cask나 기존 release asset을 이 후보에 적용하지 않습니다.

| Field | Value |
| --- | --- |
| Baseline HEAD | `65a8e71e5825bb8caca2357a713ef4d80c1b092a`; TMQA-006/007 수정은 uncommitted |
| App | `dist/Touch Me.app` |
| Release / numeric version / build | `0.8.0-beta.7` / `0.8.0` / `25` |
| Bundle identifier / executable | `io.github.soom-kang.touchme` / `TouchMe` |
| Minimum OS / architecture / signature | macOS `26.0` / `arm64` / ad hoc |
| Local executable SHA-256 | `d6fe1a98a98f03f684651b5e1856be8edf17b0889d00255a851872001ddd1bd2` |
| DMG | `dist/touch-me-0.8.0-beta.7-arm64.dmg`, 525,279 bytes |
| Local DMG SHA-256 | `cb46fa2fda5211504d04d9b7536de5883ad566cf514bf2ab02452500a2e5e803` |
| Input manifest | [43 tracked input hashes](2026-10-12-native-build-inputs.json) |
| Manifest SHA-256 | `d10b4deafa2a8f12a3535c724e7273803cd1198de2c6d9bfac390adcf02949e2` |
| Executor | macOS `26.7.1` / `25G241`, arm64, Apple Swift 6.4, Python 3.9.6 |

설치된 실행 파일은
`b0ea3a8daecbb45cb75fb680941401e4ab679e9da7a8fe44c742975d38e309d4`로 유지됩니다.
공개 build 25의 이 hash와 새 로컬 후보를 구분합니다.

## Executed checks

| Check | Result | Scope |
| --- | --- | --- |
| `bash scripts/build-app.sh` | PASS, 1 invocation / 1 successful app build | Release compilation, warnings-as-errors, arm64 bundle and built-in strict signature verification |
| `python3 scripts/package-dmg.py` | Initial FAIL before image creation; resumed to 1 completed DMG | The same staged app/notes were reused; no second app or staging build |
| Metadata, `lipo -archs`, `codesign -dv --verbose=4` | PASS | Identifier, version/build, minimum OS, arm64 and ad hoc signature |
| License and icon byte comparisons | PASS | Exact `LICENSE` resource and source icon bytes |
| DMG sidecar hash comparison | PASS | Exact current image digest and filename; published digest not reused |
| `hdiutil verify` with absolute DMG path | PASS, exit 0 | Native disk-image checksums valid |
| Read-only mounted inner app | PASS, all 5 files match | Outer/inner app bytes and `codesign --verify --strict` on inner bundle |
| Inner installation notes and Applications link | PASS | `Install.txt` matches this staging; symlink targets `/Applications` |
| Normal detach | PASS | Only the dedicated QA image detached, without force; absent from final `hdiutil info -plist` |
| Candidate executable `--scan` | EXECUTED, exit 3 | Native metadata-only path; no GUI/model initialization or device open |

Package script의 첫 `hdiutil create`는 제한된 executor에서
`장치가 구성되지 않았음`으로 실패했고 이미지를 생성하지 못했습니다.
직후 이미지 검사는 파일이 없어 실패했습니다. 아래 생성 재시도 뒤 해당 검사는
정상 산출물에 대해 완료했습니다.

같은 staging directory의 아래 native 명령만 승인된 실행 환경 확장으로 재시도했습니다.

```bash
hdiutil create -volname 'Touch Me' \
  -srcfolder /Users/soom.kang/Desktop/work/2.services/touch-me/.build/dmg/eab5f12d-ee85-41ea-8eae-5fb695fed44e/contents \
  -format UDZO -fs HFS+ \
  /Users/soom.kang/Desktop/work/2.services/touch-me/.build/dmg/eab5f12d-ee85-41ea-8eae-5fb695fed44e/touch-me-0.8.0-beta.7-arm64.dmg
```

재시도는 성공했습니다. 실제 script의 AST에서 `validate_previous_pair`, `sha256_file`,
`promote_pair` 함수를 읽어 finalization을 이어서 수행했습니다. Script 전체를 다시
실행하지 않았고, staged image 옆에 sidecar를 저장한 뒤 반영했습니다. Native create
시도는 **실패 1회, 성공 1회**이며 완료된 앱과 DMG는 **각각 1개**입니다. 앱은 다시
빌드하지 않았습니다. 기존 Command Line Tools linker search-path warning은
비치명적이었고 컴파일은 성공했습니다.

패키징 전 새 beta.7 DMG/sidecar 경로는 모두 비어 있었습니다. 첫 생성이므로 native
previous-pair replacement/rollback은 `NOT_EXERCISED`입니다. 이전 22개 packaging
tests가 해당 failure injection을 검증했으며 source가 유지돼 그 결과를 재사용합니다.

## Scan observation and limits

`main.swift`의 `--scan`은 `AppDelegate`와 `ProofModel` 생성 전에 종료하며
metadata/화면 조회와 permission query만 수행합니다. 식별자를 제외한 결과는 다음과 같습니다.

| Field | Observed value |
| --- | --- |
| Mode | `metadata_only_no_open` |
| Query returned a set | true |
| Touch devices / eligible devices | 0 / 0 |
| Active / eligible external displays | 0 / 0 |
| Scan process Input Monitoring / Accessibility | false / false |
| Process exit | 3, the existing no-device exit code |

이 값은 해당 CLI 실행 환경의 관측입니다. 실제 패널 부재, unsupported hardware나
설치 앱의 권한 상태로 해석하지 않습니다. Raw contact reports와 장치 식별자는 저장하지
않았습니다. Sandboxed process query는 `sysmond service not found`로 실패했습니다.
이후 읽기 전용 실행 환경 확장의 `pgrep -x TouchMe`가 오류 없이 1을 반환해 해당
checkpoint에 matching process가 없음을 확인했습니다. 후보 GUI는 실행하지 않았습니다.

GUI startup은 startup recovery와 저장된 automatic resume에 따라 기존 journal/guard와
device mode를 처리할 수 있습니다. 이를 설명한 뒤 사용자는 상태 보존 범위의 검증을
선택했습니다. GUI 실행과 permission renewal은 시도하지 않았습니다.

## Preservation evidence

| Target | Before/after result |
| --- | --- |
| `/Applications/Touch Me.app` | All 5 file hashes unchanged |
| Recovery directory | All 7 existing file hashes unchanged; raw contents not logged/copied |
| Saved preferences file | SHA-256 unchanged |
| Previous local beta.6/build 24 app | Preserved with all file hashes under `dist/previous-builds/Touch Me-35e1ab30-0add-4893-bc86-f41a1d50f2c2.app` |
| Other local DMG/sidecar files | All 4 hashes unchanged |
| Tracked source/test/package inputs | All 43 hashes unchanged before/after the build and checks |
| Existing history files | Prior paths remain present |
| Privacy/login/trust settings | No grant, reset, registration or trust-changing command executed; TCC database contents were not inspected |

보존 검사는 위 파일의 content identity를 확인하며 extended attributes나 OS cache 전체를
검사한 결과는 아닙니다. 이전 Swift 38개/packaging 22개 PASS는 source-level regression
근거로 유지하며 source가 바뀌지 않아 suite를 다시 실행하지 않았습니다.

## Not run and stopping

- GUI, Start/Stop, delivered touch events and physical mode readback: `NOT_RUN`, by the agreed preservation-only scope.
- Installation, upgrade, Gatekeeper downloaded first launch, login/lock/sleep and crash/power-loss: `NOT_RUN`.
- Online Homebrew audit: prior trust-preserving `BLOCKED` deferral retained.
- Commit/push, publication, Cask/version change and deployment: not performed.

Hardware/lifecycle acceptance는 native 산출물 검사만으로 닫지 않습니다. 후속 GUI/device
검사에서 record, mode나 permission 변경이 필요하면 새 범위를 합의해야 합니다.
합의한 이번 범위는 검증된 로컬 산출물과 보호 대상의 보존 확인으로 완료했으며
추가 빌드는 필요하지 않습니다.

최종 문서 local link/anchor 189개, input manifest JSON, 변경 파일의 whitespace와
secret-like pattern 검사 및 `git diff --check`가 PASS입니다. 기존 source/test 변경은
유지했으며 이번 native 작업에서 새 source 수정은 없습니다. Final repository 상태는
tracked 수정 15개와 untracked QA 문서/manifest 4개이며 산출물은 기존 ignored `dist`에 있습니다.
