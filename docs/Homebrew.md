[English](Homebrew.md) · [한국어](Homebrew.ko.md) · [Build workflow](../Workflow.md) · [Use the app](../README.md)

# Publish the Touch Me Homebrew beta

## Beta.12 publication — 2026-10-28

Status: **PUBLISHED** — 2026-10-28 17:01:23 KST (08:01:23 UTC).
Release `0.8.0-beta.12`, build 39, includes native back/forward gestures and the
USB contact-source fix.
Runtime source is unchanged from `294982a`. Existing 60-test and build 36/38 local
acceptance results are reused, with no claim that the new release was exercised.
New-release installation, upgrade, permission retention and physical use are
**NOT_RUN**. Local signature, certificate/DR, arm64, mounted inner-app byte and
DMG/checksum checks passed. Anonymous public DMG/sidecar bytes, sizes and API digests
match the candidate. Public Tap `d9206d806864a539a56f5292387db510807b84e1`
and all four changed files match the reviewed checkout. The
optional Natural scrolling on/off comparison remains **NOT_RUN**.

The beta.12 DMG and Tap Cask are public. Cask Ruby syntax and current style rules
passed for one file with no offenses, using existing compatible gems including
RuboCop 1.91.0; the `brew style` front-end and exact locked toolchain were not used.
The selected Cask is trusted; the whole Tap is not. Preserve that scope and the
clean installed Tap at `49be006`; installed build 33 is unchanged. Online audit
remains **BLOCKED** under the existing deferral. See the
[release record](releases/v0.8.0-beta.12.md) and
[QA checkpoint](qa/automated-tests.md#beta12-release-preparation--2026-10-28).

## Beta.11 publication checkpoint — 2026-10-25

Beta.11/build 33 and its Tap Cask are published with pinch and three-finger
gestures. Anonymous public DMG/checksum and Tap-file comparisons passed. The
installed app and Tap were retained at publication; upgrade was **NOT_RUN** then. See the
[beta.11 verification record](releases/v0.8.0-beta.11.md) for source/tag, artifact
and Tap identities and validation limits.

At that publication checkpoint, selected-Cask and whole-Tap trust were both false.
No trust change was made; online audit was **BLOCKED** under the existing deferral. Cask syntax
and the then-current Homebrew style rules passed using existing compatible gems, not
the exact locked toolchain. The subsequent beta.11 upgrade and permission-retention
results are recorded in its release notes. Earlier publication/upgrade records follow.

## Beta.10 publication and upgrade — 2026-10-14

Beta.10/build 28 is **PUBLISHED** at 01:14:28 KST (2026-10-13 16:14:28 UTC).
Release source/tag `8aaebe4530ece3e0b6309c3be0df3c2d57e4d07f` matches all
43 frozen inputs; anonymous public DMG/sidecar bytes match the native candidate.
The Cask publication Tap is `27fd12ee7e39ec383919fd5333120afc55768ea4`.
Later README-only Tap updates are separate checkpoints.
One normal beta.9 → beta.10 upgrade exited 0 at 01:19:31 KST
(2026-10-13 16:19:31 UTC). Installed five-file equality, strict certificate/DR,
receipt, outer device/inode and preference/recovery preservation passed.
The immediate App Management preflight passed in the actual `brew` host;
selected-Cask/whole-Tap trust stayed true/false.

Fresh B10 PID `60924` matches the public app path/hash and beta.10/build 28.
The user confirmed both permissions Allowed without reapproval in its own
GUI: **PASS_USER_REPORTED_ON_THIS_MAC**. No Start or privacy change was invoked.
Native provenance and state checks passed; GUI flags are user-reported and the
result covers this Mac, user and installation path. Fresh Gatekeeper, receiving-Mac and device
acceptance remain `NOT_RUN`; online audit stays `BLOCKED`. Equivalent Cask
rules passed with existing compatible `spoom 1.8.9`, not the exact locked
toolchain. [Beta.10 release notes](releases/v0.8.0-beta.10.md) hold exact results.

## Beta.9 publication and upgrade — 2026-10-14

Prerelease `v0.8.0-beta.9` was published at 00:17:31 KST (2026-10-13 15:17:31 UTC).
Source/tag `0414617c860451e0c7b2200294b0eeca651f9ad9` matches all 43 frozen
inputs. Anonymous public DMG/sidecar bytes match the native candidate. Public
and clean installed Tap are `65d13988d6f4bb415df8f5d6853a8c38c8d3b7fc`.
The Cask body, exact-version allowlist and bilingual Tap guidance match the
reviewed publication. See [beta.9 release notes](releases/v0.8.0-beta.9.md).

One normal Homebrew beta.8 → beta.9 upgrade exited 0 at 00:30:45 KST
(2026-10-13 15:30:45 UTC). Installed build 27 matches five public-candidate files
and passes strict certificate/DR checks. The outer app directory's device/inode
were preserved; the exact App Management condition passed in the same
`brew` host immediately before upgrade. Selected-Cask trust true and whole-Tap
trust false stayed unchanged. Preferences, saved mapping and recovery hashes
also matched after launch.

The user confirmed A9 GUI beta.9/build 27 with both permissions Allowed after
initial approval; before flags remain unknown. Restarted PID `35272` matched
the public path/hash, then normal Quit and native absence passed. No Start was
invoked. At this A9 checkpoint, beta.9 → beta.10 retention was `NOT_RUN`; see
the [beta.10 result](#beta10-publication-and-upgrade--2026-10-14). Fresh Gatekeeper,
receiving-Mac and physical-device acceptance remain `NOT_RUN`.

Cask Ruby syntax and equivalent Homebrew style rules passed (one file, no
offenses) using an existing compatible dependency; exact locked-toolchain
validation did not pass. Online audit remains `BLOCKED` under the existing
trust-preserving deferral. Keep prior assets/tags and recovery records. The
following beta.8 sections preserve their historical publication checkpoints.

## Beta.8 publication — 2026-10-12

Prerelease `v0.8.0-beta.8`, build 26, was published at 10:41:21 KST
(01:41:21 UTC). Source/tag `e97d1720` matches all 43 frozen inputs. Anonymous
public DMG/sidecar bytes, size and checksum text match the inspected candidate.
The public Tap, reviewed checkout and clean installed Tap resolve to
`47a3e433`. The installed Tap fast-forwarded without installing/upgrading the
app. See [beta.8 release notes](releases/v0.8.0-beta.8.md) for full identities.

The actual Cask's version, URL and digest match that public DMG. Its body matches
the source template, excluding the template's two draft-header comments. The
prerelease allowlist contains only the exact beta.8 version for `touch-me`.
Cask Ruby syntax and equivalent Homebrew style rules passed with the installed
vendored RuboCop wrapper (one file, no offenses). The first style run was
interrupted with exit 130 after selecting the wrong working directory; the
corrected Tap-directory run passed. The `brew style` front-end, gem installation
and cleanup were not run, preserving developer settings.

One app and DMG were built, then native artifact checks passed. The completed
38 Swift and 22 packaging tests were reused. All seven earlier releases,
14 assets and 14 annotated/peeled tag refs retained their identities.
Keep the new and older assets immutable; a later artifact change needs another
version. Compare public bytes before updating a Cask and preserve incomplete
local output for inspection.

Online audit remains **BLOCKED** under the approved deferral. The selected Cask
is trusted and the whole Tap is untrusted; neither state was changed. No trust
bypass variables were used. Build 26 GUI/device, installation, upgrade,
Gatekeeper and login/lock/sleep/crash acceptance are **NOT_RUN**. At that
checkpoint installation guidance targeted beta.8; the current guide below
targets beta.12. These results retain their historical publication scope.

The installed app, recovery files, preferences and prior local artifacts match
their inventories. Target trust/developer settings also match, but the shared
trust-store raw hash changed; its cause and actor are unverified. No restoration
was attempted. See the [preservation limit](releases/v0.8.0-beta.8.md#preserved-state-and-observation-limit).

## Source QA baseline before beta.8 — 2026-10-12

The [QA report](qa/2026-10-12-qa-report.md) records local fixes for TMQA-006/007
and retains the exact build 25 native acceptance gap. Packaging now completes
the staged DMG and checksum before changing final paths. A valid previous pair
is archived together, with original filenames, under
`dist/previous-builds/touch-me-<VERSION>-<UUID>/`. Missing one prior file or a
mismatched checksum stops packaging and preserves the evidence.

Ordinary finalization errors roll back completed moves. If rollback also fails,
the script stops and reports final, staging and archive paths for inspection;
do not retry or upload until a complete pair is verified. Separate renames do
not guarantee crash, power-loss or concurrent-run atomicity. Keep the old public
version/assets; this source fix is not a new release. No public asset, actual
Tap, installed app or trust setting was changed or revalidated. The beta.7
audit deferral below remains in force. A subsequent [local native build](qa/2026-10-12-native-build.md)
passed artifact checks; its DMG digest is
`cb46fa2fda5211504d04d9b7536de5883ad566cf514bf2ab02452500a2e5e803`.
It shares beta.7/build 25's displayed metadata and has different bytes. Keep the
public Cask/digest unchanged; this local QA candidate is not the published release.

## Beta.7 release preparation — 2026-10-10

This section preserves the completed beta.7 publication checkpoint. Its artifact
and approval scope do not establish beta.8 acceptance.

Status: **PUBLISHED**. Prerelease `v0.8.0-beta.7` was published on 2026-10-10
at 14:25:14 KST (05:25:14 UTC), with build 25 and
`touch-me-0.8.0-beta.7-arm64.dmg` plus its `.sha256` file. This run updates the
public release and existing Tap only; retain the installed app and preferences.

Reuse the source's 37 Swift tests and development build 24 USB-C cycle
(`PASS_USER_REPORTED`), tied to the executable hash in
[Workflow](../Workflow.md#usb-c-reconnection-candidate--2026-10-10).
New build 25 GUI/device, installation, upgrade and Gatekeeper are `NOT_RUN`.

1. Finalize beta.7 metadata and bilingual documentation, including generated
   `Install.txt`. Build and package once; run the existing 18 packaging tests.
   Freeze release inputs and verify bundle metadata/signature/license/icon,
   arm64, DMG integrity/sidecar and read-only mounted inner identity.
2. Publish the reviewed source, tag and prerelease without replacing older
   assets. Verify anonymous public DMG/sidecar bytes, hash and inner metadata
   against the frozen candidate before changing the Tap.
3. Update the actual `Casks/touch-me.rb`, beta.7's exact-version prerelease
   allowlist and the Tap's two-language guidance. Cask Ruby syntax and style
   must pass; confirm the published Tap revision and matching asset identity.

Online audit is **BLOCKED**, an approved deferral: preserve existing trust and
do not change trust settings or bypass environment variables. Do not run
`brew audit --cask --online soom-kang/touch-me/touch-me` in this scope or treat
beta.6's historical audit PASS as the beta.7 result. Publication may finish
with this recorded exception after the required asset and Cask checks pass.
Local build/package, 18 packaging tests and actual Cask syntax/style passed
(one file, no offenses). Source/tag commit
`f8210f4318f726c9943db1de7fa82e634d132a10` matches all 28 frozen inputs.
Anonymous public DMG/sidecar raw bytes, size, digest and checksum text match the
frozen release. The DMG is 524,843 bytes with SHA-256
`74bf81ff7e7d1a0a1966146022b7e60841451897fee25a2dbe1449b31113da90`.
At the 2026-10-10 14:28:27 KST (05:28:27 UTC) checkpoint, the public Tap,
independent clone and installed Tap all matched
`7c07d4967e94e0591229410f8952bb49c2b7e102`. The installed Tap fast-forwarded
cleanly from `3c3ab9e`; its four files match the public clone, and the Cask
matches the source template. No app installation, upgrade or trust change occurred.
Record actual results in [beta.7 release notes](releases/v0.8.0-beta.7.md).
The beta.4 commands below remain historical examples.

## Local USB-C reconnection candidate — 2026-10-10

This development snapshot preceded beta.7 release preparation. The reconnection source change is not included in public beta.6. The completed development work did not change `VERSION`, release assets, Tap or the installed bundle. Local test/build results are recorded in [Workflow](../Workflow.md#usb-c-reconnection-candidate--2026-10-10), separately from publication or Homebrew acceptance. On 2026-10-10, one approved candidate Start → USB-C disconnect/reconnect → automatic resume → two-position taps → Stop cycle passed (`PASS_USER_REPORTED`). This meets the approved local acceptance scope; no new Homebrew result is implied.

The candidate can preserve an old record as `disconnected-<nonce>.json` only when both exact recorded HID/USB services are proven ended on the same boot and ownership is authorized. A synced `reconnect-required.json` keeps fresh-mode checks in force after relaunch, including sessions whose original `(2,0)` needed no mode-change record. This is unconfirmed restoration, not proof the old mode was restored, and no old mode is copied onto a new connection. `(0,0)` permits guarded automatic Start; `(2,0)` requires informed manual Start and retains its current mode after Stop.

Preserve the current app and artifacts, and use normal Quit for app transitions. If restoration or record handling blocks Quit, preserve the evidence and agree the transition first. One separately approved previous-app termination and the local candidate launch are recorded in [Workflow](../Workflow.md#usb-c-reconnection-candidate--2026-10-10); this does not authorize routine Force Quit. The Cask has no record-reset, forced-quit or recovery hook. Do not delete recovery records to make an upgrade succeed. Public beta.6 retains its continuous-attachment recovery restriction; same-port reconnection cannot bypass it.

## Published beta.6 — 2026-10-09

The [beta.6 prerelease](https://github.com/soom-kang/touch-me/releases/tag/v0.8.0-beta.6) was published at 18:38:18 KST from release source/tag `7a663f5bd70fcfc73d8b44ea78abeeb69ac4b40e`. There are no runtime-code changes since beta.5; it includes completed QA records. Anonymous DMG/sidecar verification at 18:38:33 KST matched the 455,405-byte build 24 artifact and [recorded digest](releases/v0.8.0-beta.6.md). Public and installed Tap revision is `3c3ab9e95c3ad6991d7397fa6b436c2f46e5aa7f`; the installed Tap fast-forwarded cleanly. Actual Cask Ruby syntax and Homebrew style passed, with one file inspected and no offenses.

Ordinary `brew audit --cask --online soom-kang/touch-me/touch-me` passed with exit 0 at 18:39:35 KST, without `--new` or exclusions. Existing selected-Cask trust is unchanged; the whole Tap is not trusted. The installed beta.5 app is retained. Beta.5 build 23 acceptance is regression evidence only. Beta.6 installation, GUI, Gatekeeper, real-device use and Homebrew upgrade are `NOT_RUN`.

## Published beta.5 — 2026-10-09

The [beta.5 prerelease](https://github.com/soom-kang/touch-me/releases/tag/v0.8.0-beta.5) is public at source/tag `4ead3d1acec3beb43a1f09261b308ef9fdef0e81`. Anonymous download verified the 455,408-byte DMG and sidecar against the [recorded build 23 digest](releases/v0.8.0-beta.5.md). Tap main and installed Tap `31cdb32c1e1415401c26fd338842bf811471b531` are clean and match the reviewed Cask; beta.4 assets are retained.

The public beta.4 → beta.5 upgrade phase reported success; installed Applications build 23 matched executable/signature/license/icon. Post-upgrade cleanup unexpectedly cloned core under the task-scoped `HOMEBREW_NO_INSTALL_FROM_API` flag. The verified Homebrew PID was interrupted at 16:48:57 KST; the overall command exited 130 after upgrade success. Its core path and clone processes were absent after automatic cleanup, with no reset/untap needed.

QA01 is `PASS` for the agreed public-upgrade scope. Installed build 23, both permissions, two-position taps and Stop/normal Quit are `PASS_USER_REPORTED`. Direct checks found no TouchMe process or recovery record at 18:03:47 KST; a new read-only session observed current `(0,0)` at 18:04:26 KST, matching the prior original/journal pair on the same boot, HID/USB registry identities, location and descriptor. That session only performed arm→exit, with zero feature writes and exit 0. See the [acceptance record](qa/beta5-native-acceptance.md).

## Beta.5 preparation

### Historical prepublication checkpoint — 16:24 KST

Prepublication record on 2026-10-09: **READY_FOR_RELEASE_REVIEW / NOT_PUBLISHED**.
Candidate `0.8.0-beta.5`, build 23 passed source compilation, nine focused backend
checks, signature/metadata/license/icon, 28 input comparisons, DMG integrity and
local Cask/Tap review. One controlled original-0/same-boot/continuous-P16KT
SIGKILL/relaunch recovered and cleared the previous record before mapping
resumed; final Stop/Quit readback was `(0,0)`, with no diagnostic feature write.
Normal-use/relaunch and post-crash gestures are `PASS_USER_REPORTED`. Historical
build 22's failure is retained in the [acceptance record](qa/beta5-native-acceptance.md).

The planned tag is `v0.8.0-beta.5`; the asset is
`touch-me-0.8.0-beta.5-arm64.dmg` and its `.sha256` file. Build 23's artifact
identity and strict recovery policy are in the [release notes](releases/v0.8.0-beta.5.md).
A local Cask draft does not establish a published Tap or available download.

After review and approval:

1. Compare the frozen compilation/package inputs with the release commit.
   Preserve the existing app, preferences, tags and assets.
2. Publish the reviewed DMG and sidecar, then verify the public download against
   build 23's recorded digest and inner app. Update the existing Tap only with
   that verified version and checksum; never replace an older asset or use
   `:no_check` to bypass a mismatch.
3. Use the installation/upgrade instructions below after the beta.5 asset and
   Tap update are verified. Record beta.4 → beta.5 public-upgrade acceptance
   separately; QA01 remains open and that check is `NOT_RUN` in this record.

At this checkpoint release commit/push, tag, publication and Tap update had not
been performed. Fresh installation/Gatekeeper, permission off/on, lock/sleep,
full logout/login, removal and broader crash/device recovery remain `NOT_RUN`.
Retain privacy permissions and renew only if necessary. Keep the same attachment
for Retry; reconnecting to the same port does not authorize journal recovery.

## Historical published beta.4 baseline

| Item | Value |
| --- | --- |
| Source repository | [soom-kang/touch-me](https://github.com/soom-kang/touch-me) |
| Tap repository | `soom-kang/homebrew-touch-me` |
| Tap / Cask token | `soom-kang/touch-me` / `touch-me` |
| Release version / tag | `0.8.0-beta.4` / `v0.8.0-beta.4` |
| Asset | `touch-me-0.8.0-beta.4-arm64.dmg` and its `.sha256` file |
| App / identifier | `Touch Me.app` / `io.github.soom-kang.touchme` |
| Minimum environment | Apple Silicon, macOS 26 (Tahoe) or later |
| Device scope | One ZEUSLAP P16KT, USB `0x0457:0x0819`, eligible external display |
| Signing | Ad hoc; no Developer ID signature or notarization |
| Local draft / Tap file | `packaging/homebrew/touch-me.rb.in` / `Casks/touch-me.rb` |

`VERSION` is the release-version source for new builds. The published beta.4 bundle uses numeric `CFBundleShortVersionString=0.8.0`, `CFBundleVersion=21` and `TouchMeReleaseVersion=0.8.0-beta.4`. About and settings display the full release version. [Apple version format](https://developer.apple.com/help/glossary/version-number/)

One app contains English and Korean. It starts in English without a saved language and preserves the language selected in settings. The Cask has no language-specific downloads.

Use the versioned asset URL:

```text
https://github.com/soom-kang/touch-me/releases/download/v0.8.0-beta.4/touch-me-0.8.0-beta.4-arm64.dmg
```

The Cask SHA-256 must match the exact uploaded DMG. GitHub permits asset replacement, so maintain the published version as immutable: a later source, signature or DMG change needs a new version and checksum. Never resolve a mismatch with `:no_check` or replace an existing release asset.

## Historical beta.4 release procedure

These phases preserve the beta.4 release record and its previous approval scope. Do not run their version-specific commands against the current source or use that past approval as the candidate's acceptance result.

### Phase 0 — Confirm the source and preserve the starting state

**Input:** the source checkout, authenticated GitHub access and existing artifacts. Read the instructions and build scripts. Inspect Git status, local and remote revisions, tags and releases before changing anything.

```bash
git status --short
git remote -v
git rev-parse HEAD
git ls-remote --heads --tags origin
gh repo view soom-kang/touch-me --json nameWithOwner,visibility,defaultBranchRef
gh release list --repo soom-kang/touch-me
```

**Historical beta.1 preflight:** on 2026-10-07, local `main` was clean at `5e2520f7f3bacdd85507a383d0c08da3555a1c5d`, remote `main` matched, the source repository was public and no releases existed. The intended Tap returned not found. These observations preceded beta.1 publication.

**Historical beta.2 baseline (2026-10-07):** source `main` started at `abbfece6ea621b13bd9832b53976ce0acd67f839`; beta.1 and the public Tap already existed.

**Historical beta.3 baseline (2026-10-08):** source `main` was clean at `c8b78c89e77ca6636db429cff46db9db68aebf9b` and matched the public source. The beta.2 prerelease and public `soom-kang/homebrew-touch-me` Tap existed; Tap remote `main` was `fb0cea082d066bf0d34559eec6348ae09c0a5e8d`.

**Beta.4 baseline (2026-10-09):** source `main` starts at `91142b7bb1137452ae6618b09cea5488e1c8849e` with six uncommitted gesture-related files. Beta.1, beta.2 and beta.3 are public; Tap remote `main` is `55d661ae2d5a4409db7d720d4988556592769970`. Preserve all existing tags and assets. Recheck remote state and use a separate checkout to update the existing Tap; do not recreate it.

**Complete when:** ownership, release target and intended file changes are clear. **Stop if:** a remote mismatch, conflicting tag/release, unexpected Tap changes, unpreservable change or mounted replacement image needs resolution. Eject normally; do not force eject.

### Phase 1 — Align source, license and release documentation

**Input:** the six reviewed gesture-related changes, plus release metadata and documentation updates. A one-finger tap clicks on lift; moving beyond 8 screen-coordinate units starts a drag. A second contact before dragging cancels the pending click and starts scrolling. An active drag tracks the first contact; after scrolling or losing that contact, the gesture waits for all contacts to lift. Keep the project's `LICENSE`, copyright 2026 Soom Kang, and its bundled `Licenses.txt`. Retain the existing diagrams, bundle identifier, saved-preference format and other device/lifecycle contracts; update gesture guidance in the existing UI. Review the English and Korean README, Workflow and this runbook together. Use the [beta.4 release notes](releases/v0.8.0-beta.4.md) for changes and observed validation limits.

**Complete when:** release documentation and bundle inputs agree, and the final diff contains only the requested changes. **Stop if:** a missing source file, unresolved ownership question or unrelated change prevents a reviewable release. Previously built artifacts do not establish that current bundle inputs match.

### Phase 2 — Build and freeze the candidate

**Input:** the reviewed source and `VERSION=0.8.0-beta.4` in a separate release checkout. Copy the existing build 20 app to that checkout's `dist/Touch Me.app` as the build-number baseline; one build must produce build 21. The gesture fix passed the existing 14 Swift tests, and build 20 gesture behavior is `PASS_USER_REPORTED`, without direct event/process proof. Reuse those results while gesture code stays unchanged. Packaging contracts remain unchanged; this release adds no tests or validation infrastructure and does not repeat the full suites. Build and package once from that checkout root:

```bash
bash scripts/build-app.sh
python3 scripts/package-dmg.py
hdiutil verify dist/touch-me-0.8.0-beta.4-arm64.dmg
(cd dist && shasum -a 256 -c touch-me-0.8.0-beta.4-arm64.dmg.sha256)
```

The existing scripts perform release compilation with warnings as errors, bundle creation, strict ad hoc signature verification and packaging checks for identity, version, exact license content and arm64 architecture. Inspect `Info.plist` and compare the bundled icon with the source as described in [Workflow](../Workflow.md). Confirm build 21 and record its exact checksum in the [beta.4 release notes](releases/v0.8.0-beta.4.md), then put that digest in the local Cask draft. Build 21 device, Gatekeeper and Homebrew installation checks are `NOT_RUN`; earlier results do not establish those checks. Check the final Cask with style in Phase 4.

The Cask uses `app "Touch Me.app"`, arm64/Tahoe requirements, a skipped `livecheck` for manually maintained beta releases and installation caveats. It has no launch hooks, permission changes, `zap`, language-specific downloads or auto-update claim. [Cask Cookbook](https://docs.brew.sh/Cask-Cookbook)

**Complete when:** compilation, packaging, strict signature, metadata, license/icon, arm64, DMG integrity and checksum checks pass; the draft matches the frozen candidate; documents agree. **Stop if:** any of these checks fails. Preserve the previous artifact and repeat only checks affected by a fix. Do not repeat a successful build just to reconfirm it: another build can change the build number, signature and DMG bytes.

### Phase 3 — Publish the reviewed source, tag and prerelease

**Input:** the frozen candidate, final diff and English/Korean release notes covering features, support, ad hoc signing and actual validation limits. Review and commit only the intended source, license, documents and Cask draft; generated app/DMG files remain outside Git. Compare all compilation and packaging inputs, including Sources, Package, VERSION, scripts, license and icon, between the frozen release checkout and that final source commit. Do not attach the frozen DMG to a commit with different inputs. Push the reviewed commit to source `main` and verify the remote revision before tagging it.

Run Git publication commands in the source checkout holding that commit. The asset paths below refer to the frozen release checkout; when publishing from another directory, pass its absolute DMG and checksum paths rather than the working checkout's active `dist`.

```bash
git push origin main
git tag -a v0.8.0-beta.4 "$(git rev-parse HEAD)" -m 'Touch Me v0.8.0-beta.4'
git push origin refs/tags/v0.8.0-beta.4
gh release create v0.8.0-beta.4 \
  --repo soom-kang/touch-me --verify-tag --prerelease --latest=false \
  --title 'Touch Me v0.8.0-beta.4' \
  --notes-file docs/releases/v0.8.0-beta.4.md \
  dist/touch-me-0.8.0-beta.4-arm64.dmg \
  dist/touch-me-0.8.0-beta.4-arm64.dmg.sha256
```

Use the reviewed notes file. Resolve the annotated tag to the exact reviewed commit. If a tag or release already exists, inspect its commit and assets; resume only a matching incomplete operation. Never force, delete or overwrite a published tag/asset. Download both public assets to a separate verification directory and check the uploaded `.sha256` there against the frozen candidate's digest. Confirm the release is a prerelease.

**Complete when:** remote source and tag match the reviewed commit, public download bytes match and release notes accurately describe validation. **Stop if:** source/tag identity, public download or checksum cannot be confirmed. Do not publish a Tap against a missing or mismatched asset.

### Phase 4 — Update and publish the existing Tap

**Input:** the verified public prerelease and final Cask draft. Use a separate checkout for the existing public `soom-kang/homebrew-touch-me` repository; do not recreate it or nest another Git repository inside the source project. Check its Git status and remote revision before changing it. Update `Casks/touch-me.rb`, the English/Korean install guidance and the following exact-version exception at `audit_exceptions/github_prerelease_allowlist.json`; preserve the project MIT license:

```json
{
  "touch-me": "0.8.0-beta.4"
}
```

This allows the intended beta version through the GitHub prerelease check. Do not use `all`, `any`, a global signing exception or an audit command that skips the prerelease check. Update this version deliberately with each beta release.

Copy the final draft to `Casks/touch-me.rb`, compare its version/URL/hash with the verified public DMG and run style on its absolute path before publication:

```bash
brew style /absolute/path/to/homebrew-touch-me/Casks/touch-me.rb
```

Review the Tap diff, then commit and publish only those files. Do not add CI or test infrastructure for this small Tap.

**Complete when:** the public Tap contains the reviewed Cask, exact-version exception, English/Korean guidance and license; local style passes. **Stop if:** the Tap contains unreviewed changes or history, a checksum differs or style reports an unresolved error. Preserve the source release and stop only Tap publication.

### Phase 5 — Synchronize the existing Tap and run online audit

**Input:** the published Tap and verified public assets. On 2026-10-08, the selected Cask was already trusted and the whole Tap was not trusted. Preserve that scope. Confirm the installed Tap is clean and its remote is unchanged, fast-forward it to the reviewed published revision and compare the resulting HEAD before the audit:

```bash
TASK_TAP_PATH="$(brew --repo soom-kang/touch-me)"
git -C "$TASK_TAP_PATH" status --short
git -C "$TASK_TAP_PATH" pull --ff-only
git -C "$TASK_TAP_PATH" rev-parse HEAD
brew audit --cask --online soom-kang/touch-me/touch-me
```

Use the named installed Cask for audit. Homebrew 7.0.9 disables `brew audit` with a `.rb` path; an external checkout also lacks the installed Tap context needed for its exact-version prerelease exception. The separate checkout is used for editing and the Phase 4 style check. If the selected Cask is no longer trusted, stop this phase for agreement rather than changing trust.

Homebrew 7.0.8 was inspected on 2026-10-07 and its relevant contracts were rechecked locally on 2026-10-08; Homebrew 7.0.9 was verified for this release on 2026-10-09. An ordinary online audit skips signing for non-official taps; `--new` requests signing checks and does not fit this ad hoc beta route. The exact-version Tap exception handles the intentional prerelease while leaving other ordinary audit checks enabled. Recheck this behavior if Homebrew changes. Relevant upstream code: [Cask audit](https://github.com/Homebrew/brew/blob/7.0.9/Library/Homebrew/cask/audit.rb), [audit command](https://github.com/Homebrew/brew/blob/7.0.9/Library/Homebrew/dev-cmd/audit.rb) and [GitHub release checks](https://github.com/Homebrew/brew/blob/7.0.9/Library/Homebrew/utils/shared_audits.rb).

**Complete when:** existing selected-Cask trust is preserved and the ordinary online audit succeeds, and release/Tap URLs, source revisions, build number, checksum and command results are recorded. **Stop if:** Tap synchronization fails, trust is missing or audit has an unexplained failure. Do not hide it by excluding checks. This release run ends here. Homebrew installation, Gatekeeper approval, GUI language switching, real-device mapping and login launch are `NOT_RUN`; audit does not establish those behaviors. Leave the existing `/Applications/Touch Me.app` in place.

## Install, update and remove after publication

These instructions target published certificate-signed beta.12 and its verified Tap Cask. Normal beta.9 → beta.10 in-place upgrade passed; both GUI permissions remained Allowed without reapproval on this Mac (`PASS_USER_REPORTED_ON_THIS_MAC`). Earlier release checkpoints retain their original installation limits. Fully qualified installation scopes trust to the selected Cask rather than the whole Tap. [Tap Trust](https://docs.brew.sh/Tap-Trust)

```bash
brew install --cask soom-kang/touch-me/touch-me
```

If `/Applications/Touch Me.app` was installed manually, first turn off **Launch at login**, select **Stop mapping**, then use normal **Quit**. Confirm restoration on the continuous connection or safe preservation of a proven ended-connection record. Preserve the old app by moving it outside Applications before installing through Homebrew; do not force Homebrew to overwrite it. Keep saved preferences. Stop if restoration fails.

This beta uses a fixed maintainer self-signed certificate, without Developer ID or notarization. Do not add certificate trust. Verify the release source and checksum before attempting first launch. When macOS offers the official approval path, use **System Settings → Privacy & Security → Open Anyway** and confirm the prompt yourself. Managed settings or a damage/malware alert may prevent that path; stop and investigate. This procedure does not promise Gatekeeper acceptance. [Apple's first-launch guidance](https://support.apple.com/en-us/102445)

Check **Input Monitoring** and **Accessibility** in System Settings and enable only required Touch Me items, then refresh. The initial ad hoc → certificate transition may need one manual approval; public beta.9 → beta.10 retained both permissions without reapproval on this Mac, user and path (`PASS_USER_REPORTED_ON_THIS_MAC`). The Cask's signing caveat explains this limit. It grants no permissions and does not change quarantine.

Public beta.9 through beta.12 use the same permanent certificate; the [probe pilot](../Workflow.md#accessibility-signing-pilot--2026-10-12)
remains separate evidence. If a required permission is unavailable, allow the
installed Touch Me manually, then refresh. Keep already allowed items and
existing recovery state. Quit normally and reopen the same app if needed.

For an update, first **Stop mapping → normal Quit** and confirm safe cleanup of the connection or its proven ended record.

Permission retention also depends on the upgrade method. Homebrew's
uninstall/reinstall fallback can remove macOS app metadata; in-place content
replacement avoids that deletion step. Before a separately approved upgrade, check **App
Management** for the terminal application that will run `brew`. Prefer that
permission; Homebrew also supports Full Disk Access. No additional permission
was granted in this investigation. Stable signing and the actual in-place
upgrade both need validation. [Homebrew FAQ](https://docs.brew.sh/FAQ#why-do-my-cask-apps-lose-their-dock-position--launchpad-position--permission-settings-when-i-run-brew-upgrade)

Run the update only after those checks:

```bash
brew update
brew upgrade --cask soom-kang/touch-me/touch-me
```

For removal, turn off **Launch at login**, perform the same Stop/Quit sequence and confirm safe cleanup before:

```bash
brew uninstall --cask soom-kang/touch-me/touch-me
```

Removal preserves app preferences. There is no `zap` routine, automatic process kill or device-recovery hook. Failed restoration or record handling blocks upgrade/removal. Keep the current connection and use Retry restore; preserve uncertain records and errors. A proven ended connection permits record preservation, never writing its old mode onto the new connection.

## Record results and future signing work

The release owner records the source revision, tag, build number, DMG SHA-256, Homebrew version, executed commands and outcomes with an `Asia/Seoul` date. Keep artifact, Homebrew audit, GUI, real-device and login-launch results separate. Preserve the historical build 8–12 evidence in [Workflow](../Workflow.md#choose-the-minimum-checks); it does not prove behavior for a later candidate. Never include credentials or raw personal data.

A later Developer ID release needs separately approved signing/notarization preparation and validation of the final downloaded, installed app. Keep credential access outside this runbook and record that release's verification separately from this self-signed beta.

Beta.9 through beta.12 use the same permanent maintainer identity. Preserve it for future
versions and validate downloaded/installed upgrades separately. Keep the trial
certificate out of releases. Certificate or DR changes may require reapproval;
self-signing gives no notarization or Gatekeeper guarantee. Preserve published
beta.8 assets, dated caveat records and initial-transition guidance. This Mac’s
PASS does not guarantee other Macs or every future update will retain permission.
The [pilot record](../Workflow.md#accessibility-signing-pilot--2026-10-12) explains
Apple's advice against shipping self-signed apps and the user's experimental
choice for this personal beta Tap.
The [local build options](../Workflow.md#build-and-inspect-the-app) keep ad hoc
as the default and require explicit certificate fingerprints for self-signed
builds and packaging. They do not prepare credentials or activate a release.
