[English](Homebrew.md) · [한국어](Homebrew.ko.md) · [Build workflow](../Workflow.md) · [Use the app](../README.md)

# Publish the Touch Me Homebrew beta

This guide targets beta.5 after approved publication and public-asset
verification. The historical public baseline was beta.4 build 21; its release
record and commands remain below.

## Beta.5 preparation

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

These phases preserve the beta.4 release record and its previous approval scope. Do not run their version-specific commands against the beta.5 source or use that past approval as the candidate's acceptance result.

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

These are user installation instructions and separate from the publication/audit run. Fully qualified installation scopes trust to the selected Cask rather than the whole Tap. [Tap Trust](https://docs.brew.sh/Tap-Trust)

```bash
brew install --cask soom-kang/touch-me/touch-me
```

If `/Applications/Touch Me.app` was installed manually, first turn off **Launch at login**, select **Stop mapping**, then use normal **Quit**. Confirm device-mode restoration completed. Preserve the old app by moving it outside Applications before installing through Homebrew; do not force Homebrew to overwrite it. Keep saved preferences. Stop if restoration fails.

The ad hoc beta is not notarized. Verify the release source and checksum before attempting first launch. When macOS offers the official approval path, use **System Settings → Privacy & Security → Open Anyway** and confirm the prompt yourself. Managed settings or a damage/malware alert may prevent that path; stop and investigate. This procedure does not promise Gatekeeper acceptance. [Apple's first-launch guidance](https://support.apple.com/en-us/102445)

Grant **Input Monitoring** and **Accessibility** in System Settings, then refresh the app. Ad hoc updates can require renewed privacy approval; check both permissions before mapping. The Cask's `unsigned_accessibility` caveat highlights Accessibility reapproval. It neither grants permissions nor changes quarantine.

For an update, first **Stop mapping → normal Quit** and confirm restoration. Then:

```bash
brew update
brew upgrade --cask soom-kang/touch-me/touch-me
```

For removal, turn off **Launch at login**, perform the same Stop/Quit sequence and confirm restoration before:

```bash
brew uninstall --cask soom-kang/touch-me/touch-me
```

Removal preserves app preferences. There is no `zap` routine, automatic process kill or device-recovery hook. A failed restoration blocks upgrade/removal. Keep the current connection and use Retry restore; a changed attachment blocks recovery, so preserve its record and error.

## Record results and future signing work

The release owner records the source revision, tag, build number, DMG SHA-256, Homebrew version, executed commands and outcomes with an `Asia/Seoul` date. Keep artifact, Homebrew audit, GUI, real-device and login-launch results separate. Preserve the historical build 8–12 evidence in [Workflow](../Workflow.md#choose-the-minimum-checks); it does not prove behavior for a later candidate. Never include credentials or raw personal data.

A later Developer ID release needs separately approved signing/notarization preparation and validation of the final downloaded, installed app. Keep credential access outside this runbook and record that release's verification separately from this ad hoc beta.
