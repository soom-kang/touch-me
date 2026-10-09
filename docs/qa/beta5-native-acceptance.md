# Beta.5 native acceptance — QA01 / TMQA003

## Postpublication record — 2026-10-09

Status: **PUBLISHED; public upgrade phase and installed artifact PASS; QA01
post-upgrade native batch PENDING**. TMQA003 retains its bounded build 23 PASS
from the prepublication run. No additional crash test was performed after the
public upgrade.

| Field / check | Public or installed evidence | Result |
| --- | --- | --- |
| Release source / peeled tag | `4ead3d1acec3beb43a1f09261b308ef9fdef0e81` | PASS |
| Annotated tag object | `fbea25d379fc533c040c53d0c4b8e8b31bd0c0ed` | PASS |
| Release | [v0.8.0-beta.5](https://github.com/soom-kang/touch-me/releases/tag/v0.8.0-beta.5), draft=false, prerelease=true; published 2026-10-09 07:43:52 UTC (16:43:52 KST) | PASS |
| Anonymous public assets | DMG 455,408 bytes, SHA-256 `919defb41f5700bc57bac6c680d1c4765e2b090cb7d82aabebbe06d1480e9321`; sidecar matches frozen candidate | PASS |
| Historical assets | Beta.4 asset-preservation audit | PASS |
| Tap main / installed Tap | `31cdb32c1e1415401c26fd338842bf811471b531`; clean; Cask equals reviewed contents | PASS |
| Public Homebrew upgrade phase | Beta.4 → beta.5 reported successful upgrade before later cleanup interruption | PASS (upgrade phase only) |
| Installed Applications app | Beta.5/build 23; executable `8a7d98412594ef164b9c3b73bc73d4f240c2978f42cc4a0e185e7f62ffda748e`; signature/license/icon match; build 21 backup retained | PASS (artifact only) |
| Overall upgrade command | Verified Homebrew PID `21614` interrupted during unexpected core clone at 17:48:57 KST; exited 130 after upgrade success | INTERRUPTED (post-upgrade cleanup) |
| Core clone cleanup | Exact core path and clone processes absent after automatic interrupt cleanup; no reset or untap performed | PASS (cleanup observation) |
| Installed GUI / native batch | Build 23 and permissions, target/Start, two-position taps, Stop and normal Quit requested; response pending | PENDING |
| QA01 | Public upgrade artifact completed; installed GUI/native acceptance still pending | PENDING / OPEN |

The unexpected clone was not an app install failure. The local Homebrew code
supports task-scoped `HOMEBREW_NO_INSTALL_FROM_API` plus post-upgrade cleanup as
the cause: finish-installation can run periodic cleanup, loading installed
formula definitions; explicit non-API mode makes CoreTap ensure its checkout.
Tap installation handles Interrupt by removing its exact path and an empty
parent. After the interrupt, read-only checks found no
`/opt/homebrew/Library/Taps/homebrew/homebrew-core`, its `.git` or empty
`.../Taps/homebrew` parent, and no PID `21614`, `git` or `git-remote-https` process.
No additional Homebrew command, reset, untap or deletion was needed. The whole
command's exit 130 is retained separately from the successful upgrade phase.

At 17:50:46 KST, new retained diagnostic session
`289E4FD5-302D-4298-8FC2-21A7A11B8130` captured `(0,0)` on the same recorded
HID/USB identities, location and descriptor. This read-only baseline is not
post-upgrade GUI or product-restoration proof. The installed-app manual batch
remains pending; the candidate's earlier native result does not replace it.

The shipped release notes remain unchanged as their dated prepublication
snapshot. No source/package rebuild or further crash test was performed for
this documentation update.

## Historical prepublication checkpoint — 16:24 KST

Prepublication acceptance record, 2026-10-09 16:24 KST (`Asia/Seoul`). Status at
this checkpoint: **READY_FOR_RELEASE_REVIEW / NOT_PUBLISHED**. Build 23's local
checks and one controlled original-0/same-boot/continuous-P16KT SIGKILL recovery
are PASS. Normal/relaunch and post-crash gesture results are PASS_USER_REPORTED.
QA01 public upgrade remains NOT_RUN; historical build 22 recovery remains FAIL.
This record concerns the new candidate and its later public upgrade; historical
[beta.4 build 21 evidence](build-21-native-checklist.md) remains separate.

## Historical prepublication journal candidate

| Field | Current evidence |
| --- | --- |
| Source | Workspace based at `dac55ff229cec870d69002cffc05aa8272d7a254`, branch `codex/tmqa-beta5`, with uncommitted journal implementation; final release revision pending |
| Policy | User approved strict journal and one additional controlled SIGKILL retest |
| Build | Verified beta.5 build 23 at 15:32 KST; strict signature, arm64, metadata, license/icon and 28 frozen inputs match |
| Executable SHA-256 | `8a7d98412594ef164b9c3b73bc73d4f240c2978f42cc4a0e185e7f62ffda748e` |
| DMG / checksum | `touch-me-0.8.0-beta.5-arm64.dmg`, 455,408 bytes; SHA-256 `919defb41f5700bc57bac6c680d1c4765e2b090cb7d82aabebbe06d1480e9321` |
| Native retest | Build 23 normal/relaunch and post-crash batch PASS_USER_REPORTED; same-device journal recovery before resume and final `(0,0)` readback PASS for this one controlled case |
| Publication / Tap | READY_FOR_RELEASE_REVIEW / NOT_PUBLISHED at this prepublication checkpoint; publication/asset verification and public upgrade not performed |

## Historical build 22 artifact identity

| Field | Current evidence |
| --- | --- |
| Candidate source | Workspace based at `dac55ff229cec870d69002cffc05aa8272d7a254`, branch `codex/tmqa-beta5`; final release revision pending |
| Release metadata | Verified `TouchMeReleaseVersion=0.8.0-beta.5`, numeric version `0.8.0`, arm64 |
| Build | Verified 22 from installed build 21 |
| DMG / SHA-256 | `touch-me-0.8.0-beta.5-arm64.dmg`, 419,445 bytes; `8faf802c23aee6ef6bcb3f948641e90fcfd398956c795c5a7fbede4c2e3d996a` |
| Publication / Tap | Build 22 was not published; no public beta.5 asset or Tap update recorded |
| Native setup | macOS 26.7.1 (25G241), arm64, Mac16,5; verified P16KT at USB location `34799616` |
| Candidate executable | `dist/Touch Me.app/Contents/MacOS/TouchMe`, SHA-256 `9290e1d9dadea4d7af3e1492b9b817cf8e85dafc077ecabbcbc19ac8e87ba0ea`; running path verified below |

Before a native result, record macOS version, architecture, panel identity,
USB port, other mapper state, bundle version/build, executable path, operator
and test time. Do not record credentials or raw personal touch data. Confirm
that the candidate process is running rather than an existing app with the same
bundle identifier.

## Approved checks

Retain existing privacy permissions. Renew only if necessary; do not turn them
off to manufacture a missing-permission test. Use the existing proof window and
counters for the affected gestures; counters establish post calls, not receipt
by another app.

### Journal implementation and retest

| Check | Evidence | Result |
| --- | --- | --- |
| Journal policy | Approved and implemented in source, separate from saved mapping | IMPLEMENTED; bounded native PASS |
| Source compilation | All targets compiled after the journal change | PASS |
| Focused backend checks | Existing DeviceMode checks 3; new journal checks 6 | PASS |
| Journal candidate build | Build 23, strict signature, arm64, metadata, license/icon, frozen inputs 28 | PASS |
| Journal candidate package | 455,408-byte DMG; integrity, sidecar and final package-input comparison match | PASS |
| Mounted DMG contents | Read-only mount: inner executable SHA matches build 23, strict signature, license/icon and installation guidance match; normal detach | PASS |
| Journal candidate Cask | Actual temporary `.rb` syntax and Homebrew style: one file, no offenses; independent four-file Tap draft review has no findings | PASS (local draft) |
| Candidate identity | Sole PID, exact candidate path, build 23 and frozen executable SHA verified before normal-route SIGTERM | PASS |
| Candidate settings / permissions | User confirmed build 23 version and both permissions | PASS_USER_REPORTED |
| Target confirmation | User confirmed cancellation → Refresh retains Start blocking | PASS_USER_REPORTED |
| Normal gestures / counters | Two-position taps, double tap, drag, horizontal/vertical scrolling and existing counters in the requested batch | PASS_USER_REPORTED |
| Stop-state / Quit-resume persistence | Stop → Quit → relaunch remains stopped; active mapping → Quit → relaunch resumes; final Stop → Quit | PASS_USER_REPORTED |
| Normal Quit route readback | App absent; same-session `(0,0)` at 16:20:05 KST; recovery record absent at 16:20:06 KST; preceding mapping not directly observed | PASS (readback only) |
| Additional SIGKILL / retention | Explicit active-mapping/no-held-input readiness; one guarded SIGKILL; process absent; before relaunch `(2,0)` and exact record survived | PASS (observation only) |
| Previous-record recovery before resume | Exact candidate PID/path logged verified recovery and record clearing at 16:22:50.076056 KST | PASS (this controlled case) |
| Post-crash user batch | Explicit automatic resume, two-position taps, no error, Stop and normal Quit | PASS_USER_REPORTED |
| Post-crash cleanup readback | App/record absent at 16:24:39 KST; same-device `(0,0)` fresh read at 16:24:41; helper feature writes 0 | PASS |
| TMQA003 bounded acceptance | Original mode 0, same boot and continuous verified P16KT attachment, one additional SIGKILL | PASS (bounded scope) |
| Public upgrade / release | Release review and publication/asset verification precede public upgrade; recovery hold resolved for tested scope | NOT_RUN |

The initial journal run failed when its fixture used a `/var` alias rejected by
the safe-path guard. Changing only the fixture to literal `/private/tmp` passed
all six; the production guard was preserved. These backend results do not prove
HID behavior on the physical panel.

The journal is durably and atomically stored before `(0,0) → (2,0)`, under an
exclusive lease and an exact record nonce. Recovery requires the same boot,
HID/USB registry identities, USB location and descriptor on the continuously
attached verified device and a proven-dead predecessor. It verifies original
readback and removes the same record before mapping resumes. Live, reused or
unknown owners, malformed/stale records and changed attachments block startup
without guessed writes. Initial mode 2 without a record does not imply mode 0.
An inactive blocked startup may Quit while preserving the record; this owner's
pending restoration continues to block Quit. Same-port reconnect cannot bypass
identity. Public API, saved-mapping schema, layout and dependencies are retained.

At 15:32:41 KST the new retained diagnostic session
`5391B7F7-23D5-408A-9825-B24F45CFA0E1` captured baseline `(0,0)` on the same
recorded HID/USB IDs, USB location and descriptor below. This is the new retest
baseline, not product recovery evidence. Later normal-route and SIGKILL
observations follow below.
At the initial pre-retest checkpoint, the retained session was alive with no
later diagnostic feature write or additional SIGKILL. That process check found
no TouchMe process and no production journal directory; those absences did not
establish prior launch history or recovery behavior. The later normal batch
below supersedes that checkpoint.

The user replied “모두 정상적으로 작동합니다” to the explicit build 23 batch:
version and both permissions; target cancellation → Refresh retaining Start
blocking; two-position taps, double tap, drag, horizontal/vertical scrolling and
existing counters; Stop → Quit → relaunch staying stopped; active-mapping Quit
→ relaunch resuming; final Stop → Quit. Only those requested outcomes are
`PASS_USER_REPORTED`, without a direct agent GUI/event trace.

At 16:19:16 KST PID `4443` was still running. The production journal directory
existed with mode `0700`, but its record was absent. A helper read at 16:19:18 KST
returned an app-running guard error before opening HID: no I/O and no product
failure result. After sole-PID, exact-path, build 23 and executable-hash guards,
one `SIGTERM` was sent through normal Quit at 16:19:54.669911 KST. Process absence
was confirmed. At 16:20:05 KST the retained original session
`5391B7F7-23D5-408A-9825-B24F45CFA0E1` freshly read `(0,0)` on the same identity,
`identityRejected=false`, `unresolved=false`. At 16:20:06 KST the record remained
absent. The direct result is normal-route readback only; immediately preceding
mapping and earlier record creation/removal were not directly observed.

The user then explicitly confirmed active build 23 mapping with no held input.
At 16:21:56 KST inspection confirmed the same diagnostic session and no identity
rejection. Sole candidate PID `5661` was checked against exact path, build 23 and
frozen executable SHA. Its `0600` recovery record captured original `(0,0)`,
matching boot, HID registry `4295075832`, USB registry `4295075820`, location
`34799616` and descriptor SHA recorded below. Owner PID/start was
`5661` / `1791530424.427586`; nonce was
`EC54D2E2-27F1-4552-9258-61E21C364D1F`.

Exactly one additional SIGKILL was sent at 16:21:59.933172 KST and process
absence was verified. Before any relaunch, the same-session read at 16:22:04 KST
returned `(2,0)`, `identityRejected=false`, `unresolved=true`; the exact same
record survived. Retained-mode/journal observation is `PASS`; mode 2 before
relaunch alone is not a product FAIL. The helper performed zero feature-mode
writes in this session: only arm/read/inspect, with no roundtrip or restore.

On relaunch, the exact candidate executable path/PID `7323` logged
`Previous mode recovery verified; record cleared before mapping resume` at
16:22:50.076056 KST in `MappingRecovery`. The user explicitly reported
“자동 재개·두 위치 탭 정상, 오류 없음, Stop·정상 Quit 완료” for that requested
post-crash batch (`PASS_USER_REPORTED`). At 16:24:39 KST no TouchMe process or
recovery record remained. Fresh read at 16:24:41 KST in the same original
diagnostic session returned `(0,0)`, `identityRejected=false`, `unresolved=false`.
The helper exited at 16:24:53 KST with exit code 0, zero feature-mode writes
throughout the session and no write on exit.

The observed chain is captured 0 → guarded SIGKILL → retained 2 plus exact
record → candidate-verified original recovery/record cleanup before resume →
reported normal mapping/Stop/Quit → direct final 0. TMQA003 is `PASS` for this
one controlled original-0, same-boot and continuously attached P16KT case.
Recovery after reboot, re-enumeration, replacement, power loss or a native
initial-mode-2 fault remains `NOT_RUN`; this result does not establish those
conditions. QA01's candidate batch is `PASS_USER_REPORTED`, but its public
Homebrew upgrade remains `NOT_RUN` and the ticket stays open. The recovery hold
is resolved for the tested scope; publication awaits release review.

DMG creation initially failed in the default sandbox with a device-configured
error. Retrying the identical packaging script with the required native
permission passed without rebuilding the app. The final 28-input package
comparison passed. Package installation guidance was aligned with the strict
same-connection Retry policy; compiled/bundled inputs were unchanged from build
23. Cask caveats use the same policy. Package, mount and local Tap checks do not
establish a public asset or installed-device behavior.

### Historical build 22 checks

| Check | Acceptance evidence | Result |
| --- | --- | --- |
| Existing Swift checks | Planning-phase `bash scripts/test.sh`: 24 tests (11 Platform, 13 Core), reused without another run | PASS |
| Candidate build | One `bash scripts/build-app.sh`: build 22, strict ad hoc signature, metadata, arm64, exact license/icon, 27-input manifest comparison | PASS |
| Package / integrity | One `python3 scripts/package-dmg.py`; correct-path `hdiutil verify`; SHA-256 sidecar verification | PASS |
| Cask syntax | Ruby syntax on temporary `Casks/touch-me.rb` | PASS |
| Cask style | Homebrew 7.0.9 style on the exact temporary `.rb`: one file inspected, no offenses | PASS |
| Existing app metadata scan | Installed beta.4 build 21 `--scan`: one verified `0457:0819` device, `canStartProof=true`, four displays/three eligible; no device open | PASS (metadata only) |
| Diagnostic fallback | Unarmed restore edge performs no HID access; armed same-device `(0,0) → (2,0) → (0,0)` with verified readbacks and no unresolved restoration | PASS (diagnostic only) |
| Candidate launch identity | Full-path launch; build 22 executable path and SHA-256 match the frozen candidate | PASS |
| Candidate settings / permissions | User confirmed beta.5/build 22 and both permissions; agent GUI read remains unavailable | PASS_USER_REPORTED |
| Target confirmation | After Stop, cancel → Refresh keeps Start blocked; P16KT test window reconfirmed, then Start succeeds | PASS_USER_REPORTED |
| Basic coordinates / gestures | Two separated taps, double tap, drag, horizontal and vertical scrolling reported normal | PASS_USER_REPORTED |
| Stop → normal Quit | User confirmed requested Stop followed by normal Quit; later mode observation is recorded separately | PASS_USER_REPORTED |
| Remaining gesture edges | Separate event evidence for staggered contacts, first-finger drag ownership and full-lift reset | NOT_RUN |
| Stop-state / Quit-resume persistence | Relaunch after Stop; normal Quit while mapping followed by allowed resume | NOT_RUN |
| Mode readback after normal Quit route | Same diagnostic session read captured `(0,0)` after exact-path/sole-PID guarded `SIGTERM`; preceding app mapping state not directly observed | PASS (readback only) |
| SIGKILL / retained-mode observation | One guarded `SIGKILL`; process absent; before relaunch, same-device mode `(2,0)` retained against saved original `(0,0)` | PASS (observation only) |
| Post-crash Stop / normal Quit | User reported “중지·정상 종료 완료”; app-stopped guard passed before readback | PASS_USER_REPORTED |
| Post-crash pre-crash-mode restoration | Same-device read after Stop/normal Quit retained `(2,0)` instead of captured original `(0,0)`; only this one SIGKILL/setup | FAIL |
| Post-crash automatic resume / error UI | Explicit automatic-resume and error outcome not reported | NOT_RUN |
| Diagnostic fallback after crash | Explicit restore captured `(0,0)` on the same identity; fresh readback and clean helper exit | PASS (diagnostic only) |
| Public beta.4 → beta.5 Homebrew upgrade | Not performed for build 22 | NOT_RUN (BLOCKED) |
| Release execution | Release commit/push, tag, publication and Tap update held | NOT_RUN |

The first DMG verification command repeated the `dist` path and failed with
file-not-found; correcting the path passed without rebuilding the artifact.
The first `brew style --cask` attempt failed on API/DNS access and the unregistered
temporary Cask. The corrected file-style invocation used
`HOMEBREW_NO_AUTO_UPDATE=1`, `HOMEBREW_NO_INSTALL_FROM_API=1`,
`HOMEBREW_DEVELOPER=1` and task-scoped cache/temp paths; it passed without changing
permanent Homebrew settings or trust.
The metadata scan's permission values belong to that scan process and do not
establish candidate GUI permissions, device-mode I/O or gesture behavior.
`/Applications/Touch Me.app` remains beta.4 build 21. Local beta.3 build 20 and
installed build 21 copies were preserved before preparation, and build 20 also
remains in `dist/previous-builds`.

## Historical build 22 native observations

At 13:26:26 KST, the retained diagnostic process (PID `85645`, PTY `49904`)
captured original mode/identifier `(0,0)`. The verified device had registry ID
`4295075832`, physical ID `4295075820`, USB location `34799616` and descriptor
SHA-256 `09c2703f6c8a73b14dab47f0ec7efafeb83b29705a96d7a2b56b6c855bfd858e`.
At 13:26:41 KST, its controlled roundtrip wrote mode 2, verified readback, restored
the captured pair and verified `(0,0)` on the same identity. It reported
`RESTORE_VERIFIED`, `ROUNDTRIP_VERIFIED`, `unresolved=false`. This verifies the
diagnostic fallback, not the app's cleanup or cross-process crash recovery.

At 13:26:59 KST, full-path app selection launched candidate PID `86072`.
`lsof` confirmed
`/Users/soom.kang/Desktop/work/2.services/touch-me/dist/Touch Me.app/Contents/MacOS/TouchMe`.
The executable matches the historical build 22 SHA-256 above. Bundle-ID resolution was ambiguous
because earlier preserved copies exist; no alternate copy was launched.

Repeated native UI reads failed with
`Sky Computer Use native pipe closed before response`, including a reset and
full-path retry. At that point the agent performed no UI click, permission change, gesture,
Stop/Quit or `SIGKILL`. Initial HID-scan logs do not establish that mapping started.

The user subsequently replied “전부 확인했습니다 정상입니다” to the bounded
manual request: candidate beta.5/build 22 and both permissions; Stop → target
confirmation cancellation → Refresh with Start still blocked; reconfirm the
P16KT test window → Start → two-position taps, double tap, drag and horizontal/
vertical scrolling; Stop → normal Quit. These rows are `PASS_USER_REPORTED`,
without direct agent UI/event observation. The reply does not establish mode
readback, relaunch state, Quit-while-mapping resume, `SIGKILL` recovery or the
public Homebrew upgrade.

After that report, another candidate process (PID `3781`) was confirmed at the
same build 22 executable path. One `SIGTERM` was sent after exact-path and
sole-PID checks; AppDelegate routes this signal through normal Quit. At
13:54:07 KST, the retained helper's original session
`D654E073-C06E-406E-899E-5F92E1452E32` read `(mode: 0, identifier: 0)` on the same
device, with `identityRejected=false` and `unresolved=false`. This is a direct
readback of the captured original pair after the normal Quit route. The app's
immediately preceding mapping state was not directly observed, so it does not
establish restoration during Quit while mapping. No `SIGKILL` had been performed
at that point.

The user later explicitly confirmed “매핑 중, 누름 없음, 강제 종료 시험 준비 완료”.
At 14:04:27 KST, the retained helper inspected the same original session and
reported `identityRejected=false`, `unresolved=false`. Candidate PID `12088`
was the sole app process; exact executable path, version/build and frozen
executable SHA-256 were checked before sending `SIGKILL` exactly once at
14:04:47.716572 KST. The subsequent process check reported
`noRemainingTouchMe=true`.

Before any relaunch, the helper read the same device at 14:04:53 KST and returned
`(mode: 2, identifier: 0)`, `identityRejected=false`, `unresolved=true`. Thus the
captured original `(0,0)` was not restored when the owner exited. The next
Stop/Quit observation is recorded below.

The full-path CUA relaunch call returned a native-pipe connection error after
816.75 seconds. A later process check at 14:18:49 KST found PID `21237` at the
exact candidate path. That confirms a candidate process at the check time, not
the relaunch latency or automatic mapping. Helper inspection at 14:18:53 KST
kept the same original session, `identityRejected=false`, `unresolved=true`.
The user was asked to report automatic resume and then Stop → normal Quit.
They replied “중지·정상 종료 완료”; no explicit automatic-resume or error outcome
was reported. After the app-stopped guard passed, a same-original-session read
at 14:30:35 KST returned `(mode: 2, identifier: 0)`, `identityRejected=false`,
`unresolved=true`. The app had not restored the captured pre-crash `(0,0)` pair:
this recovery acceptance is `FAIL` for this one conditional SIGKILL/setup.

Explicit diagnostic restore at 14:30:43 KST reported `RESTORE_VERIFIED`,
`(mode: 0, identifier: 0)`, the same identity and `unresolved=false`. An additional
read at 14:31:01 KST again returned `(0,0)`, `identityRejected=false`,
`unresolved=false`. The helper exited at 14:31:03 KST with exit code 0 and no mode
write on exit. Final observed device state is the captured original `(0,0)`.
The complete observed sequence was captured 0 → post-SIGKILL 2 → post-Stop/normal
Quit 2 → explicit diagnostic restore 0. This was diagnostic recovery, not a fix
to the frozen build 22. The later journal implementation and build 23 are tracked
separately above.

At the historical build 22 checkpoint, publication was HOLD / NOT_PUBLISHED and
TMQA003 awaited journal implementation/retest; QA01 public upgrade was
`NOT_RUN`. Release commit/push, tag, publication, Tap update and upgrade were not
performed. For historical build 22, Stop-state relaunch and Quit-while-mapping
resume remain `NOT_RUN`; its ready message was not an explicit outcome.
Build 23's later user-reported normal lifecycle results are recorded above.

The abnormal-exit row follows
[TMQA003's decision gate](abnormal-exit-recovery.md). If a fallback cannot be
verified, do not kill the process. If mode-retention evidence is inadequate,
hold publication. Reopening the app or a successful later Stop does not prove
the previous owner's original mode was restored. Record any recovery attempt
and its outcome without writing an assumed mode value.

## Excluded checks and stopping

Fresh installation, permission off/on, lock/unlock, sleep/wake, full logout/login
and removal are **NOT_RUN** and outside this approved pass. An upgrade does not
establish fresh installation or Gatekeeper behavior on another Mac. Login-item
source changes do not establish login behavior here.

Use `PASS`, `PASS_USER_REPORTED`, `FAIL`, `PENDING`, `NOT_RUN` or `BLOCKED` with the actual
observation per row. Identify reports as user-reported when the agent did not
observe them. A failure needs the exact artifact, sequence, expected/actual
result and recovery outcome. Stop the affected operation for unresolved restore
errors; preserve the prior app and preferences. QA01 and TMQA003 close only for
the evidence-backed scope, with excluded checks left visible.
