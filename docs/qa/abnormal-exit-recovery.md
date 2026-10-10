# Abnormal exit recovery boundary

Ticket: TMQA-003. Status: **PASS for the approved build 23 controlled SIGKILL
on this same-boot, continuously attached P16KT, original `(0,0)`.** Historical
build 22 failed. Product recovery is verified for the approved scope. Build 23
is now [published as beta.5](https://github.com/soom-kang/touch-me/releases/tag/v0.8.0-beta.5);
the public download and Homebrew app replacement match the verified candidate.
QA01 is **PASS for the approved public upgrade and installed-app flow**:
permissions/taps/Stop/normal Quit are `PASS_USER_REPORTED`; process/record
cleanup and the same-identity current `(0,0)` pair are directly observed.
See the [postpublication record](beta5-native-acceptance.md).

After the installed-app Stop and normal Quit report, process and record absence
were confirmed at 18:03:47 KST. At 18:04:26 KST, a fresh read-only diagnostic
session returned `(0,0)` on the same boot, HID/USB registry IDs, location and
descriptor, matching the earlier baseline and app's recorded original pair.
The earlier helper session was no longer available; its in-memory snapshot was
not used for this final observation. The fresh helper performed zero feature
writes and exited normally. This upgrade check adds no crash-recovery claim.
Fresh installation, permission off/on, lock/sleep, full logout/login and removal
remain `NOT_RUN`; reboot, reconnection, power loss and other panels remain
outside the verified recovery scope.

## Ended-connection record handling — development candidate, 2026-10-10

The user reported that unplugging and reconnecting USB-C while Touch Me was open
left mapping blocked even after Retry restore. The supplied settings image shows
`mode_restore_0xE00002C0` and an unresolved restoration notice after disconnection.
This is incident evidence, not proof of the new candidate's behavior. The
approved physical reconnection cycle subsequently passed as `PASS_USER_REPORTED`
on 2026-10-10, within the scope recorded below.

An ended connection has a separate cleanup disposition from verified restoration.
The candidate never applies a previous attachment's original pair onto a newly
enumerated device. It must prove both exact recorded HID and USB active services
ended on the same boot; a registry query failure is not absence. Keep the active
record if either service remains active or any proof is uncertain.

The journal also requires its exclusive lease, a valid exact nonce and current
ownership or a predecessor proven dead. A live, reused or unknown predecessor,
changed boot, malformed record or unsafe path continues to block mapping. Under
those checks, a changed-mode active record uses this sequence:

1. Atomically preserve and sync private `disconnected-<nonce>.json`, retaining
   the original record as an unconfirmed restoration.
2. Persist and sync private `reconnect-required.json`.
3. Remove only the exact active record and sync the directory.

Retry an interrupted sequence with the same nonce, including after relaunch.
Verify an existing matching archive or guard before using it; do not overwrite
different records. Failed storage or directory sync remains visible and cannot
be reported as restored or silently discarded. The active-record and
`SavedMapping` schemas stay unchanged.

An original `(2,0)` session performs no mode change and has no schema-1 active
record to retire. It still requires a durable reconnect guard. When no active
record exists and the captured `(0,0)` or `(2,0)` pair remained unchanged, persist
the exact pair, attachment identity and owner in the guard first, then preserve
the corresponding archive. This guard-first path is limited to unchanged modes;
it does not replace the archive-first order for changed active records. If a
valid unchanged-mode guard survives restart without its archive, complete that
canonical archive using only the file evidence. No device-mode read or guessed
write is needed to complete that interrupted file transition.

If Start acknowledges a guard but the removal's directory sync fails, restore
the guard durably before rolling back or releasing the failed Start's lease.
If persistence also fails, keep the pending failure visible and block cleanup.
This prevents a failed Start from dropping the restart-time manual-mode gate.

The separate guard survives relaunch and requires the new connection's mode to
be read after exclusive open and final device/display/permission/session checks.
Only fresh `(0,0)` permits automatic Start. Clear the guard after the new
default-mode journal is ready, or after informed manual Start. If fresh mode is
`(2,0)`, automatic Start performs zero mode writes; the user may start manually
and Stop retains `(2,0)`. Do not infer that the new pair came from this app.

The candidate retains `stop()` and failure callbacks, adds a typed cleanup
disposition and a defaulted reconnection policy for `start()`, and exposes a
manual-Start-required error. This extension does not change the saved mapping
or old journal format. Archive success can unblock normal Quit for a proven
ended connection; an unresolved current connection or failed record handling
still blocks the relevant cleanup. An inactive predecessor record preserves the
existing normal-Quit allowance. Never delete a record to bypass this condition.

The cable-wait intent is local to the running app until successful resume.
Automatic recovery is limited to one supported P16KT at the saved USB location
and display UUID, with current eligible geometry and all guards satisfied.
Those checks do not prove it is the same physical panel: the verified profile
has no permanent individual identity. Reboot, power loss, other panels and
original-mode-2 physical behavior remain outside new acceptance. Test/build
results are recorded in [Workflow](../../Workflow.md#usb-c-reconnection-candidate--2026-10-10).
No new controlled crash-acceptance test, release or Homebrew activation was run.
The user reported the installed app's normal Quit blocked by a recovery error
(`BLOCKED_USER_REPORTED`). With separate one-time approval, exact path/PID 973
was checked twice, terminated once, and confirmed absent. The active-record
SHA-256 was unchanged before/after without logging its contents; the installed
bundle was preserved. This transition does not verify original-mode restoration
or authorize routine Force Quit.

After the initial CUA read and sandboxed launch failures, the approved launch
retry confirmed only the local candidate PID 53203 running (`PASS`). Its
13:24:13.214 `MappingRecovery` log confirms the ended predecessor archival path
ran before scanning; it is not an independent count of device-mode writes.
On 2026-10-10, the user confirmed that the requested **Start → same USB-C
disconnect → reconnect → automatic resume → two-position taps → Stop** cycle
succeeded once (`PASS_USER_REPORTED`). Together with the focused test/build
results, this meets the approved completion scope. No direct mode-pair readback
or independent device-mode write count was taken. Original-mode-2 physical
behavior, reboot, lock/sleep regression and broader crash recovery have no new
acceptance claim.

## Published beta.5/6 continuous-attachment recovery contract

`DeviceModeTransaction` keeps the original mode/identifier pair in memory.
`DeviceModeRecoveryJournal` adds a separate record before a verified `(0,0)` to
`(2,0)` change. The saved-mapping format and public API signatures/cases are
unchanged. Initial `(2,0)` without a record is accepted without a guessed reset.

The journal uses a private directory, atomic no-overwrite installation, file and
directory sync, a nonblocking lease and an owner PID/start-time identity. A
record binds to the boot session, exact HID and USB registry IDs, USB location
and descriptor SHA-256. Only that continuously attached device and a proven
absent predecessor may authorize cross-process recovery.

Startup recovery runs before mapping or automatic resume. Matching `(2,0)` may
be restored to the recorded `(0,0)`; matching `(0,0)` needs no mode write.
Readback and cleanup of the same nonce must succeed before a new mapping starts.
Malformed or stale records, changed attachment, live/reused/unknown owner and
unsafe journal paths preserve the record and block mapping. Same-port reconnect
cannot bypass these checks. Current-owner recovery and cleanup failures remain
pending until resolved.

The existing bilingual status and Retry restore control expose failures. An
inactive startup record that this process cannot recover allows normal Quit
while preserving the record. This owner's unresolved restoration still blocks
normal Quit. No dependency, UI layout, gesture contract or saved-mapping schema
was changed.

## Published beta.5 acceptance boundary

Use Stop and normal Quit. If restoration fails, keep the current connection and
use Retry restore. Do not continue an upgrade or removal with this process's
pending restoration. Do not reconnect as an automatic remedy or force mode 0 on
an arbitrary panel. Process disappearance and diagnostic fallback success do
not establish product recovery.

The accepted native scope is one continuously attached P16KT on this Mac, with
all held input released before one additional path/PID-verified SIGKILL. Read
mode before relaunch, then after relaunch/Stop/Quit. Preserve the exact build,
identity, pair and termination evidence. Power loss, reboot, re-enumeration,
original-mode-2 hardware behavior and other panels remain unverified.

## Earlier cloud disposition (2026-10-09)

Cloud QA had no macOS/P16KT access. It established the in-memory process-loss
limit through injected I/O and left TMQA-003 blocked. No journal was introduced
by that cloud change. The authorized local observation below supplied the
retained-mode evidence; the operator subsequently agreed the strict continuous-
attachment policy. Backend tests alone cannot close this ticket.

## 2026-10-09 local beta.5 preparation

The user authorized the current Apple Silicon/macOS 26+ setup, one conditional
`SIGKILL` observation after a verified fallback, and a temporary diagnostic tool.
The app's metadata-only scan found one eligible P16KT (`0x0457:0x0819`). The
earlier USB-registry query found no match and was not sufficient evidence of
disconnection.

At 13:26:26 (`Asia/Seoul`), the diagnostic helper captured `(mode=0,
identifier=0)` on the continuously attached verified HID/USB services. At
13:26:41, its explicit `0 -> 2 -> captured 0` roundtrip and readback passed with
the same registry identity, USB ancestor, location and descriptor. The helper
keeps this original pair only in its long-lived process memory, closes HID
between commands, and rejects a different or re-enumerated attachment. It is
not bundled or available as a product recovery feature.

The beta.5 build 22 candidate was launched from its recorded local path. Native
UI observation repeatedly failed with `Sky Computer Use native pipe closed
before response`, including after resetting the UI session. Candidate gesture,
Stop/Quit and abnormal-exit observations are not established by that launch.
At that stage, no `SIGKILL` had been performed. The operator subsequently reported normal
candidate permissions, confirmation-cancellation/Refresh behavior, basic
gestures and Stop/normal Quit (`PASS_USER_REPORTED`).

At 13:54:07, after one path-verified `SIGTERM` routed through the candidate's
normal Quit handling, the retained diagnostic process read `(0,0)` on the
original continuous attachment, with `identityRejected=false` and
`unresolved=false`. Mapping activity immediately before that signal was not
directly observed. Stop/relaunch and Quit-while-mapping/resume results remain
unreported separately.

The operator then confirmed active mapping with all fingers and mouse buttons
released. At 14:04:47, exactly one `SIGKILL` was sent to candidate PID `12088`
after rechecking the sole process, full executable path, beta.5/build 22 and
executable checksum. Process disappearance was confirmed. Before relaunch, the
original diagnostic session read `(2,0)` at 14:04:53 on the same attachment,
with `identityRejected=false` and `unresolved=true`. The original `(0,0)` was
not restored by process exit in this observed condition.

The full-path relaunch attempted by the UI tool returned a native pipe failure
after a long wait. At 14:18:49, PID `21237` was verified at the candidate path;
the helper still retained its original snapshot without identity rejection.
The operator then reported Stop and normal Quit completed. At 14:30:35, with
the app-stopped guard satisfied, the original diagnostic session read `(2,0)`
again on the same attachment, with `identityRejected=false` and
`unresolved=true`. The product did not restore the captured original `(0,0)`
through the observed relaunch/Stop/Quit flow. Automatic resume and absence of
UI errors were not separately reported.

At 14:30:43, an explicit diagnostic restore wrote only the captured `(0,0)` and
verified readback, reporting `RESTORE_VERIFIED` and `unresolved=false`. Another
read at 14:31:01 confirmed `(0,0)` without identity rejection. The diagnostic
exited at 14:31:03 with no write on exit. This fallback success does not resolve
the product failure. At that historical build 22 checkpoint, the app was
stopped and publication remained held.

A verified diagnostic fallback did not establish product recovery after app
exit. At that point the ticket remained open until a recovery policy was agreed,
implemented and verified. That build 22 SIGKILL result does not establish power-loss, reconnection,
original-mode-2 or other-panel behavior. See the
[beta.5 acceptance record](beta5-native-acceptance.md) for artifact identity,
observations and remaining checks.

## Historical approved strict recovery policy — build 23

Persist a separate, narrowly scoped recovery record before this process changes
verified `(0,0)` to `(2,0)`. Keep the saved-mapping schema, public API, visual
layout and dependencies unchanged.

- Bind the record to the boot session, exact HID/USB registry identities, USB
  location and descriptor. Restore before mapping resumes only when that
  continuous attachment is verified and no other owner is active.
- Claim the record atomically without overwriting an unresolved predecessor;
  uncertain owner identity or liveness blocks writes. Clear only the same
  record nonce. Complete predecessor recovery and record cleanup before a new
  mode change or automatic resume.
- Write and confirm the record before changing mode; if persistence fails,
  do not change mode. Preserve it through partial writes and failed readbacks.
- For a matching record, accept already-restored `(0,0)` without a mode write;
  restore captured `(0,0)` only from verified `(2,0)`. Delete the record only
  after successful original-pair readback. With no record, do not infer that
  an initial mode 2 previously belonged to this app.
- A malformed record, reboot, re-enumeration, replacement or identity mismatch
  must preserve the record and block mapping/automatic resume without a guessed
  write. Show the reason through the existing bilingual status/error UI.
  Same-port reconnect is not an automatic remedy under this strict policy.
  Existing same-port Retry must not bypass the record's attachment identity.
- A startup record rejected before this process owns active input must not
  trap the user in the app: allow normal Quit while preserving the record.
  Keep the current Quit-block behavior for this owner's unresolved restoration.

The operator approved this policy and one additional controlled SIGKILL retest.
The implementation is in build 23, subsequently published as beta.5 after
approval and the successful native retest. Build 22 remains a historical failed
candidate and was not published. This policy does not claim power-loss or
reconnection recovery. The additional native retest passed for the approved
continuous-attachment scope.

Validation stayed in the existing test target: three existing device-mode checks
passed, and six journal checks passed. They cover surviving records, readback,
initial mode 2, nonce/overwrite protection, identity/owner rejection, malformed
and symlink records, competing leases and retry after removal sync failure.
The first six-check run rejected a fixture path normalized to the macOS `/var`
symlink. The fixture alone was changed to literal `/private/tmp`; production
path guards were retained and the failed six checks were rerun successfully.
These backend results do not establish native product recovery.

## Build 23 normal-flow observation

The operator reported all requested build 23 checks normal: displayed version
and permissions, cancelled confirmation surviving Refresh, two-position taps,
double tap, drag, horizontal/vertical scrolling and counters, Stop/Quit/relaunch
staying stopped, and normal Quit while mapping followed by allowed resume.
These results are `PASS_USER_REPORTED`.

At 16:19:16 KST a candidate process still existed. The recovery directory was
private (`0700`) and the record was absent. A diagnostic read at 16:19:18 was
rejected by the app-running guard before any HID open. After verifying sole PID
`4443`, the full build 23 executable path and its checksum, the existing normal
Quit route received one SIGTERM at 16:19:54.669911. Process absence was confirmed.
At 16:20:05 the retained diagnostic session read `(0,0)` on the same attachment,
with `identityRejected=false` and `unresolved=false`; the record remained absent
at 16:20:06. This establishes normal-flow original-pair readback and cleanup.
Mapping immediately before the signal was not directly observed.

The operator was then asked to start mapping again and explicitly confirm all
fingers/buttons released before the exact-PID/record checks and one additional
signal. Publication was held at that pre-retest checkpoint.

## Build 23 additional SIGKILL — product recovery verified

After the operator explicitly confirmed build 23 mapping active with no held
input, the retained helper still reported no identity rejection at 16:21:56 KST.
The sole PID `5661`, exact candidate path, build 23 and executable SHA-256 were
verified. The private `0600` record contained original `(0,0)`, the same boot,
HID/USB IDs, location and descriptor, owner PID/start time and nonce
`EC54D2E2-27F1-4552-9258-61E21C364D1F`.

Exactly one additional SIGKILL was sent at 16:21:59.933172 KST, followed by a
confirmed absent app process. Before any relaunch, the same diagnostic session
read `(2,0)` at 16:22:04 with `identityRejected=false` and `unresolved=true`.
The exact original journal record survived. The helper has performed no mode
write during this build 23 session. Retained mode after SIGKILL is an observation; the relaunch recovery result
follows below.

The operator was asked to relaunch the full-path candidate, report automatic
resume and any recovery error, then test two-position taps and Stop/normal Quit.
The operator explicitly reported automatic resume, two-position taps, no error
and Stop/normal Quit completed (`PASS_USER_REPORTED`). Exact candidate-path
logs from relaunched PID `7323` at 16:22:50.076056 report predecessor mode
recovery verified and record cleared before mapping resume. At 16:24:39 the
app was absent and the record was removed. At 16:24:41, the same diagnostic
session read `(0,0)` with no identity rejection and no unresolved state.
It exited at 16:24:53 with code 0 and no exit write.

The complete measured sequence was original 0 → post-SIGKILL 2 →
post-relaunch/Stop/Quit 0. The helper performed no feature mode write during
this session, so its fallback did not produce this product recovery result.
This native scope is `PASS`. Reboot, reconnection, power loss, original-mode-2
hardware behavior and other panels remain `NOT_RUN`/unverified. Final release
review, publication, public checksum verification and the Homebrew app
replacement subsequently completed. The installed-app native acceptance is
tracked separately in the postpublication record; no further crash test was
performed for that upgrade.
