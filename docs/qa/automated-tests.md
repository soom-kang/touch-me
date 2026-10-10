# Automated QA layers

Ticket: TMQA-005. Tests added here are not a claim that native tests passed.
No CI service, external dependency, device driver, or permission change is added.

## Beta.7 release boundary — 2026-10-10

Beta.7 was **PUBLISHED** on 2026-10-10 at 14:25:14 KST (05:25:14 UTC).
Public DMG/sidecar verification and public/installed Tap revision checks passed.
Local build 25 and packaging passed; reuse the source's 37
Swift tests and one development build 24 USB-C cycle (`PASS_USER_REPORTED`),
bound to executable SHA-256
`06306a6ed873d314ab565066b42d5a022618ea067a53cd76abceb7333f2e41f7`.
The snapshot below retains its exact scope; new build 25 GUI/device, installation,
upgrade and Gatekeeper are `NOT_RUN`. No direct mode-pair readback, independent
device-write count or broader recovery acceptance is added. Online audit is
`BLOCKED` by the approved trust-preserving deferral, separate from beta.6's
historical PASS. See [beta.7 release notes](../releases/v0.8.0-beta.7.md) for new
artifact and publication results. Earlier release/QA observations stay historical.

## USB-C reconnection candidate — 2026-10-10

Use the existing Swift targets and `bash scripts/test.sh`; no separate runner,
device simulator or new dependency is added. The stable-source
`bash scripts/test.sh` run passed 37 tests (24 Platform, 13 Core) and app
compilation. The candidate app build and native-cycle status are recorded in
[Workflow](../../Workflow.md#usb-c-reconnection-candidate--2026-10-10).
The earlier Linux results below remain historical and do not describe the
current Mac's tool availability or candidate checks.

Focused coverage belongs in the existing journal, transaction and recovery
tests:

- Journal: exact ended-service proof and same-boot/owner/nonce rejection,
  private archive and durable guard, and retry after interrupted saves or
  removal sync. Query failures must preserve the active record. Unchanged
  original modes 0/2 also persist a guard, complete a missing canonical archive
  after restart, and retain the guard when acknowledgement sync fails.
- Transaction: a fresh `(2,0)` read after open rejects automatic Start with
  zero mode writes; informed manual Start and Stop preserve that pair.
- Recovery window: repeated readiness events keep the first device
  reappearance's fixed ten-second deadline.

These checks do not open a real HID device or establish the native exclusive
open, service termination, permissions, screen state or delivered touch events.
One `bash scripts/build-app.sh` run passed candidate compilation/bundling and
the built-in `codesign --verify --strict`, producing local beta.6/build 24;
the approved **Start → same USB-C disconnect → reconnect → automatic resume →
two-position taps → Stop** device cycle passed once on 2026-10-10
(`PASS_USER_REPORTED`). With the focused test/build results, the approved
completion scope is met. Keep original-mode-2 physical
behavior, reboot, lock/sleep regression, Gatekeeper and Homebrew upgrade results
separate. Preserve previous apps and artifacts.
The first `bash scripts/test.sh` attempt failed to compile a new test due to a
missing `try`. Its correction produced an interim 36-test PASS; the final
stable-source 37-test run includes the review changes. Existing Command Line
Tools linker search-path warnings were non-fatal. The previous app's normal Quit
is `BLOCKED_USER_REPORTED`. After initial CUA and sandboxed launch failures, a
separately approved transition preserved the active record and installed bundle;
the sole local candidate launch is tool-observed `PASS`. Its log confirms the
ended predecessor archival path ran before scanning. These process/log results
do not establish device-mode write counts. No direct mode-pair readback or
independent hardware write-count measurement was taken in the user-reported
cycle. See Workflow for the exact candidate identity, bounded transition
evidence and separately recorded physical result.

## Portable packaging tests

From the repository root:

```bash
python3 -m unittest discover -s Tests/PackagingTests -v
```

The tests run the actual Python scripts in temporary copies. codesign, lipo,
ditto, and hdiutil are replaced with test doubles; fake executables and images
are never installed, mounted, or executed. PASS means Python packaging contracts
passed, not that Apple's native tools approved an app. Coverage includes version
validation, missing inputs, metadata, history, license/identity/architecture
rejection, checksum output, and prior-artifact preservation after tool failures.

## Swift tests on the supported build environment

```bash
bash scripts/test.sh
```

Existing core tests remain. New tests cover malformed coordinate inputs, integer
extremes, a one-pixel target, and platform ClickSequence time/distance boundaries,
cancellation, incomplete contacts, invalid intervals, and clock reversal.
The platform test target imports AppKit/IOKit dependencies but these test cases
only call pure ClickSequence logic; they do not request permissions or open HID.

On the Linux QA executor, Swift and xcrun are absent. The new Swift tests are
**NOT_RUN**, and the Swift test target still needs compilation on supported tools.
No external CI result is implied by adding these files.

## Focused macOS QA seams (2026-10-09)

The fix branch reuses the existing test targets. No CI service, device simulator,
app-target test framework, duplicated Python gesture model or dependency is added.
The added tests call small helpers used by production:

- `HIDContactFrameAssembler`: queued/mixed reports, callback order, unchanged
  axes, reused slots and rejection of future snapshots (TM PLAT 01).
- `HIDContactLayout` / `HIDMappingEligibility`: reject a partial or ambiguous
  contact layout while preserving unrelated vendor elements (TM PLAT 02).
- `TargetConfirmation`: explicit cancellation survives Refresh; a changed
  target is not already confirmed (APP-B01).
- `DeviceModeTransaction`: modes 0/2, partial write, failed readback/restore,
  replacement I/O preserving the original pair, and the cross-process ownership
  limit. P16KTDeviceMode retains all native descriptor/location validation.
- `RecoveryWindow`: settling can delay the next attempt but cannot extend the
  original ten-second deadline. ProofModel uses this helper and accepts a
  monotonic clock provider; the default remains system uptime (TMQA-005).

The 18 existing Python packaging tests passed on 2026-10-09 in Linux. Swift and
xcrun remain unavailable here: the new and existing Swift suites are **NOT_RUN**,
not PASS. `bash scripts/test.sh` must compile/run them on a supported authorized
Mac before these source fixes are release-ready. No new artifact was built.

## Remaining native and integration verification

SavedMapping persistence/schema validation and full AppKit lifecycle observation
are not expanded into a new framework in this task. The focused defects now have
production test seams; this is not exhaustive model or OS integration coverage.
Native descriptor validation/re-enumeration, feature I/O, permissions, UI states,
backlog event tracing and login behavior still require supported macOS/P16KT.
Use the [build 21 checklist](build-21-native-checklist.md) only for that historical
artifact, and a separately built candidate for the source fixes. TMQA-003's
approved build 23 continuous-attachment SIGKILL scope passed; that result does
not verify this candidate's USB-C cycle. See the separate
[recovery acceptance boundaries](abnormal-exit-recovery.md).
