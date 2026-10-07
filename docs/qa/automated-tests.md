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

## Remaining test work

- SavedMapping persistence, malformed schema and identifier cases need an app
  state test seam; no executable-target dependency trick is introduced here.
- Feature write/readback/rebind failures need an injected HID adapter before
  deterministic device-mode tests can be written safely.
- App lifecycle message transitions need a model/observer test seam.
- Native release, restore, permission and login checks remain in the
  [build 11 checklist](build-11-release-checklist.md).

The ticket is partially addressed: runnable portable regression coverage and
Swift cases are added, but the above integration gaps remain open. Never replace
an UNTESTED native row with a mock result.
