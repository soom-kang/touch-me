# Automated QA layers

Ticket: TMQA-005. Tests added here are not a claim that native tests passed.
No CI service, external dependency, device driver, or permission change is added.

## Public beta.10 retention — 2026-10-14

**PUBLISHED; IN_PLACE_UPGRADE_PASS; PASS_USER_REPORTED_ON_THIS_MAC**.
Release source/tag `8aaebe4530ece3e0b6309c3be0df3c2d57e4d07f`/`v0.8.0-beta.10`
match all 43 frozen inputs; public DMG/sidecar equality passed. The Cask publication
Tap is `27fd12ee7e39ec383919fd5333120afc55768ea4`. One normal beta.9 → beta.10
upgrade exited 0 at 2026-10-14 01:19:31 KST (2026-10-13 16:19:31 UTC).
Installed five-file equality, strict certificate/DR, receipt and outer
device/inode preservation passed; selected-Cask/whole-Tap trust stayed true/false.

A9 PID `35272` had both GUI permissions Allowed after initial approval and quit
normally. New B10 PID `60924` matched the exact public installed path/hash and
beta.10/build 28. The user confirmed Accessibility and Input Monitoring both
Allowed without reapproval. Native provenance was reconfirmed at 01:27:59 KST
and state preservation at 01:28:03 KST (2026-10-13 16:27:59/16:28:03 UTC).
Preferences/saved mapping/guard/recovery hashes remained unchanged;
`resumeMapping=false`, active 0, valid guard 1, archives 5. No Start or privacy
change was invoked. GUI flags are user-reported; this PASS covers this Mac,
user and installation path. Automated GUI reading failed once with a closed
native pipe; native process checks are not direct GUI permission readings.

