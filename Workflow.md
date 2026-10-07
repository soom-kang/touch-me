[English](Workflow.md) · [한국어](Workflow.ko.md) · [Use the app](README.md) · [Homebrew distribution](docs/Homebrew.md)

<!-- meta.contentType: How-to; audience: contributors; goal: build and package Touch Me locally; content plan: environment, modules, build, packaging, checks, recovery, release. -->

# Build and package Touch Me locally

Use this workflow to build the arm64 app, inspect its bundle and create a personal disk image. The existing scripts use Apple's local tools and Python 3. They do not install additional dependencies or publish artifacts.

## Prepare your environment

Use an Apple Silicon Mac with macOS 26 or later, Swift tools compatible with the package's Swift 6.0 manifest, and Python 3. Run commands from the project directory. Building does not require a connected touchscreen.

The app keeps these identifiers and versions:

| Field                 | Value                                             |
| --------------------- | ------------------------------------------------- |
| App and executable    | `Touch Me.app` / `TouchMe`                        |
| Bundle identifier     | `io.github.soom-kang.touchme`                     |
| Release version       | `0.8.0-beta.2`, read from `VERSION`               |
| Bundle version        | `0.8.0` plus an incrementing numeric build number |
| Full release metadata | `TouchMeReleaseVersion=0.8.0-beta.2`              |
| Target                | `arm64`, macOS 26 or later                        |

Keep the identifier and saved-preference format stable when changing documentation or packaging. Changing the signing identity or installation path can require permission checks in the installed app.

## Understand the modules

The package separates session logic from macOS device access and app controls:

| Module             | Responsibility                                                                                         |
| ------------------ | ------------------------------------------------------------------------------------------------------ |
| `TouchMappingCore` | Coordinate normalization, screen mapping and contact-state effects                                     |
| `TouchMePlatform`  | USB Human Interface Device (HID) discovery, display selection, P16KT mode restoration and macOS events |
| `TouchMeApp`       | Menu bar, settings and test windows, preferences, login launch and resume decisions                    |

The app accepts one verified panel and an eligible external display. Mapping opens the device exclusively, enables the verified mode when needed, and restores it on Stop or normal Quit. Restoration failure stays visible and can block Quit.

No app networking code or raw-input logging is implemented in the current source. Preferences store the selected device/display identity, the intent to resume and the app's language selection; they do not store a touch history. English is the default, and changing language updates app-owned UI without restarting the session or changing macOS language settings.

## Build and inspect the app

Build the release executable and bundle it with icons and the project license:

```bash
bash scripts/build-app.sh
```

The script creates `dist/Touch Me.app`, increments the previous local bundle's build number and preserves the previous app under `dist/previous-builds`. It applies an ad hoc signature and verifies it with `codesign --verify --strict`.

Check the bundle metadata and license resource before making a disk image:

```bash
plutil -p 'dist/Touch Me.app/Contents/Info.plist'
cat 'dist/Touch Me.app/Contents/Resources/Licenses.txt'
codesign --verify --strict 'dist/Touch Me.app'
```

`Licenses.txt` contains the project `LICENSE`. A missing license file stops bundling. Ad hoc signature verification confirms local bundle integrity; it does not establish Developer ID signing or notarization.

## Create the personal disk image

Package the signed app, an Applications shortcut and bilingual installation notes:

```bash
python3 scripts/package-dmg.py
```

The script verifies the app's identifier, release metadata against `VERSION`, license-resource presence, signature and arm64 architecture. A stale bundle stops packaging instead of receiving a new release filename. It creates these outputs:

| Output                                        | Purpose                   |
| --------------------------------------------- | ------------------------- |
| `dist/Touch Me.app`                           | Locally signed app bundle |
| `dist/touch-me-0.8.0-beta.2-arm64.dmg`        | Local beta disk image     |
| `dist/touch-me-0.8.0-beta.2-arm64.dmg.sha256` | SHA-256 checksum          |

An existing image moves to `dist/previous-builds`. Verify the new checksum from `dist`:

```bash
(cd dist && shasum -a 256 -c touch-me-0.8.0-beta.2-arm64.dmg.sha256)
```

