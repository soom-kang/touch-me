# Automated QA layers

Ticket: TMQA-005. Tests added here are not a claim that native tests passed.
No CI service, external dependency, device driver, or permission change is added.

## Native page swipe candidate — 2026-10-28

Status: **SOURCE_CHECKS_PASS; LOCAL_ACCEPTANCE_COMPLETE_USER_REPORTED; FINAL_STOP_GUI_CONFIRMED; NOT_PUBLISHED**.
This is unpublished local work based on `be6216d`, with scroll phases,
fixed gesture targeting and explicit scroll termination. The installed beta.11
app and existing permission/trust settings are unchanged.
The latest candidate is build 38, with the contact-source selection fix described
below. Its focused physical results are separate from the broader build 36 matrix;
only explicitly marked cases are **PASS_USER_REPORTED**.
Event construction and receiver observations are tracked separately from these
browser results; a pending row is not covered by another browser's result.

| Build 38 focused physical check | Safari 27.2 | Chrome 156.0.8078.74 |
| --- | --- | --- |
| Fresh tap, vertical scroll and Back/Forward on the same attachment that failed in build 37 | Not separately checked | **PASS_USER_REPORTED** |
| USB removal during an uncommitted transition; full lift, same-port reconnect and automatic resume; B retained, feedback cleared and fresh tap, vertical scroll and Back/Forward | **PASS_USER_REPORTED** | **PASS_USER_REPORTED** |
| Pinch, drag and reversal cancellation after recovery | **PASS_USER_REPORTED** | **PASS_USER_REPORTED** |

Build 38's repeated three-finger left/right and Mission Control gestures,
application to the P16KT in the current multi-display layout, and final Stop are
**PASS_USER_REPORTED**. A later GUI read still showed Running; the agent then
clicked Stop and confirmed **Stopped**, Start enabled and Stop disabled. No cause
is assigned to the difference between the user report and that later GUI state.
The optional Natural scrolling on/off comparison is **NOT_RUN**; the system
setting was not changed. Source checks pass with 39 Platform + 21 Core tests and
App compilation. The agreed local validation is complete, with the candidate
boundaries below. No installation or publication was performed.
Build 38 retains the gesture output behavior from build 36, with the registration
source-selection fix and focused tests. The full build 36 matrix was not repeated.

| Historical build 36 physical check | Safari 27.2 | Chrome 156.0.8078.74 |
| --- | --- | --- |
| Native transition feedback, back/forward, repetition, reversal cancellation | **PASS_USER_REPORTED** | **PASS_USER_REPORTED** |
| History first/last boundary and reverse return after full lift | **PASS_USER_REPORTED** | **PASS_USER_REPORTED** |
| Vertical/diagonal scroll, pinch, tap and text-selection drag without unintended navigation/click | **PASS_USER_REPORTED** | **PASS_USER_REPORTED** |
| Wide page: content-only horizontal scroll in the middle; both actual scrollbar ends match the built-in trackpad | **PASS_USER_REPORTED** | **PASS_USER_REPORTED** |
| Nested scroll: middle and both boundaries; target remains on the original region as fingers cross its border | **PASS_USER_REPORTED** | **PASS_USER_REPORTED** |
| Page overscroll policy compared with the built-in trackpad | **MATCH_NATIVE_USER_REPORTED**: both inputs navigate; CSS blocking was not observed | **PASS_USER_REPORTED**: both inputs block back/forward navigation |
| Stop during an uncommitted transition; full lift, restart and fresh navigation | **PASS_USER_REPORTED** | **PASS_USER_REPORTED** |
| Lock during an uncommitted transition; full lift, unlock and automatic recovery | **PASS_USER_REPORTED** | **PASS_USER_REPORTED** |
| USB removal during an uncommitted transition; full lift, same-port reconnect and automatic recovery | **PENDING** | **FAIL_USER_REPORTED**: automatic resume succeeds, but fresh touch input malfunctions |

At that checkpoint, three-finger, multi-display, the optional alternate Natural
scrolling setting and final Stop had not been checked. The subsequent source-only
help/status update also passed
`bash scripts/test.sh`: 35 Platform + 21 Core tests and App compilation in the
normal host context (`.build/page-swipe-final-tests.log`). Final bounded code
review found no new actionable defect in that source state. At that checkpoint,
build 36 was running for physical checks; the help/status changes had not yet
been bundled or checked in the GUI. The later USB diagnosis and source-selection
change are recorded below, separately from those passing checks.
The chronological record below preserves each development checkpoint. Its
failure and pending labels apply to that checkpoint; build 36 and build 38 results
are separated in the tables above. The initial browser/receiver results belong to
build 34; the follow-up build 35 is described separately.