The first post-upgrade assertion compared prerelease with numeric
`CFBundleShortVersionString`; verification continued after correcting the field
to `TouchMeReleaseVersion`. No second upgrade was run; the initial failure is
retained. Native build/package one each and app/DMG checks passed. Same-certificate
A9↔B10 DR passed bidirectionally with different executable bytes/cdhash. Nonfatal
CLT warnings were retained. Equivalent Cask rules passed with existing compatible
`spoom 1.8.9`, not the exact locked toolchain; online audit remains **BLOCKED**.
Fresh Gatekeeper, receiving Mac without signing identity or added trust and
physical-device acceptance remain **NOT_RUN**. No runtime/test infrastructure
changed or source suites repeated. [Release details](../releases/v0.8.0-beta.10.md)
and [Workflow](../../Workflow.md#beta10-publication-and-upgrade--2026-10-14) retain
exact artifacts and scope. Older records below are their dated checkpoints.

## Public signed beta.9 — 2026-10-14

Beta.9/build 27 is **PUBLISHED** at source/tag
`0414617c860451e0c7b2200294b0eeca651f9ad9`/`v0.8.0-beta.9`.
All 43 frozen inputs match the exact tag; anonymous public DMG/sidecar bytes
match the native candidate. Public and clean installed Tap are
`65d13988d6f4bb415df8f5d6853a8c38c8d3b7fc`. One normal Homebrew beta.8 → beta.9
upgrade exited 0. Installed five-file equality, strict certificate/DR and outer
device/inode preservation passed. The immediate App Management condition passed
in the actual `brew` host; selected-Cask/whole-Tap trust remained true/false.
[Workflow](../../Workflow.md#public-signing-validation--2026-10-13) and
[release notes](../releases/v0.8.0-beta.9.md) retain exact identities/times.

Initial A9 PID `26957` had user-reported one or more required permissions;
individual before flags are unknown. After initial approval/restart, PID
`35272` matched the public path/hash, and the user confirmed GUI beta.9/build
27 with both permissions Allowed. Baseline is
**PUBLIC_SIGNED_A9_GUI_PERMISSION_BASELINE_PASS_USER_REPORTED**. Normal Quit
is user-reported and native PID absence passed; no Start was invoked. The
automated GUI channel remained unavailable after reset/retries.

Read-only postlaunch preferences/saved-payload/guard/recovery-manifest hashes
match the preinstall baseline: `resumeMapping=false`, active 0, valid historical
guard 1, archives 5. The earlier-boot guard was preserved; current-boot equality
is not a prerequisite for the no-active-record path. Initial restricted queries
were retained before successful native process confirmation. Physical mode and
durable cleanup were not measured.

At the 2026-10-13 native checkpoint, one build and one package exited 0; app/DMG
checks and normal detach passed without launching the candidate. Equivalent
Homebrew Cask style rules passed one file/no offenses after initial exit 2 for
missing locked `spoom 1.8.10`, using installed compatible `1.8.9` through a
process-only load path. Exact locked-toolchain validation did not pass; online
audit stays **BLOCKED**. No suite was repeated or runtime feature/test
infrastructure added for these artifact/publication checks.

At this A9 checkpoint, beta.9 → beta.10 retention was **NOT_RUN**; the later
[beta.10 result](#public-beta10-retention--2026-10-14) supersedes that status.
Fresh Gatekeeper, physical-device acceptance and a receiving Mac without
installed signing identity or added trust remain **NOT_RUN**. Existing source-test and probe results below retain their scopes.
Keep receipts, preferences and recovery; retain the confirmed A9 allowed state before measuring B.

## Current checkout check — 2026-10-12

On macOS 26.7.1/arm64 with Apple Swift 6.4 and Python 3.9.6, the modified checkout
on `65a8e71` passed `bash scripts/test.sh` (25 Platform + 13 Core tests, with App
compilation) and `python3 -m unittest discover -s Tests/PackagingTests -v`
(22 tests), once each after the fixes. Earlier baseline 37/18 and Linux results
remain historical snapshots, not these modified-source results.

The [current QA report](2026-10-12-qa-report.md) records source-fixed TMQA-006/007.
One existing-target Swift regression test checks predecessor unlink/sync failure,
lease reacquisition, another sync failure, successful confirmation and new-record
preservation. Four packaging tests check staged checksum failure, four rename
failure boundaries, incomplete/mismatched prior pairs and rollback failure;
the existing success case now checks distinct new bytes and the archived pair.
All use existing seams/fixtures; no runner, dependency or test target was added.
The [isolated fault evidence](2026-10-12-fault-evidence.md) preserves the pre-fix
counterexamples. No native I/O is exercised. TMQA-005's App lifecycle decision
matrix remains unexecuted; helper PASS does not replace model/native acceptance.
The later [local native build](2026-10-12-native-build.md) passed app/DMG artifact
checks, read-only inner-app comparison and normal detach. Suites were reused
without another run because all 43 tracked inputs stayed unchanged. `--scan`
executed in its CLI context with exit 3/no visible devices; no journal or
preference writes. GUI/device acceptance remains `NOT_RUN` by user agreement.

## Accessibility signing pilot — 2026-10-12

The temporary native [signing pilot](../../Workflow.md#accessibility-signing-pilot--2026-10-12)
is **PROBE_RETENTION_PASS**. Different A/B executables passed strict signature
and cross-DR checks under the same trial certificate; the same-ID ad hoc control
failed the pinned requirement. These are signature checks, not native TCC
negative controls. After A was manually allowed, a new B process reported
`AXIsProcessTrusted()==true` at 14:27:51 KST without permission changes during
replacement. The live app path and outer directory inode were preserved.

The initial temporary-app approval difficulty and its LaunchServices lookup
limit are retained in Workflow. No permanent probe, test target or dependency
was added. This result covers this Mac, user and path; the trial identity was
in a dedicated Keychain during acceptance without added trust settings. A receiver
with no installed signing certificate/private key or added certificate trust,
native signed Touch Me build/package and real Homebrew upgrade are **NOT_RUN**.
After retention acceptance, approved registration of a same-signature B cleanup
copy made the Probe row visible. That copy was not launched. Manual user removal
is **PASS_USER_REMOVAL_UI_CONFIRMED**: fresh Accessibility UI shows no Probe row
and the actual Touch Me entry ON. The guarded cleanup copy and empty parent were
removed, with no Probe process remaining. The user separately approved deleting
the trial Keychain. Exact-path, sole-certificate fingerprint and non-default
Keychain checks preceded successful scoped deletion; the file is absent. Key
cleanup is **DELETED_WITH_USER_APPROVAL**. Original temporary app, public
certificate and evidence are retained. This later
registration and cleanup are separate from retention PASS. Existing Core/Platform
tests cannot establish TCC retention.

At the signing-source checkpoint, `python3 -m unittest discover -s Tests/PackagingTests -v`
passed all 26 tests (the previous 22 plus four focused signing cases).
`bash -n scripts/build-app.sh` and combined native `codesign` inspection of the
signed probe and ad hoc control passed. The restricted executor could not read
the extracted certificate output; native Mac inspection passed without trust
changes or fallback. Packaging tests use native-tool doubles and do not prove
native bundle/DMG signing. Core/Platform/App code is unchanged, so Swift tests
were not repeated. Actual signed Touch Me artifacts and installed-app/Homebrew
acceptance were **NOT_RUN** at that checkpoint; later native artifacts are
recorded separately below.

## Release identity backup and restore — 2026-10-12

The permanent identity is **GENERATED** and same-Mac restore is
**RESTORE_SIGNING_PASS**. [Workflow](../../Workflow.md#release-signing-identity-preparation--2026-10-12)
records its public certificate parameters, fingerprints and distinct source/
restored cdhash values. Native password-protected PKCS#12 export/import are
`USER_REPORTED`; backup presence, `0600` and parent `0700` are directly verified.
New dummy bytes signed through the temporary restore Keychain passed strict
verification, exact certificate matching and both DR directions, proving the
restored private key is usable. Neither app was launched and no explicit user,
admin or system certificate trust was added. The permanent Keychain's `0600`,
300-second timeout, sleep lock and non-default status passed direct checks.

This is identity recovery on the same Mac, not Touch Me or TCC acceptance.
Independent storage is **NOT_AVAILABLE**, and off-Mac restore is **NOT_RUN**.
Temporary restore Keychain cleanup is **DELETED_WITH_USER_APPROVAL** after
exact-path, sole-certificate SHA-1/SHA-256 and non-default guards. Its file and
search-list entry are absent. At the 17:34:45 KST preparation checkpoint, the
original release Keychain was locked and preserved, and the encrypted backup
was retained. Native signed
Touch Me build/DMG packaging, installation, Homebrew upgrade, a receiving Mac
without separately installed signing identity or added trust, Gatekeeper and
publication were **NOT_RUN**. The [later local candidate](../../Workflow.md#local-certificate-signed-touch-me-candidate--2026-10-12)
has native artifact verification only. No repository source or tests changed for this
identity-only check, and Touch Me was not built; earlier 26-test source results
remain separate.

## Local certificate-signed candidate — 2026-10-12

One actual Touch Me build and one DMG packaging invocation exited 0. Native
strict signature, permanent certificate SHA-1/SHA-256 and pinned DR, arm64,
version/build, license/icon, `hdiutil verify` and checksum checks passed.
Read-only mounted inner bytes/signature/certificate/DR, bilingual installation
notes, Applications shortcut and normal detach also passed. Previous local
app/images and the installed app were preserved. The candidate was never
launched and no explicit certificate trust was added. The outer DMG was not
code signed by the packager; its integrity/checksum and inner app signature were
verified. [Workflow](../../Workflow.md#local-certificate-signed-touch-me-candidate--2026-10-12)
records the exact local signer and hashes.
After validation, the permanent Keychain was locked with `0600`,
300-second/sleep lock and non-default status verified; the encrypted backup
remained `0600` (`keychain-final-state.json`).

This is **NATIVE_ARTIFACT_PASS**, not permission-retention acceptance. The local
candidate and published ad hoc beta.8 share version/build but have different
signatures and bytes. Actual Accessibility/Input Monitoring retention,
installation/Homebrew upgrade, receiving Mac without separately installed
identity or added trust, Gatekeeper, signed publication and push remain
**NOT_RUN**. The previously verified scripts and runtime source were unchanged;
this native phase required no source/test changes or suite repeat.

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