![Local packaging flow from source and license files to a signed app, personal disk image and SHA-256 checksum.](docs/assets/packaging.png)

[Editable diagram](docs/assets/packaging.html)

Do not replace an image while it is mounted. Eject it normally first. If it is busy, stop the replacement and close the application using it; do not force eject.

## Choose the minimum checks

Match verification to the behavior you changed. Add checks only when a defect or a new compatibility claim requires them:

| Change                                        | Minimum check                                                                                               |
| --------------------------------------------- | ----------------------------------------------------------------------------------------------------------- |
| Documentation or image                        | Read the whole affected document; check links, translations and rendered images                             |
| License menu or packaging                     | One release build; inspect license resources, signature, disk image and checksum                            |
| App language                                  | One release build; check English default, both directions of immediate switching and persistence where safe |
| Coordinate or gesture logic                   | Run `bash scripts/test.sh`; check the affected gesture on the target panel                                  |
| Device opening, mode restoration or lifecycle | Check exclusive ownership, input release and restoration on the target panel                                |
| Signing, login launch or compatibility        | Check the installed app in the changed environment                                                          |

The existing core tests cover pure logic. They do not prove HID access, device-mode restoration, permissions or behavior on a physical panel. Do not add test infrastructure for a documentation-only change.

Before opening a language-check candidate, confirm that any other app with the same Bundle Identifier has quit and the P16KT is disconnected. Otherwise record GUI checks as `NOT_RUN`. An existing app being activated, or a saved mapping session resuming, is not evidence for the candidate. Check the menu and an already-open test window as well as settings; switching languages must preserve target confirmation and test history. Recorded build 8 and build 9 checks below remain historical evidence.

The retained 2026-10-07 build 8 notes record user-reported standalone gestures, Quit/resume, Stop persistence, login-item toggling and Finder installation. They also record package, signature, checksum and process checks. Those records do not prove behavior in a newly rebuilt app. Full logout/login is `NOT_RUN`; horizontal scrolling after automatic resume is `NOT_RETESTED`.

The 2026-10-07 documentation and license update produced build 9. Release compilation, strict ad hoc signature verification, exact license-resource content, arm64 architecture, bilingual installation notes, read-only disk-image inspection and SHA-256 verification passed. The packaged executable and icon matched the local app. Core tests and device checks were not repeated because mapping logic stayed unchanged; opening the new app's License menu was not exercised.

### v0.8.0-beta.1 local preparation

On 2026-10-07 (`Asia/Seoul`), the language/version preparation produced build 10 with `CFBundleShortVersionString=0.8.0` and `TouchMeReleaseVersion=0.8.0-beta.1`. `bash scripts/build-app.sh` passed release compilation with warnings as errors and strict ad hoc signature verification. Exact bundled license content and icon content matched the source. Missing Command Line Tools framework/library search paths produced non-fatal linker warnings; the build completed.

The first `python3 scripts/package-dmg.py` attempt failed at `hdiutil create` under the restricted execution environment. It succeeded with the required local disk-image access. After removing publication-timing wording from the installation notes, only packaging was repeated with the same build 10 app. That DMG passed `hdiutil verify` and its SHA-256 check. `ruby -c packaging/homebrew/touch-me.rb.in` passed, and the draft's digest matched that candidate. Missing/invalid `VERSION` and stale bundle metadata were checked in temporary inputs and rejected before artifact replacement. These checks cover the build 10 preparation; a later release candidate needs its own artifact checksum and packaging results. Previous app and DMG artifacts were retained.

GUI language switching, relaunch persistence, open test-window behavior and clipping are `NOT_RUN`: USB registry queries failed, so physical P16KT disconnection could not be confirmed. No existing Touch Me process was found, and the candidate was not launched. Source review confirmed that language changes update presentation without restarting models or calling mapping/login actions. Core tests were not repeated because core logic is unchanged; no test files or dependencies were added. Homebrew style/audit/install, downloaded Gatekeeper handling, device mapping and login launch remain `NOT_RUN`. Local build/signature results do not establish those behaviors.