| Check | Result and boundary |
| --- | --- |
| `bash scripts/test.sh` in the normal host context | **PASS**, 33 Platform + 21 Core tests, including App compilation; no global input is posted |
| Initial restricted-executor run | **FAIL**: the existing keyboard-source test could not create its event source; scroll assertions also required explicit `CGFloat` to `Double` conversion. The corrected suite passed in the normal host context |
| Public precise-scroll event conversion | **PASS**: nonzero began, changed, zero-delta ended/cancelled, signed axes, fixed anchor and no momentum |
| Local build / existing certificate signature | **PASS**, build 34 at `dist/Touch Me.app`; no installation or publication |
| Candidate permissions and target | Both permissions **Allowed** in the GUI; P16KT display 3 confirmed by the user; mapping started |
| Safari page navigation | **FAIL_USER_REPORTED** on the A/B/C local-page fixture; the B page remained visible with both history controls enabled |
| Same-fixture controls | **PASS_USER_REPORTED**: P16KT vertical scrolling and built-in trackpad back navigation both work |
| Listen-only scroll capture | **OBSERVED**: the candidate's began/changed/ended phases and deltas survive the HID and session taps; this does not establish AppKit swipe tracking |
| Temporary AppKit receiver | **OBSERVED** after user-operated comparison: candidate began `dx=33` seeds progress `0.033`, but further progress remains at that value before returning to 0. Physical trackpad begins at `0.001`, progresses and completes at 1. Both trackers complete before the next trial; neither result establishes browser acceptance |
| Chrome, cancellation/edge cases and interruption recovery | **NOT_RUN**, pending resolution of the Safari failure |

Candidate executable SHA-256:
`f751cf66a56b493d37b23382e40739088ce114f38a7278fc0171004c03d4ab1a`.
Native PID `60913` was verified at the local candidate path. The candidate keeps
the unchanged `0.8.0-beta.11` version label but uses build 34; it is not the public
build 33. Environment: macOS 26.7.2, Safari 27.2, Chrome 156.0.8078.74.
Input counters establish posting activity only, not browser handling. No keyboard
navigation fallback is implemented, and native page navigation is not yet accepted.
The receiver uses public `trackSwipeEvent` with symmetric `[-1, 1]` bounds.
Its result rules out an initial direction-sign mismatch for that stroke, but does
not identify which subsequent event property prevents progress. Tracker callbacks
are asynchronous and are not counted as one callback per received scroll event.
The diagnostic receiver and captures are temporary local files, not shipped code.

A second user-operated receiver comparison reproduced the lack of subsequent
synthetic progress. Its separate, time-limited field listener had already exited,
so post-dispatch timestamp and delta-field comparison is **NOT_RUN**; unrelated
mouse-wheel records are not used as evidence. A follow-up candidate assigns a
fresh uptime timestamp immediately before both began and changed dispatch, while
leaving delta, phase and event-source fields unchanged. The three existing scroll
tests pass, including send-time timestamp ordering, and App compilation passes.
After user-completed native authentication, the existing certificate signed local
build 35 and strict signature verification passed. Candidate path remains
`dist/Touch Me.app`; executable SHA-256 is
`bbcada2c049b2bf49a550ce1a1c4345dadc76575e7eddccd2a87f9dda36a7670`.
Native PID `28858` was verified at that path, both permissions remain **Allowed**,
and mapping started with the confirmed P16KT display 3 target. The installed
build 33 executable hash is unchanged. The user-operated receiver comparison
**FAILS_TO_IMPROVE**: build 35 seeds `0.008`, remains there during tracking, then
returns to 0; the physical trackpad progresses and completes at 1. The session
capture independently contains one candidate began, 121 changed and one ended.
Changed timestamps increase and are nonzero; horizontal point deltas sum to 527.
Public raw/accelerated fields are zero on those candidate events. Physical
samples have nonzero raw/accelerated fields, but that difference alone does not
establish causality. The bounded listener exited and the candidate was stopped
normally in the GUI after diagnosis. Safari/Chrome acceptance remains incomplete.

