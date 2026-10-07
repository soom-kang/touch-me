[English](Homebrew.md) · [한국어](Homebrew.ko.md) · [Build workflow](../Workflow.md) · [Use the app](../README.md)

# Publish the Touch Me Homebrew beta

This runbook publishes `0.8.0-beta.1` as a GitHub prerelease and an ad hoc beta Cask in a personal Tap. The 2026-10-07 release task covers the reviewed source update, tag, release assets, Tap publication and online audit. Advance after each phase passes; stop for a failed check or a new consequential decision. Installing the Cask, replacing the existing Applications app, GUI checks and device checks are separate follow-up work.

## Release contract

| Item | Value |
| --- | --- |
| Source repository | [soom-kang/touch-me](https://github.com/soom-kang/touch-me) |
| Tap repository | `soom-kang/homebrew-touch-me` |
| Tap / Cask token | `soom-kang/touch-me` / `touch-me` |
| Release version / tag | `0.8.0-beta.1` / `v0.8.0-beta.1` |
| Asset | `touch-me-0.8.0-beta.1-arm64.dmg` and its `.sha256` file |
| App / identifier | `Touch Me.app` / `io.github.soom-kang.touchme` |
| Minimum environment | Apple Silicon, macOS 26 (Tahoe) or later |
| Device scope | One ZEUSLAP P16KT, USB `0x0457:0x0819`, eligible external display |
| Signing | Ad hoc; no Developer ID signature or notarization |
| Local draft / Tap file | `packaging/homebrew/touch-me.rb.in` / `Casks/touch-me.rb` |

`VERSION` is the release-version source. The bundle uses numeric `CFBundleShortVersionString=0.8.0`, an incrementing numeric `CFBundleVersion` and `TouchMeReleaseVersion=0.8.0-beta.1`. About and settings display the full release version. [Apple version format](https://developer.apple.com/help/glossary/version-number/)

One app contains English and Korean. It starts in English without a saved language and preserves the language selected in settings. The Cask has no language-specific downloads.

Use the versioned asset URL:

```text
https://github.com/soom-kang/touch-me/releases/download/v0.8.0-beta.1/touch-me-0.8.0-beta.1-arm64.dmg
```

The Cask SHA-256 must match the exact uploaded DMG. GitHub permits asset replacement, so maintain the published version as immutable: a later source, signature or DMG change needs a new version and checksum. Never resolve a mismatch with `:no_check` or replace an existing release asset.

## Execute each phase

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

At the 2026-10-07 preflight, local `main` was clean at `5e2520f7f3bacdd85507a383d0c08da3555a1c5d`, remote `main` matched, the source repository was public and no releases existed. The intended Tap returned not found. These are starting observations; recheck remote state before publication. Preserve unrelated changes and previous app/DMG artifacts. Do not initialize an already existing source repository.

**Complete when:** ownership, release target and intended file changes are clear. **Stop if:** a remote mismatch, conflicting tag/release, unexpected existing Tap, unpreservable change or mounted replacement image needs resolution. Eject normally; do not force eject.

### Phase 1 — Align source, license and release documentation

**Input:** the reviewed language/version implementation and the requested documentation cleanup. Keep the project's `LICENSE`, copyright 2026 Soom Kang. Package that license in `Licenses.txt` and make the app menu, installation notes and diagrams agree. Retain the existing UI and mapping behavior. Review the English and Korean README, Workflow and this runbook together.

**Complete when:** release documentation and bundle inputs agree, and the final diff contains only the requested changes. **Stop if:** a missing source file, unresolved ownership question or unrelated change prevents a reviewable release. Previously built artifacts do not establish that current bundle inputs match.

### Phase 2 — Build and freeze the candidate

**Input:** the reviewed source and `VERSION=0.8.0-beta.1`. Run from the project root:

```bash
bash scripts/build-app.sh
python3 scripts/package-dmg.py
(cd dist && shasum -a 256 -c touch-me-0.8.0-beta.1-arm64.dmg.sha256)
```

The existing scripts perform release compilation with warnings as errors, bundle creation, strict ad hoc signature verification and packaging checks for identity, version, license resource and arm64 architecture. Inspect `Info.plist` and `Licenses.txt` as described in [Workflow](../Workflow.md). Record the build number and exact checksum, then put that digest in the local Cask draft.

```bash
ruby -c packaging/homebrew/touch-me.rb.in
```

The Cask uses `app "Touch Me.app"`, arm64/Tahoe requirements, a skipped `livecheck` for manually maintained beta releases and installation caveats. It has no launch hooks, permission changes, `zap`, language-specific downloads or auto-update claim. [Cask Cookbook](https://docs.brew.sh/Cask-Cookbook)

**Complete when:** compilation, packaging, checksum and Ruby syntax pass; the draft matches the frozen candidate; documents agree. **Stop if:** metadata, signature, architecture, license or checksum checks fail. Preserve the previous artifact and repeat only checks affected by a fix. Do not repeat a successful build just to reconfirm it: another build can change the build number, signature and DMG bytes.

### Phase 3 — Publish the reviewed source, tag and prerelease

**Input:** the frozen candidate, final diff and English/Korean release notes covering features, support, ad hoc signing and actual validation limits. Review and commit only the intended source, license, documents and Cask draft; generated app/DMG files remain outside Git. Push the reviewed commit to source `main` and verify the remote revision before tagging it.

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

Use the reviewed notes file. Resolve the annotated tag to the exact reviewed commit. If a tag or release already exists, inspect its commit and assets; resume only a matching incomplete operation. Never force, delete or overwrite a published tag/asset. Download both public assets to a separate verification directory and check the uploaded `.sha256` there against the frozen candidate's digest. Confirm the release is a prerelease.

**Complete when:** remote source and tag match the reviewed commit, public download bytes match and release notes accurately describe validation. **Stop if:** source/tag identity, public download or checksum cannot be confirmed. Do not publish a Tap against a missing or mismatched asset.

### Phase 4 — Create and publish the Tap

**Input:** the verified public prerelease and final Cask draft. Use a separate checkout for the public `soom-kang/homebrew-touch-me` repository; do not nest another Git repository inside the source project. The Tap needs `Casks/touch-me.rb`, a short README with support and install guidance, the project MIT license and the following exact-version exception at `audit_exceptions/github_prerelease_allowlist.json`:

```json
{
  "touch-me": "0.8.0-beta.1"
}
```

This allows the intended beta version through the GitHub prerelease check. Do not use `all`, `any`, a global signing exception or an audit command that skips the prerelease check. Update this version deliberately with each beta release.

Copy the final draft to `Casks/touch-me.rb`, compare its version/URL/hash with the verified public DMG and run style on its absolute path before publication:

```bash
brew style /absolute/path/to/homebrew-touch-me/Casks/touch-me.rb
```

Review the Tap diff, then commit and publish only those files. Do not add CI or test infrastructure for this small Tap.

**Complete when:** the public Tap contains the reviewed Cask, exact-version exception, README and license; local style passes. **Stop if:** the Tap already contains unexpected history, a checksum differs or style reports an unresolved error. Preserve the source release and stop only Tap publication.

### Phase 5 — Trust the selected Cask and run online audit

**Input:** the published Tap and verified public assets. Scope local trust to the selected Cask:

```bash
brew tap soom-kang/touch-me
brew trust --cask soom-kang/touch-me/touch-me
brew audit --cask --online soom-kang/touch-me/touch-me
```

Homebrew 7.0.8 was inspected on 2026-10-07. An ordinary online audit skips signing for non-official taps; `--new` requests signing checks and does not fit this ad hoc beta route. The exact-version Tap exception handles the intentional prerelease while leaving other ordinary audit checks enabled. Recheck this behavior if Homebrew changes. Relevant upstream code: [Cask audit](https://github.com/Homebrew/brew/blob/7.0.8/Library/Homebrew/cask/audit.rb), [audit command](https://github.com/Homebrew/brew/blob/7.0.8/Library/Homebrew/dev-cmd/audit.rb) and [GitHub release checks](https://github.com/Homebrew/brew/blob/7.0.8/Library/Homebrew/utils/shared_audits.rb).

**Complete when:** selected-Cask trust and the ordinary online audit succeed, and release/Tap URLs, source revisions, build number, checksum and command results are recorded. **Stop if:** trust or audit has an unexplained failure. Do not hide it by excluding checks. This release run ends here. Homebrew installation, Gatekeeper approval, GUI language switching, real-device mapping and login launch are `NOT_RUN`; audit does not establish those behaviors. Leave the existing `/Applications/Touch Me.app` in place.

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

Removal preserves app preferences. There is no `zap` routine, automatic process kill or device-recovery hook. A failed restoration blocks upgrade/removal until the panel is reconnected to the same USB port and Stop succeeds.

## Record results and future signing work

The release owner records the source revision, tag, build number, DMG SHA-256, Homebrew version, executed commands and outcomes with an `Asia/Seoul` date. Keep artifact, Homebrew audit, GUI, real-device and login-launch results separate. Preserve the historical build 8–10 evidence in [Workflow](../Workflow.md#choose-the-minimum-checks); it does not prove behavior for a later candidate. Never include credentials or raw personal data.

A later Developer ID release needs separately approved signing/notarization preparation and validation of the final downloaded, installed app. Keep credential access outside this runbook and record that release's verification separately from this ad hoc beta.