### v0.8.0-beta.1 release candidate

On 2026-10-07 (`Asia/Seoul`), release preparation produced build 11. One release build passed compilation with warnings as errors and strict ad hoc signature verification. The bundled `Licenses.txt` exactly matched the project `LICENSE`. Packaging rejected the previous bundle's different license resource before staging; the rebuilt app passed packaging, arm64 checks, `hdiutil verify` and SHA-256 verification.

The frozen DMG SHA-256 is `eb255a5296921c93c2cd8d9de98b7424fc380e7b3a24e713c682df0cf500b618`. The local Cask draft and Tap Cask use that digest. Ruby syntax passed. The first Homebrew style run needed access to its tool cache; the style check then reported a redundant platform name in the Cask description. After correcting that description, the same file passed with no offenses. English/Korean packaging images were regenerated with the existing design and checked for clipping. See the [release notes](docs/releases/v0.8.0-beta.1.md) for support and validation limits.

This candidate's GUI, Gatekeeper, real-device, login-launch and Homebrew installation checks remain `NOT_RUN`. Source and Tap publication and online audit follow the runbook phases; their actual results are recorded separately from local artifact checks.

### v0.8.0-beta.2 release candidate

On 2026-10-07 (`Asia/Seoul`), the existing Python packaging suite initially passed 17 of 18 tests. The permission-failure fixture used the macOS `/var` path alias while packaging resolved it to `/private/var`, so its mock did not exercise the intended failure. Resolving the fixture's temporary root fixed that mismatch; the repeated suite passed all 18 tests. The existing Swift suite passed all 14 tests in one run. No new tests or validation infrastructure were added.

One release build produced build 12 with numeric bundle version `0.8.0` and `TouchMeReleaseVersion=0.8.0-beta.2`. Release compilation, strict ad hoc signature verification, exact bundled license/icon content, arm64 packaging, `hdiutil verify` and SHA-256 verification passed. Missing Command Line Tools framework/library search paths produced non-fatal linker warnings. The frozen DMG SHA-256 is `b667c7ba2518b966fec2fdc4b92152d66db58b0758460e5c5f4daa42cd5d3469`. These are local artifact results; publication, Cask style and online audit results are recorded separately. GUI, Gatekeeper, real-device, login-launch and Homebrew installation checks are `NOT_RUN`. See the [release notes](docs/releases/v0.8.0-beta.2.md) for this release's changes and limits.

## Handle failures without changing the scope

A build or packaging failure is a stop condition for delivering a new artifact. Fix the reported local cause and repeat only the failed command. Retain the previous usable artifact until the replacement passes its checks.

If device restoration fails during an approved device check, reconnect the P16KT to the same USB port and retry Stop. Do not hide the failure, silently switch devices or overwrite the stored resume intent to claim recovery.

After a completed cleanup, `.build` and `dist/previous-builds` may be absent. Subsequent builds recreate them. Inspect the exact generated paths and active mounts before removing them; do not follow symlinks into external folders.

## Publish the reviewed release

The `0.8.0-beta.2` route updates the ad hoc beta Cask in the existing personal Tap `soom-kang/homebrew-touch-me`. The source repository is [soom-kang/touch-me](https://github.com/soom-kang/touch-me). The reviewed release starts from `main` at `abbfece6ea621b13bd9832b53976ce0acd67f839`. On 2026-10-07, the release task authorized the reviewed source update, tag/prerelease and Tap update through online audit. Each phase advances when its checks pass; a new decision or failed check stops the affected phase.

Follow [Homebrew distribution](docs/Homebrew.md) for release phases, checksum freeze, first-launch handling and Tap checks. The ad hoc beta is not notarized and does not claim Gatekeeper approval. A future Developer ID release requires signing, notarization and a new check of the final installed artifact's permissions and device behavior.

Homebrew installation, replacement of `/Applications/Touch Me.app`, GUI/device checks, privacy changes and login-item registration are outside this release run. Future executions require their own authorized scope. Keep credentials out of commands, logs and documentation.

Touch Me uses the [project MIT License](LICENSE).
