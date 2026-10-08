# Build 11 release evidence and remaining native checks

Ticket: TMQA-001. Recorded 2026-10-07 UTC. This checklist concerns the already
published beta, not a newly built app from this QA branch. It is **not a native
QA pass or a release approval**. Updating this file does not authorize installing,
changing privacy settings, registering login items, or writing to a real device.

## Pinned artifact

- Source: `soom-kang/touch-me@0d94054bf969ff1d6471e7081b577394c2ab7354`
- Tap: `soom-kang/homebrew-touch-me@25597107b001444c381f5499895f1d11c7a5b0e4`
- Tag: `v0.8.0-beta.1`, resolves to the source SHA above
- [Release](https://github.com/soom-kang/touch-me/releases/tag/v0.8.0-beta.1)
- Artifact: `touch-me-0.8.0-beta.1-arm64.dmg`, 357087 bytes
- SHA-256: `eb255a5296921c93c2cd8d9de98b7424fc380e7b3a24e713c682df0cf500b618`
- Published `2026-10-07T05:19:42Z`, prerelease true
- Bundle release `0.8.0-beta.1`, numeric version `0.8.0`, build `11`
- Bundle ID `io.github.soom-kang.touchme`, executable `TouchMe`
- Minimum OS `26.0`, Mach-O arm64, languages `ko` and `en`

## Cloud results

| Check | Result | What it establishes |
| --- | --- | --- |
| Actual versioned DMG and checksum download | PASS | Downloaded bytes, not installation |
| Published checksum and both cask digests | PASS | SHA-256 equality for pinned artifact |
| Annotated tag and source HEAD | PASS | Same commit; not reproducible-build proof |
| Source cask draft and Tap cask | PASS | Exact body equality after draft comments |
| Exact-version prerelease exception | PASS | Only `0.8.0-beta.1` allowed |
| Read-only UDIF/HFS+ inspection | PASS | Bundle metadata above and source LICENSE equality |
| Mach-O CodeDirectory hashes | PASS, limited | 43 SHA-256 code slots and Info.plist/CodeResources special slots match |
| Ad hoc flag | PRESENT | No assertion of certificate trust or Gatekeeper acceptance |
| macOS codesign, Gatekeeper, Homebrew install | NOT_RUN | Linux cloud has no macOS runtime |
| Swift test runner | BLOCKED | Missing xcrun and Swift; no Swift test ran |
| Physical-device and login lifecycle checks | NOT_RUN | No connected panel or macOS session |

The downloaded app was neither mounted nor executed. Hash checks do not replace
Apple's native validation tools. Historical build 8 reports in the README remain
historical; they do not establish these build 11 checks.

## Native verification record

Before running, record OS version, machine architecture, app build and checksum,
installation path, panel model, USB connection, other mapper state, operator,
time, and the approved scope. Do not record credentials or raw touch data.
Use `PASS`, `FAIL`, `NOT_RUN`, or `BLOCKED` per row, with observed evidence.
A checkbox alone without artifact identity and observed result is insufficient.

| ID | Scenario | Expected safety or behavior | Status |
| --- | --- | --- | --- |
| N01 | Fresh cask installation | Correct app installed; no forced overwrite | NOT_RUN |
| N02 | Existing manual app | Stop, restore, normal Quit, preserve old app first | NOT_RUN |
| N03 | No permissions / each permission missing | Start blocked; actionable status | NOT_RUN |
| N04 | Both permissions and confirmed matching panel/display | Start succeeds; initial held finger must lift | NOT_RUN |
| N05 | Two-position tap, drag, double-click | Correct target and release; no stuck button | NOT_RUN |
| N06 | Two-finger vertical and horizontal scroll | Scroll without preceding tap; remaining finger does not click | NOT_RUN |
| N07 | Stop during drag and repeated Stop | Input released once; stays stopped on relaunch | NOT_RUN |
| N08 | Normal Quit during mapping, then relaunch | Release and restore; resume only with all saved conditions | NOT_RUN |
| N09 | Permission loss / display change / USB removal | Input stops; failure is visible; no unverified target used | NOT_RUN |
| N10 | Restore failure using approved fault setup | New Start blocked; Quit can be cancelled; no silent success | NOT_RUN |
| N11 | Same-port reconnect after restore failure | Rebind only verified panel; retry restore succeeds or stays blocked | NOT_RUN |
| N12 | Original mode 0 versus original mode 2 | Stop returns to actual session-start state | NOT_RUN |
| N13 | Sleep/wake, inactive session, user switch | Build 11 stays stopped; current development recovery is documented in lifecycle policy | NOT_RUN |
| N14 | Full logout/login with login launch enabled | App launch and mapping intent evaluated separately; record notification order | NOT_RUN |
| N15 | Horizontal scroll after automatic resume | Same supported gesture behavior as manual start | NOT_RUN |
| N16 | English/Korean changes while mapping | Session/selection maintained; messages and menus update | NOT_RUN |
| N17 | Upgrade or uninstall | Successful Stop/restore/normal Quit precede package change | NOT_RUN |

Do not force a crash, unplug during a write, or change permissions merely to fill
this table without an approved safe test setup. Prefer adapter fault injection
before hardware fault cases. Abort upgrade/removal if restoration is unresolved.
A failure needs a separate bug with exact build, sequence, expected/actual result,
and a recovery record. Native rows remain open until supported evidence exists.

## Recheck trigger

A new app build, signature, lifecycle/device code change, or release artifact
requires affected checks on that exact new artifact. Do not carry this checksum
or the historical device results forward to a different binary.
