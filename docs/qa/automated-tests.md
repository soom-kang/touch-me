# Automated QA layers

Ticket: TMQA-005. Tests added here are not a claim that native tests passed.
No CI service, external dependency, device driver, or permission change is added.

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
Use the [build 21 checklist](build-21-native-checklist.md) for the public artifact,
and a separately built candidate for the source fixes. TMQA-003 remains blocked
on its [hardware decision gate](abnormal-exit-recovery.md).