The existing [Mac Mouse Fix scroll implementation](https://github.com/noah-nuebling/mac-mouse-fix/blob/master/Helper/Core/Touch/GestureScrollSimulator.m)
posts a separate, undocumented type-29/subtype-6 gesture event alongside the
ordinary scroll event. This is a source-backed alternative to investigate, not a
verified fix on this candidate. The user explicitly approved extending the
public-scroll-only plan for a local companion-event candidate. The path is being
isolated in the adapter with paired termination and a macOS 26 format guard.
A non-posting check confirms that subtype 6 converts to native event type 29 and
that `CGGesturePhase` values map to the expected `NSEvent.Phase` values on this Mac.
The implemented pairs share location, flags and a fresh timestamp. All began,
ended and cancelled events are allocated before any input; a failed changed-pair
allocation posts neither member and the existing mapper cleanup cancels the
active pair. Unsupported OS/format checks retain public scrolling. The companion
uses the same pixel displacement without the reference project's sensitivity
multiplier. This mapping still needs physical acceptance.

`bash scripts/test.sh` now **PASS**: 35 Platform + 21 Core tests and App compilation
in the normal host context. Independent code review and `git diff --check` pass.
The earlier restricted focused run had 8 passes and one failure in the unchanged
system-key event-source allocation; the complete suite passes without a source
change in the normal host. No companion input has been posted at this checkpoint.

The existing certificate then signed local build 36; strict verification passed.
Its executable SHA-256 is
`5bfa36858f338ad9220a14600f7cf9a399a2ba8b75e124401165a99cd747032f`
at `dist/Touch Me.app`, native PID `43560`. Both permissions remain **Allowed**.
Mapping started on confirmed P16KT display 3 for the companion-event receiver
trial. User-operated receiver results are **PASS_OBSERVED_ON_THIS_MAC**: rightward
tracking grows from `0.012` to `0.642` and completes at 1; leftward tracking grows
from `-0.008` to `-0.545` and completes at -1. The short rightward/reverse stroke
peaks at `0.135`, decreases during return and completes at 0. Each tracker
completes before the next stroke. This demonstrates progress, direction and
reversal cancellation in the temporary receiver, not browser history acceptance.
Safari 27.2 basic acceptance is **PASS_USER_REPORTED** on build 36: P16KT
back/forward navigation follows the fingers, repeats normally, and a short stroke
reversed before lift cancels. This used a fresh A→B→C history, returned to B, in a
test window moved to the P16KT. At that checkpoint, scroll-policy, boundary,
regression and interruption checks were pending. Subsequent results are recorded
in the table above. The installed build 33 hash was unchanged.

Chrome's automated local-file navigation was blocked by the browser tool's URL
policy. No workaround was attempted. Its basic history trial instead uses a
dedicated public-page tab: `https://example.com/` →
`https://www.iana.org/help/example-domains` →
`https://www.iana.org/domains/reserved`, returned to the middle page. The user was
asked to move that tab to the P16KT and report physical navigation, repetition
and reversal cancellation. Chrome 156.0.8078.74 basic acceptance is now
**PASS_USER_REPORTED** on build 36: transition feedback, both directions,
repeated strokes and reversal cancellation all work normally. This does not
cover the local fixture's horizontal-scroll or overscroll-policy cases.
The user subsequently confirmed both actual history boundaries (disabled Back
or Forward control), no extra navigation beyond either end, and normal reverse
return after full lift. On the long IANA page, vertical and diagonal scrolling,
pinch, tap and text-selection drag also work without unintended navigation or
clicks. These additional results apply to Chrome on build 36 only.
The user then opened the existing wide-page fixture manually in both browsers
and prepared forward history with its C link before returning. Both Safari and
Chrome pass middle-of-range content-only horizontal scrolling, and both actual
scrollbar boundaries behave like the built-in trackpad (**PASS_USER_REPORTED**).
The fixture's printed “right end” label was not used to identify the real end.
The nested fixture also passes in both browsers (**PASS_USER_REPORTED**): the
inner content scrolls in the middle, both boundaries match the built-in
trackpad, and moving the fingers outside the inner region without lifting does
not switch the gesture to another region or unexpectedly navigate history.
On the `html { overscroll-behavior-x: contain }` fixture, Safari navigates with
both the P16KT and the built-in trackpad (**MATCH_NATIVE_USER_REPORTED**).
This is not a successful CSS navigation-blocking test and does not, by itself,
demonstrate a Touch Me defect. The observation is consistent with
[WebKit issue 240183](https://bugs.webkit.org/show_bug.cgi?id=240183), still open
when checked on 2026-10-28, which reports Safari history navigation despite this
CSS setting. That issue is supporting context, not proof of the exact code in
the installed Safari binary. On the same fixture, Chrome blocks both back and
forward navigation with both the P16KT and the built-in trackpad
(**PASS_USER_REPORTED**). The browser-specific results are kept separate; Touch Me
does not impose a different history-navigation policy on either browser.
Safari's actual first/last history boundaries and reverse return after full
lift also pass, along with vertical/diagonal scroll, pinch, tap and text-selection
drag without unintended navigation or clicks (**PASS_USER_REPORTED**).
Both browsers' Stop/restart flows pass with an uncommitted transition: page B stays
in place, the transition feedback clears, and fresh back/forward gestures work
after full lift and restart. This is evidence for the complete Stop flow, not
isolated proof of the adapter's cancellation event; the mouse action used to
press Stop can also affect browser tracking. Both browsers' lock/unlock flows
also pass (**PASS_USER_REPORTED**): after locking during an uncommitted
transition, lifting all fingers and unlocking, mapping resumes automatically,
B stays in place, transition feedback clears, and fresh back/forward input
works normally. The Chrome USB interruption/recovery trial then failed according
to the user. The user clarified that mapping resumes automatically but fresh
touch input does not work normally. The subsequent GUI
shows mapping Running with both permissions Allowed on the confirmed display 3,
2,320 received values, maximum two contacts, and zero posted clicks, scrolls,
pinches or system gestures since restart. The scoped recovery log records the
old attachment ending at 14:44:41 KST and verified device reappearance at
14:44:56 KST on 2026-10-28. These observations do not identify the cause or prove
that browser tracking recovered. The local build 36 remains unchanged, and
Safari USB, common regressions and final-candidate work are on hold during
diagnosis. Logs are stored in the ignored `.build/page-swipe-usb-recovery.log`.
A second GUI read before the distinguishing check still shows 2,320 values and
zero output counters. Without reconnecting or restarting, the user was asked to
complete one two-contact touch/full-lift cycle, then a fresh tap and vertical
scroll. Both remained ineffective according to the user; the GUI showed 3,781
received values, maximum three contacts and zero outputs. At that checkpoint the
cause was not established. A local diagnostic candidate was planned to collect
aggregate contact masks and rejection counts without raw coordinates. The
all-lift gate and HID initialization paths had not changed with page swiping;
neither a stale contact nor invalid coordinates had yet been established as the cause.

### USB input diagnosis — 2026-10-28 16:09:51 KST

Temporary diagnostic build 37 uses executable SHA-256
`a7963a60cba3f0e16a53faa48f81d8554e4187bb3f03f196155b81fe35154771`,
with native PID `27492` at `dist/Touch Me.app`. The 56-test suite and native strict
signature verification passed for that candidate. Both GUI permissions remained
**Allowed**, with the same P16KT display 3 target. After normal Stop, Quit and
relaunch, the user still reported ineffective input before another USB trial.

The ignored `.build/page-swipe-input-diagnostic.log` records aggregate fields,
without raw coordinates:

- Start at 16:07:19 KST: `slots=6`, `initialDown=1`, `currentDown=1`,
  `initialReady=false`.
- Stop at 16:09:51 KST: `initialDown=1`, `currentDown=1`, `tipOff=6`,
  `initialReady=false`, `frames=430`, `validEmpty=0`, `missingCoordinates=0`,
  `mappingRejected=0`, `filtered=28`, `excessContacts=0`.

The metadata-only `--scan`, which does not open the device, identifies contact
ordinal 0 as mouse emulation (tip usage page 9, usage 1), followed by five
digitizer contacts (tip usage page 13, usage 66). Its captured output is
`.build/page-swipe-diagnostic-scan.json`. The down-mask bit that persisted belongs
to the inactive mouse source. Source inspection shows that the assembler's
`allLifted` included that source while the later frame path preferred digitizer
contacts. Its retained pressed state prevented an empty accepted frame, leaving
Core's initial-lift gate closed. This identifies the input-blocking path in this
run; it does not establish why the device retained the mouse state.

The source change selects contact keys once at registration through
`HIDContactLayout.mappingKeys`: use digitizer contacts when present, otherwise
retain the pointer-only fallback. Initial tip reads, coordinate callbacks and
all-lift checks then use the same selected source. Full descriptor validation
still precedes selection. The temporary aggregate instrumentation is removed
from the source change. The earlier 56-test result applies to build 37, not this
subsequent fix. The first fix-specific full-suite attempt failed to compile a new
test because a nested `#expect` recursively
expanded. This was a test compilation failure, not a runtime failure. The
expression was extracted before the assertion and the suite was retried. The
retry **PASS** covers 39 Platform + 21 Core tests and App compilation, recorded
in `.build/page-swipe-usb-fix-tests-retry.log`.
The initial failure remains in `.build/page-swipe-usb-fix-tests.log`.

Build 38 was signed successfully at `dist/Touch Me.app`, with executable SHA-256
`1ad79bfc70e3d08b2addce47ff59439ba1e75af59ff3207f50b16906f03bee46`.
Native strict signature verification is **PASS**; the build log is
`.build/page-swipe-usb-fix-build.log`. The launched candidate has both GUI
permissions **Allowed**, and mapping started on the confirmed P16KT display 3.
Runtime versions were rechecked: macOS 26.7.2, Safari 27.2 and Chrome
156.0.8078.74. Native PID is `51263`. At launch, USB recovery acceptance was pending;
the baseline result below preceded the new USB cycles.

Build 38 baseline, before a further cable interruption: **PASS_USER_REPORTED**.
On the same attachment that failed in build 37, the user reports that fresh
Chrome taps, vertical scrolling and Back/Forward all work. The GUI shows Running,
2,748 received values, four posted presses and 671 scroll actions. This confirms
recovery in that attachment; a new USB interruption/reconnect had not yet been run.

The subsequent Chrome USB cycle on build 38 is **PASS_USER_REPORTED**:
automatic resume, B retained, transition feedback cleared and fresh taps,
vertical scrolling and Back/Forward normal. The GUI confirms Running with
1,531 received values, five posted presses and 369 scroll actions after restart.
The following Safari USB cycle on build 38 is also **PASS_USER_REPORTED**:
automatic resume, B retained, transition feedback cleared and fresh taps,
vertical scrolling and Back/Forward normal. The user then confirmed pinch, drag
and reversal cancellation in both browsers (**PASS_USER_REPORTED**). The final
user confirmation covers repeated three-finger gestures without an intervening
mouse click, application to the P16KT and final Stop (**PASS_USER_REPORTED**).
At closeout, the GUI still showed Running; the agent clicked Stop and observed
Stopped, Start enabled and Stop disabled. The counters then showed 7,748 received
values, five posted presses, 1,252 scroll actions, 305 magnification actions and
two system actions in that session. Counters are not substituted for physical
acceptance. The optional alternate Natural scrolling setting remains **NOT_RUN**.
The candidate executable still matches the build 38 hash above; the installed
build 33 executable retains SHA-256
`d2fff378613a3653b7b795008b17d8d7e9f1417c7785cd55c7775222eb207ea6`.
Final documentation checks reuse the unchanged 60-test/build result and run
`git diff --check`; no source tests or packaging checks are repeated for prose.
The existing beta.11 release-document changes are preserved. VERSION, Cask,
installed app, permissions and certificate trust are unchanged; push, tagging,
publication and Homebrew distribution remain outside this task.

An earlier own-process queue experiment compiled but exited with code 133 during
initialization, before its application-start log. Baseline/raw-only/accelerated-only
trials are therefore **NOT_RUN / INVALID_HARNESS**, not evidence for or against a
field's effect. Both diagnostic processes exited; the experiment was not expanded.

## Beta.11 release packaging — 2026-10-25

Gesture source was committed as `f386a89`. Beta.11/build 33 publishes the same
runtime source at `0de6e5a`; release changes are version, packaging instructions,
Cask metadata and documentation. The existing 49 Swift tests are reused and
26 packaging tests passed after the instruction update. One release app and
DMG passed native artifact checks; anonymous public bytes and the published Tap
match. Build 33 GUI/device, installation/upgrade, fresh Gatekeeper and a receiving
Mac remain **NOT_RUN**. Online audit is **BLOCKED** under the existing deferral.
The build 32 user acceptance below remains tied to that exact development app.
See [beta.11 release verification](../releases/v0.8.0-beta.11.md).

## Gesture expansion — 2026-10-25

Status: **SOURCE_CHECKS_PASS; P16KT_ACCEPTANCE_PASS_USER_REPORTED_ON_THIS_MAC; FINAL_STOP_CONFIRMED**. The source is based on
`6e82833` with then-uncommitted gesture changes, later committed as `f386a89`.
At this development checkpoint, public beta.10/build 28 was unchanged.

| Check | Result and boundary |
| --- | --- |
| `bash scripts/test.sh` in a normal host context | **PASS**, 30 Platform + 19 Core tests, including after the arrow-flags and modifier-release fixes; includes App compilation |
| `git diff --check` | **PASS**, final source and documentation changes |
| Same suite under the restricted executor | **FAIL**, keyboard event-source creation returned nil; the system service was inaccessible. The unchanged suite passed outside that restriction |
| Pinch event construction → `NSEvent` conversion | **PASS** on macOS 26.7.1/arm64, Swift 6.4; began/changed/ended/cancelled, positive and negative changes; no global events posted |
| `bash scripts/build-app.sh` | **PASS**, one local ad hoc candidate, beta.10/build 29; not a release or installation |
| `codesign --verify --deep --strict 'dist/Touch Me.app'` | **PASS**, local artifact only |
| Candidate UI | Pinch toggle, guidance and counters observed in the existing settings layout. Ad hoc build 29 required permissions; certificate-signed builds 30–32 show both **Allowed** |
| Approved certificate-signed candidates | **PASS**, existing bundler created builds 30–32; strict signature and installed certificate requirement passed in the native host |
| Existing `--scan` from the host process | **PASS**, metadata only/no open: one `0x0457:0x0819` panel, verified grouping, eligible descriptor with five digitizer finger slots; three eligible external displays |
| Safari pinch effect | **PASS_USER_REPORTED** on build 32: continuous in/out, repeated gestures and stop/lift behavior normal, without unintended click/scroll. Earlier synthetic probe was blocked before posting |
| Preview PDF pinch effect | **PASS_USER_REPORTED** on build 32: continuous in/out, repeated gestures and stop/lift behavior normal, without unintended click/scroll |
| Preview image pinch effect | **PASS_USER_REPORTED** on build 32: continuous in/out, repeated gestures and stop/lift behavior normal |
| Chrome pinch effect | **PASS_USER_REPORTED** on build 32: continuous in/out, repeated gestures and stop/lift behavior normal, without unintended click/scroll |
| P16KT target / Start | **PASS_USER_REPORTED** for the test window on the physical P16KT; candidate GUI then showed mapping running in multitouch mode |
| Existing P16KT tap/double-tap/drag/scroll | **PASS_USER_REPORTED** on build 30; no unintended click or magnification during scrolling |
| P16KT three-finger up/left/right | **PASS_USER_REPORTED** on build 32, including repeated strokes without an intervening mouse click; earlier failures are retained below |
| First/last Space and reverse return | **PASS_USER_REPORTED** on build 32, both boundaries stop without wrapping and the reverse gesture works after lift |
| Stop during P16KT pinch / restart | **PASS_USER_REPORTED** on build 32: Stop ends zoom; after full lift and Start, fresh pinch/tap/scroll work without unwanted zoom/click |
| Lock during P16KT pinch / unlock | **PASS_USER_REPORTED** on build 32: automatic resume and fresh pinch/tap/scroll work without unwanted zoom/click |
| USB interruption during P16KT pinch | **PASS_USER_REPORTED** on build 32: automatic resume after reconnecting to the same port; fresh pinch/tap/scroll/three-finger switching work without unwanted zoom/click |
| Multiple-display targeting / final Stop | **PASS_USER_REPORTED** on build 32 in the current four-display layout: click, pinch and Space switching target the P16KT; final Stop is normal. GUI independently shows Stopped, Start available and Stop disabled, without a recovery error |
| Homebrew / release / installed upgrade | **NOT_RUN**, outside scope |

Initial ad hoc build 29 executable SHA-256:
`841b971ae3f60d88742bbb161dc273121db9de15d7ea32323676cab929b15c8f`.
The observed UI was tied to host PID `11877`, running the candidate at
`dist/Touch Me.app/Contents/MacOS/TouchMe` with that exact executable hash.
Mapping remained stopped with zero received values and posted events; no privacy
permission was changed during this observation.
The subsequent Input Monitoring inspection showed one enabled `Touch Me` row;
its Finder action resolved to the local candidate, but the candidate still reported
both permissions missing after Refresh. That row did not establish separate
authorization for the installed and local apps. Both bundles use the same bundle
identifier; the installed designated requirement pins the permanent certificate,
while build 29 uses an ad hoc code hash. No row was added, removed or toggled.
The user then approved signing only the candidate with the existing permanent
certificate. The existing bundler produced build 30 after native authorization,
preserving build 29. Build 30 PID `13806` runs from the same `dist` path with
executable SHA-256
`3a19ece61200592aee9a30524437c4a294601f87e684ba62acfcbe2c89e1cb74`.
Its GUI shows both Input Monitoring and Accessibility **Allowed**, the verified
USB device and `ZEUSLAP-TYPEC` target. No privacy row or trust setting was changed
by the agent. The user confirmed the screen 4 test window was on the physical
P16KT. The agent applied that confirmation and selected Start. The candidate GUI
showed mapping running in multitouch mode with zero received/posted values at the
start checkpoint. This establishes readiness, not gesture acceptance.
After the user's gesture checks, the GUI reported 23,376 received values,
38 mouse downs, maximum contact count 4, 974 scroll events, 224 pinch events and
8 system commands. Those counters show that some gestures reached posting; they
do not contradict the user's report that all three-finger actions failed.
Read-only System Settings inspection confirmed enabled Control-Up, Control-Left
and Control-Right shortcuts. Display 4 matched the P16KT UUID and had three Spaces
in the saved display configuration. No shortcuts or Spaces were changed. Physical
keyboard comparison subsequently **PASS_USER_REPORTED** for all three shortcuts
with the pointer on the P16KT. Mapping was stopped normally before diagnostic
posts. Temporary helpers isolated the keyboard output from HID recognition:

| Control-Up diagnostic | Observed effect |
| --- | --- |
| Original immediate key pair | **FAIL_USER_REPORTED**, no change |
| Same pair held for 100 ms | **FAIL_USER_REPORTED**, no change |
| Private source retained through delivery | **FAIL_USER_REPORTED**, no change; a listen-only session tap received the uniquely tagged down/up pair with Control present |
| Explicit Control down/up around the arrow | **FAIL_USER_REPORTED**, no change |
| Original pair with native arrow flags restored | **PASS_USER_REPORTED**, Mission Control opened |

Non-posting inspection showed that CoreGraphics creates arrow events with
`numericPad` and `secondaryFn`. Assigning Control alone discarded those flags.
The successful comparison restored only these two flags, retaining the original
source lifetime and immediate posting. The source fix inserts Control into the
existing flags; its regression test requires the arrow flags on both key events.
Build 31 added no delay, extra modifier events or persistent source. Helpers guard
posting permission and held physical inputs; no shortcut settings or repository
test infrastructure were changed. At that checkpoint, the diagnostic PASS did
not establish three-finger acceptance in the corrected app candidate.

Corrected build 31 was signed with the same approved certificate after the
49-test suite and App compilation passed. Its executable SHA-256 is
`7a6a71da832bc036fef95c8401f39f0b810b8af3e494181a8ac1d151bff6b0c8`.
Native PID `16986` was confirmed at the exact `dist` executable path.
Build 30 quit normally before replacement and remains in the existing local
history folder. Build 31 opened with both permissions Allowed and the confirmed
P16KT target intact; Start succeeded in multitouch mode. The user reported that
all three directions now execute, but another stroke fails until a mouse click.
The first/last Space check was not run. At Stop, the GUI showed 19,127 received
values, 43 downs, maximum contacts 4, 112 scroll events, 14 pinch events and
14 system commands.

A bounded native probe reproduced the repeat blocker without a mouse click:
before the arrow pair, HID flags were `0x20000000` with no modifier key down;
afterward, flags were `0x20a40000` and Control key 59 appeared down. Explicit
Control release restored `0x20000000` and Control-up state. The existing physical
input guard therefore rejected the next stroke because of the app's own
synthesized modifier state. The source now prepares Control-down, arrow-down,
arrow-up and Control-up before posting, while preserving the arrow flags. A
native probe of this corrected sequence ended with `0x20000000` and no modifier
keys down before any cleanup event. The adapter regression checks both modifier
events and two consecutive commands through a stateful recording sink. Physical
consecutive-stroke acceptance was deferred to build 32 below.

Build 32 contains the modifier-release fix. The 49-test suite, App compilation,
strict signature and certificate requirement passed. Its executable SHA-256 is
`d63b1fd037fbaa78ef3822779609fbb11cb760eb916d6724cad6a0b6573884bf`.
Native PID `17994` was confirmed at the exact `dist` executable path.
Build 31 quit normally and was preserved before build 32 opened with both
permissions Allowed and the P16KT target still confirmed. Mapping restarted in
multitouch mode. The user confirmed consecutive left/right strokes without mouse
clicks and repeated Mission Control opening after closing it with Esc. Both Space
boundaries and reverse-direction return after lift were also confirmed normal
(**PASS_USER_REPORTED**). These results cover build 32 on this P16KT/Mac setup.
Safari's existing local pinch fixture was separated into its own window and moved
to `ZEUSLAP-TYPEC`; its initial `visualViewport.scale` is 1.000. The user confirmed
normal continuous zoom in/out, repetition, stop/lift and no unwanted click/scroll
(**PASS_USER_REPORTED**, Safari 27.0). The previous Safari Start Page window was
preserved. Preview's one-page temporary PDF and the existing PNG were opened in
separate windows and placed on the left/right of the P16KT. The user confirmed
normal zoom in/out, repetition and stop/lift for both PDF and image
(**PASS_USER_REPORTED**, Preview 11.0). Only view placement was changed; document
content was not edited. Chrome's browser tool rejected the local file URL. The
test instead uses the public static `https://example.com` page in its own window
on the P16KT; local file access was not bypassed. The user confirmed continuous
zoom in/out, repetition, stop/lift and no unintended click/scroll
(**PASS_USER_REPORTED**, Chrome 156.0.8078.48). All required app pinch checks now
pass on this Mac with build 32. The user then stopped mapping with fingers still
touching during pinch and confirmed that zoom stopped. After full lift and Start,
fresh pinch/tap/scroll worked without unwanted zoom/click (**PASS_USER_REPORTED**).
The candidate GUI was subsequently observed running again. The user then locked
the Mac while still touching during pinch, lifted all fingers and unlocked it.
Automatic resume and fresh pinch/tap/scroll were confirmed normal without unwanted
zoom/click (**PASS_USER_REPORTED**); the GUI was again observed running with both
permissions Allowed. The user then disconnected USB during pinch, lifted all
fingers and reconnected to the same port. Automatic resume and fresh
pinch/tap/scroll/three-finger switching were confirmed normal without unwanted
zoom/click (**PASS_USER_REPORTED**). The GUI again showed mapping running on
`ZEUSLAP-TYPEC`, screen 4, with both permissions Allowed. Final file inspection
confirmed the same build 32 executable hash and the unchanged installed build 28.
The user confirmed that click, pinch and Space switching apply to the P16KT in
the current multiple-display layout without affecting the wrong screen, then
stopped mapping normally (**PASS_USER_REPORTED**). Final GUI inspection showed
Stopped, Start enabled, Stop disabled, both permissions Allowed and no recovery
error. The agent closed only the test Chrome tab, Safari fixture window and two
Preview fixture windows; the original Safari window and other browser tabs were
preserved. The candidate remains open with mapping stopped.

The candidate and installed designated requirements match: bundle identifier plus
certificate SHA-1 `e7491a0b49d0784093d48b2bb30b298df3a924f9`.
The initial explicit requirement check used incorrect `codesign -R` argument
syntax; the corrected check returned `CSSMERR_TP_NOT_TRUSTED` in the restricted
executor, then passed unchanged in the native host for both bundles. No trust
exception was added. The unchanged Swift suite was not repeated for re-signing.
Installed build 28 remains byte-identical at executable SHA-256
`3107bb4b44cc64f730591e454566c4cbd4ff7108c4cd1ad364543297ec531482`.
The build script preserved the previous local bundle in its existing history folder.
Linker warnings about missing CommandLineTools search directories remain visible;
they did not prevent compilation or the passing host test run.

Core tests exercise threshold arbitration, a stationary finger during pinch,
staggered three-finger acquisition, slot identity replacement, reversed contact
order, no multi-touch clicks, one-shot switching, cancellation, restart, disabled
pinch and degenerate geometry. The HID regression checks off/on within one report.
The new Platform tests inspect actual event fields and key pairs through a recording
sink, including preparation failure and cancellation after allocation failure.
No tests synthesize global input or change privacy/shortcut settings.

Acceptance procedure uses the exact candidate, with all fingers lifted between
gestures. The table above records the results on this Mac:

1. Preserve the installed app and its permission entries. Resolve candidate-only
   permissions; do not overwrite an existing permission or trust setting to continue.
   Confirm the test window physically appears on the P16KT before Start.
2. Check tap/double-click, one-finger drag and two-finger vertical/horizontal scroll;
   scrolling must not click or zoom, and pinch must not click or scroll.
3. Check continuous zoom in/out in Safari and Chrome web content and Preview PDF
   and image content. Stop moving and lift: no further zoom may be emitted.
4. Check three-finger up and both horizontal directions. Each stroke executes
   once. Check the first/last Space and targeting in the connected display layout.
5. Check Stop, lock and USB interruption during pinch. After the existing recovery
   path, no input remains held and a fresh gesture requires full lift. Stop
   normally and confirm safe device cleanup.

Additional physical variants remain **NOT_RUN**: a negative-origin P16KT layout,
deliberate contact replacement/addition and interruption during an established
drag. Core tests cover these relevant state transitions and negative coordinates;
those tests are not hardware acceptance. The current P16KT bounds are
`(2056, 0, 1280, 800)` in a four-display setup. Display arrangement was not changed.

Tested app versions: Safari 27.0, Preview 11.0, Chrome 156.0.8078.48. App behavior
is established by the user observations above, not version inventory alone.
Event creation, posted counters and HID descriptor slots do not establish app
behavior or physical finger tracking. Required-app failures block completion;
there is no automatic shortcut fallback. Preferences and release history are not
rewritten to turn a blocked test into a pass.

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
