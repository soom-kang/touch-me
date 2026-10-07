[English](Homebrew.md) · [한국어](Homebrew.ko.md) · [Build workflow](../Workflow.md) · [Use the app](../README.md)

# Prepare the Touch Me Homebrew beta

This runbook prepares `0.8.0-beta.1` for a personal Tap. The current deliverables are a local ad hoc app, DMG, checksum and Cask draft. Publishing the source or Tap, pushing a tag, releasing assets, trusting a Cask and installing it are later actions that require approval. The planned repositories below have not been verified as publicly available.

## Release contract

| Item | Agreed value |
| --- | --- |
| Source repository, planned | `soom-kang/touch-me` |
| Tap repository, planned | `soom-kang/homebrew-touch-me` |
| Tap / Cask token | `soom-kang/touch-me` / `touch-me` |
| Release version / tag | `0.8.0-beta.1` / `v0.8.0-beta.1` |
| Asset | `touch-me-0.8.0-beta.1-arm64.dmg` and its `.sha256` file |
| App / identifier | `Touch Me.app` / `io.github.soom-kang.touchme` |
| Minimum environment | Apple Silicon, macOS 26 (Tahoe) or later |
| Device scope | One ZEUSLAP P16KT, USB `0x0457:0x0819`, eligible external display |
| Signing | Ad hoc; no Developer ID signature or notarization |
| Draft / future Tap file | `packaging/homebrew/touch-me.rb.in` / `Casks/touch-me.rb` |

`VERSION` is the release-version source. The bundle uses numeric `CFBundleShortVersionString=0.8.0`, an incrementing numeric `CFBundleVersion` and `TouchMeReleaseVersion=0.8.0-beta.1`. The app's About and settings displays use the full release version. [Apple version format](https://developer.apple.com/help/glossary/version-number/)

One app contains English and Korean. It starts in English without a saved language, changes language in settings and preserves that preference. The Cask does not select a language or install different language artifacts.

The draft uses a versioned asset URL:

```text
https://github.com/soom-kang/touch-me/releases/download/v0.8.0-beta.1/touch-me-0.8.0-beta.1-arm64.dmg
```

Its SHA-256 must match the exact DMG uploaded. The path is fixed by convention; GitHub assets can still be replaced. Treat the published version as immutable: if source, signature or DMG bytes change after publication, use a new release version and checksum. Never resolve a mismatch with `:no_check`.

## Execute each phase

### Phase 0 — Preserve the starting state

**Input:** the local project and existing app/DMG. Inspect the instructions, build scripts and file list. Run `git status --short` when Git metadata exists; this checkout had no Git repository at the start of this preparation. Preserve a file snapshot outside the project and record the intended changes. Do not initialize Git as part of the local preparation.

**Complete when:** original files and generated artifacts can be distinguished from this work. **Stop if:** existing changes cannot be preserved or an image being replaced is mounted. Eject normally; do not force eject.

### Phase 1 — Add the app language selector

**Input:** the bilingual app text and preferences. Add English / 한국어 selection at the top of settings, defaulting to English for missing or invalid values. Update settings, menus, existing status/error messages and open test windows immediately while retaining session and target state. Keep macOS dialogs, system errors and display product names in their existing form.

**Complete when:** the code retains one app/session model and persists the language independently of macOS language settings. GUI confirmation also needs any other app with the same Bundle Identifier to be closed and the P16KT disconnected. Check English default, both switching directions, existing messages, an open test window, clipping and selection after relaunch. **Stop the GUI check if:** either isolation condition is unavailable; record it as `NOT_RUN`. Do not reset mapping preferences or privacy permissions to manufacture a clean test.

### Phase 2 — Build and freeze the local candidate

**Input:** the reviewed source and `VERSION=0.8.0-beta.1`. Run from the project root:

```bash
bash scripts/build-app.sh
python3 scripts/package-dmg.py
(cd dist && shasum -a 256 -c touch-me-0.8.0-beta.1-arm64.dmg.sha256)
```

The existing scripts perform release compilation with warnings as errors, bundle creation, strict ad hoc signature verification and packaging checks for identity, version, notices and arm64 architecture. Inspect `Info.plist` and the bundled notices as described in [Workflow](../Workflow.md). Record the build number and checksum. The package command must reject a bundle with stale release metadata.

**Complete when:** both scripts and checksum verification pass, and the exact candidate files are retained. **Stop if:** compilation, metadata, signature, architecture, notices or checksum checks fail. Preserve the last usable artifact; fix the local cause and repeat only affected checks. Do not run a second successful build just to reconfirm it: rebuilding changes the build number, signature or DMG bytes and invalidates the frozen checksum.

### Phase 3 — Finish the local Cask draft and documents

**Input:** the final candidate's checksum and the agreed release contract. Set the draft's `sha256` to that exact digest. Keep the `.rb.in` suffix to distinguish preparation from a Tap's loadable `Casks/touch-me.rb`.

```bash
ruby -c packaging/homebrew/touch-me.rb.in
```

