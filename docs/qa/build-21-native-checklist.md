# Public beta.4 build 21 acceptance (QA-01)

Status on 2026-10-09: **BLOCKED / NOT_RUN**. The cloud executor is Linux, with no
macOS GUI, xcrun, Swift, Homebrew or P16KT. The user's Mac is not authorized for
this task. None of the source fixes on `fix/macos-qa-20261009` changes the already
published build 21. Do not report checks of one as checks of the other.

## Verified artifact baseline

- App source/tag: `346fca27da6b2ebe10e24c27ad13f49e8481af12`, `v0.8.0-beta.4`.
- Tap: `0a73f54c402d2ed04df8cf0d9e8f9b8a0b594958`.
- Public file: `touch-me-0.8.0-beta.4-arm64.dmg`, 396,800 bytes.
- SHA-256: `ebc23abfa4ee9b8e196bd41edb676ed671b1200d63e4eca677c92eba2bbb7b89`.
- The earlier 2026-10-09 cloud audit downloaded the file and verified the sidecar,
  Cask and public release digest. That PASS establishes bytes, not installation.
- Source changes do not warrant editing the Cask checksum/version or issuing a
  new release. Tap changes are not required for the current fix branch.

## Authorized native setup required

Apple Silicon, macOS 26+, one P16KT on a recorded USB-C port, eligible external
screen, no competing mapper. Obtain permission before installing, changing TCC
or login settings, restarting the session, or removing an installed app. No
forced crash, arbitrary feature write, quarantine bypass or destructive reset is
part of this checklist. The app remains ad hoc signed, not notarized.

Record macOS version, Mac model, panel identity/firmware if available, connection,
installed bundle version/build, process executable path and test time. Confirm
the installed process is **0.8.0-beta.4, build 21, arm64** before the checks.

| Check | Required evidence | Result |
| --- | --- | --- |
| Homebrew install / first launch | One clean install, installed identity, Gatekeeper result, denied permissions block Start; approved permissions refresh accurately | NOT_RUN |
| Target / coordinates | Test window on the selected panel; two separated taps stay on that screen; record confirmation-cancel/Refresh behavior | NOT_RUN |
| Gestures | Tap/double tap, drag below/above 8 units, staggered horizontal/vertical scroll with no preliminary downs, second finger during drag, full lift reset; event counts/trace | NOT_RUN |
| Stop / Quit / reconnection | Stop clears restart intent; normal Quit preserves allowed resume; same-port reconnection and visible restore failures; no unresolved recovery hidden | NOT_RUN |
| Lock / sleep / login | One lock/unlock and sleep/wake; recovery timing, Stop cancellation; actual logout/login separately if authorized | NOT_RUN |
| Upgrade / removal | Earlier beta → build 21, permission recheck, normal stop/restore/Quit, login disabled before removal; app/process gone, documented preferences preserved | NOT_RUN |

An unavailable prior beta leaves upgrade NOT_RUN; clean installation cannot
substitute for it. Keep logout/login NOT_RUN if only lock/unlock was tested.
Use PASS/FAIL/NOT_RUN per row with logs/screens or measured events, not an overall
PASS inferred from packaging. The new branch's backlog and confirmation fixes
need a separately built candidate and are not retroactively present in build 21.

## Exit conditions

QA-01 remains open until the native rows have evidence. A failure becomes a
narrow product ticket; a blocked or omitted row remains unverified. For abnormal
exit recovery use [TMQA-003's separate decision gate](abnormal-exit-recovery.md),
not a forced-crash test in this normal smoke pass.
