![touch me](docs/assets/touch-me-title.png)

[English](README.md) · [한국어](README.ko.md) · [Build workflow](Workflow.md) · [Homebrew distribution](docs/Homebrew.md)

<!-- meta.contentType: Landing; audience: P16KT owners; goal: install and operate Touch Me; content plan: setup, installation, gestures, recovery, validation, licenses. -->

# Use your P16KT touchscreen on macOS

Touch Me maps touches on a ZEUSLAP P16KT to its selected display. Run the menu bar app to tap, drag, double-click and scroll with two fingers. The current beta is `0.8.0-beta.1`.

## Check your setup

The current implementation targets one connected P16KT on Apple Silicon with macOS 26 or later. The recorded hardware checks used an Apple M4 Max, macOS 26.7.1 and a direct USB-C connection.

| Requirement   | Current scope                                                         |
| ------------- | --------------------------------------------------------------------- |
| Touch panel   | ZEUSLAP P16KT; verified USB device `0x0457:0x0819`                    |
| Display       | External, without rotation or mirroring                               |
| Permissions   | Input Monitoring and Accessibility                                    |
| App languages | English by default; English / 한국어 selector in settings             |
| Distribution  | Ad hoc arm64 app and disk image; personal Homebrew beta Tap          |

Other panels, Intel Macs and older macOS versions have no recorded validation. Stop other touch-mapping software before starting Touch Me.

## Install and start mapping

Use the DMG and checksum from the [v0.8.0-beta.1 release](https://github.com/soom-kang/touch-me/releases/tag/v0.8.0-beta.1), or build them with the [development workflow](Workflow.md). The local image is `dist/touch-me-0.8.0-beta.1-arm64.dmg`. See [Homebrew distribution](docs/Homebrew.md) for Tap installation, manual-app conflicts and release checks.

1. Open the disk image and drag **Touch Me.app** to **Applications**. Eject the image, then open the installed app.
2. Open **System Settings → Privacy & Security**. Allow Touch Me in **Input Monitoring** and **Accessibility**.
3. Connect the P16KT by USB-C. Open **Settings / Proof** from the Touch Me menu bar item.
4. Select the P16KT display and open its test window. Confirm that the window appears on the panel, then select the target-confirmation checkbox.
5. Select **Start mapping** and check taps at two separated positions.

The app stays in the menu bar. Closing the settings window leaves mapping active.

Choose **English** or **한국어** from **Language** at the top of settings. The choice takes effect immediately and stays selected on the next launch. Changing it preserves the current mapping session, selected target and test-window history. macOS dialogs and System Settings keep their own language.

The beta has an ad hoc signature and is not notarized. For a downloaded copy, macOS may block the first launch. Verify its source and checksum before following [Apple's manual approval guidance](https://support.apple.com/en-us/102445); availability of that option does not guarantee the app can run.

## Use touch and control the session

The supported gestures are:

| Action                            | Gesture                                                    |
| --------------------------------- | ---------------------------------------------------------- |
| Click or double-click             | Tap once or twice                                          |
| Drag                              | Hold one finger and move it                                |
| Scroll vertically or horizontally | Move two fingers together                                  |
| Return from scrolling to dragging | Lift both fingers before starting a new one-finger gesture |

Select **Stop mapping** to release input and keep mapping stopped on the next launch. Quitting while mapping preserves the intent to resume. Automatic resume requires the saved display, USB location and both permissions to match.

Sleep, an inactive user session, or a display-configuration change stops mapping and clears the saved intent to resume. Waking or returning to the session does not restart mapping automatically. Check the target and permissions, then start mapping manually. Normal Quit preserves resume intent only if no earlier safety interruption or explicit Stop cleared it.

**Launch at login** is off by default. Enable it in settings after copying the app to Applications. Login launch opens the app; the saved mapping state determines whether it resumes.

## Recover or remove the app

Mapping temporarily changes the verified P16KT device mode. Stop or normal Quit releases input and restores the original mode when a change was necessary. A restoration error can prevent the app from quitting.

| Situation                     | Next action                                                                          |
| ----------------------------- | ------------------------------------------------------------------------------------ |
| A permission is missing       | Allow Touch Me in both privacy settings, then refresh the app                        |
| The panel or display changed  | Reconnect the saved panel to the same USB port; select and confirm the display again |
| Device access fails           | Stop other mappers and check the USB connection                                      |
| Device-mode restoration fails | Reconnect the P16KT to the same USB port and retry **Stop mapping** before quitting  |

To remove Touch Me, turn off **Launch at login**, stop mapping, quit the app and move it to Trash. These steps leave saved preferences in place.

## Understand the mapping path

The app selects the target and controls the session. Platform code reads the panel, calls the coordinate and gesture logic, then posts mouse and scroll events to macOS.

![Touch Me runtime: P16KT input passes through platform and core logic to macOS events on the selected display.](docs/assets/architecture.png)

[Editable diagram](docs/assets/architecture.html) · [Module responsibilities](Workflow.md#understand-the-modules)

## Read the recorded validation

This summary preserves standalone build 8 checks recorded on 2026-10-07, in `Asia/Seoul`. It replaces the retired detailed development notes. The following results came from user reports, with separate process and artifact checks:

- Tap coordinates, one-finger drag and input release after normal Quit
- Two-finger vertical and horizontal scrolling without a preliminary tap
- Double-click detection and automatic resume after normal Quit
- Stop-state persistence and login-item registration and removal
- Finder installation from the personal disk image and subsequent mapping

These are recorded results, not new device checks for a rebuilt app. A full logout/login launch is `NOT_RUN`; horizontal scrolling after automatic resume is `NOT_RETESTED`. Earlier checks with possible interference from another mapper do not establish standalone behavior.

See the [validation boundaries](Workflow.md#choose-the-minimum-checks) before changing device handling or expanding compatibility.

## Read the license

Touch Me uses the [MIT License](LICENSE), copyright 2026 Soom Kang. Open **License** in the app menu to read it.