Read both versions of this runbook and the affected README/Workflow pages. Confirm version, asset name, URL, support limits and approval boundaries agree. The Cask uses `app "Touch Me.app"`, arm64/Tahoe requirements, a skipped `livecheck` for manually maintained beta releases and installation caveats. It has no launch hooks, permission changes, `zap`, language-specific downloads or auto-update claim. [Cask Cookbook](https://docs.brew.sh/Cask-Cookbook)

**Complete when:** Ruby syntax passes, the digest matches the final candidate and documents agree. **Stop if:** the candidate changes, the digest differs or the draft implies that unpublished URLs work. This ends the current preparation. Homebrew style, online audit and installation remain `NOT_RUN` until the later phases.

### Phase 4 — Publish the approved source and prerelease

**Input:** explicit approval for Git initialization, reviewed commits, remote creation, push and publication; a frozen candidate; approved release notes containing signing/support limits and actual validation results.

First verify the planned repository's ownership and availability. If it is absent, create `soom-kang/touch-me` as an approved public repository. Initialize local Git only if still absent, review `.gitignore` (`.build`, `dist`, `.DS_Store`), and stage the reviewed source, license notices, documentation and Cask draft. Inspect the staged diff for unrelated files and sensitive data before an explicitly requested commit. Configure the approved remote and push that reviewed commit. Do not use force or bypass hooks.

After the commit and remote are confirmed, the release commands are:

```bash
git tag v0.8.0-beta.1
git push origin v0.8.0-beta.1
gh release create v0.8.0-beta.1 \
  --repo soom-kang/touch-me --verify-tag --prerelease \
  --title 'Touch Me v0.8.0-beta.1' \
  --notes-file /path/to/approved-release-notes.md \
  dist/touch-me-0.8.0-beta.1-arm64.dmg \
  dist/touch-me-0.8.0-beta.1-arm64.dmg.sha256
```

Replace the release-notes path with the approved file. If the tag or release already exists, inspect it and stop on a mismatch; do not overwrite it. Download the public asset into a separate verification directory and run the uploaded `.sha256` check there. Confirm that its digest equals the frozen candidate and that the release remains marked prerelease.

**Complete when:** the public tag references the reviewed source, download bytes match and release notes accurately record limits. **Stop if:** ownership, approval, source/tag identity, public download or checksum cannot be confirmed. Do not publish the Tap against a missing or mismatched asset.

### Phase 5 — Publish the Tap and verify installation

**Input:** the verified public release and explicit approval for the Tap repository, push, Cask trust and local installation. Use a separate checkout for `soom-kang/homebrew-touch-me`; do not create a nested Git repository inside the source project. Copy the final draft to `Casks/touch-me.rb`, compare its version/URL/hash with the public DMG, and publish only the reviewed Tap change.

After publication, narrow trust to this Cask and check it:

```bash
brew tap soom-kang/touch-me
brew trust --cask soom-kang/touch-me/touch-me
brew style --cask soom-kang/touch-me/touch-me
brew audit --cask --online soom-kang/touch-me/touch-me
```

Homebrew 7.0.8 was inspected on 2026-10-07. Its ordinary online audit skips signing for non-official taps, while `--new` requests signing checks. The separate `github_prerelease_version` audit can reject an intentional GitHub prerelease. Keep the ordinary result. If the only exception is that beta policy, record a second, explicitly limited result:

```bash
brew audit --cask --online --except=github_prerelease_version soom-kang/touch-me/touch-me
```

Do not call the limited result an unrestricted audit pass, suppress other failures or disable signing requirements globally. Recheck this behavior if Homebrew changes. Auditing a private Tap does not establish Gatekeeper acceptance. The relevant inspected upstream code is [Cask audit](https://github.com/Homebrew/brew/blob/7.0.8/Library/Homebrew/cask/audit.rb), [audit command](https://github.com/Homebrew/brew/blob/7.0.8/Library/Homebrew/dev-cmd/audit.rb) and [GitHub release checks](https://github.com/Homebrew/brew/blob/7.0.8/Library/Homebrew/utils/shared_audits.rb).

Install only after resolving conflicts as described below. Record actual download, installation, first launch, language selection, privacy permission handling and P16KT behavior separately. A successful install alone does not validate mapping.

**Complete when:** the exact public artifact installs and recorded installed-app results support the declared scope. **Stop if:** style/audit has an unexplained error, a conflicting app remains, device restoration fails, Gatekeeper reports damage/malware or installed-app checks fail. Preserve evidence and the known-good candidate; do not automate recovery by changing security settings.

## Install, update and remove after publication

These commands are future instructions, not evidence that the Tap is available. Fully qualified installation scopes trust to the selected Cask rather than the whole Tap. [Tap Trust](https://docs.brew.sh/Tap-Trust)

```bash
brew install --cask soom-kang/touch-me/touch-me
```

If `/Applications/Touch Me.app` was installed manually, first turn off **Launch at login**, select **Stop mapping**, then use normal **Quit**. Confirm device-mode restoration completed. Preserve the old app by moving it outside Applications before installing through Homebrew; do not force Homebrew to overwrite it. Keep its saved preferences. Stop if restoration fails.

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

The release owner records the source revision, tag, build number, DMG SHA-256, Homebrew version, executed commands and their outcomes with an `Asia/Seoul` date. Keep candidate GUI, real-device, login-launch and Homebrew results separate. Preserve the historical build 8/9 evidence in [Workflow](../Workflow.md#choose-the-minimum-checks); do not reuse it as proof for this candidate. Never include credentials or raw personal data in the record.

A later Developer ID release needs separately approved signing/notarization preparation and validation of the final downloaded, installed app. Keep credential access outside this runbook and record that release's verification separately from this ad hoc beta.
