# Mapping lifecycle policy

Ticket: TMQA-002. The development source preserves mapping intent across
temporary lock, sleep and user-session interruptions. This change is not in
the published beta.2 app.

| Event | Release input and restore device | Saved resume intent | Next action |
| --- | --- | --- | --- |
| Explicit Stop | Yes | Clear | Manual Start after safety conditions pass |
| Screen lock, sleep or inactive user session | Yes | Preserve | Guarded resume after all interruption conditions clear |
| Display configuration change during suspension or recovery | Already released | Preserve | Recheck the saved target after one quiet second |
| Target error within a confirmed interruption's recovery window | Yes | Preserve | Recheck the original device and display configuration before retrying |
| Display validation failure before an interruption is confirmed | Yes | Pending for at most two seconds | Preserve only if a public interruption signal is observed; otherwise clear and require manual Start |
| Independent display configuration change while active | Yes | Clear after classification | Refresh, verify target, manual Start |
| Recovery not ready within ten seconds | Already released | Clear | Check setup, manual Start |
| Mapper failure | Yes | Clear | Resolve failure and verify target |
| Normal Quit | Yes | Preserve existing value | Resume only if saved target, USB location and permissions match |
| Retry after failed Quit restoration | Retry | Preserve existing value | Do not report success until restoration succeeds |

Only running mapping or an existing valid pending resume creates deferred intent.
Explicit Stop, target selection changes and confirmation cancellation cancel it.
Normal Quit preserves the saved value and cancels in-process recovery. Quit cannot
restore an intent already cleared by Stop, a mapping error or recovery timeout.

## Recovery guards

The app samples public `NSApplication.isProtectedDataAvailable`, the documented
console/login keys from `CGSessionCopyCurrentDictionary`, and
`CGDisplayIsAsleep` for the exact online display UUID. Missing session state blocks
Start. An unavailable display-power query preserves a previously confirmed sleep
guard; it does not prove wake. Public Mac/screen wake events clear their own guard
and recheck display power together. Other guards remain in force. Separate sleep,
display-sleep and inactive-session guards prevent one notification from clearing
another interruption. Duplicate events do not reset the deadline.

Availability polling normally uses the existing one-second timer in common
run-loop modes. During an interruption resume or the two-second classification,
a 0.25-second timer samples availability. A scoped
`userInitiatedAllowingIdleSystemSleep` activity prevents App Nap from deferring
this work, as described in [Apple's activity guidance](https://developer.apple.com/library/archive/documentation/Performance/Conceptual/power_efficiency_guidelines_osx/PrioritizeWorkAtTheAppLevel.html).
Mac idle sleep remains allowed. Confirmed system sleep or inactive-session events
suspend this monitoring until their public return events arrive. The activity is
retained through an automatic Start and ends on completion, cancellation,
restoration failure, timeout or Quit. Ordinary startup/permission waiting does
not create it. HID scans and readiness retries retain their one-second cadence;
fast polling does not repeat device I/O four times per second.
The mapper's watchdog and input flush also ask the model to sample availability
before their permission/display checks. When that sample detects an interruption,
the model releases mapping and those checks return if mapping has stopped.
Cleanup mouse-up events always remain allowed. Other mapper failures still
cancel resume.

Display identity is checked by a unique persistent UUID and unchanged bounds,
built-in, rotation and mirroring state. An unchanged target with a new temporary
display ID continues mapping with the refreshed ID. Both the display watchdog and
screen-configuration callback release input before classifying an invalid target.
If no interruption is confirmed yet, they retain the actual previous target for
at most two seconds using the existing timer. This pending classification cannot
start mapping or refresh into an automatic Start. Only a public interruption
signal observed before expiration promotes it to the existing guarded recovery.
Expiration, explicit Stop, selection change, Quit or restoration error cancels
it. A display change alone never authorizes automatic resume.

After all guards clear, recovery waits one quiet second, then refreshes the exact
saved USB location and display UUID. Readiness queries retry once per second for
at most ten seconds. A successful start uses fresh device handles and display
geometry. A context captured from the active mapper before a confirmed interruption
preserves the original display configuration and saved device. Its fixed deadline
remains after a successful automatic Start. A target-change error or display
notification within that window releases mapping and schedules another readiness
check without extending the deadline. Both the model's scan and the mapper's final
fresh scan must match the original UUID, bounds, built-in, rotation and mirroring
state. USB location, VID/PID and supported descriptors must still match the saved
device. Initial application state without an active mapping target does not create
this context.

The ten-second window bounds readiness retries before starting. It does not
interrupt a native device call already in progress. Synchronous feature-report
reads and writes in `P16KTDeviceMode` may block the main thread until the device
responds. Recovery phase and elapsed-time messages in OSLog category
`MappingRecovery` distinguish a delayed retry from a delayed scan, device open,
mode read/write or contact initialization. They contain no device identifiers,
session data or touch values. App Nap prevention does not guarantee shorter
native device response times.

Input and removal callbacks check that their sender is one of the mapper's
currently opened devices and that mapping is running. Failure callbacks sample
public availability before reporting a terminal error. Cleanup unregisters each
callback with its original registration context, matching the [Apple IOKitUser
implementation](https://github.com/apple-oss-distributions/IOKitUser/blob/main/hid.subproj/IOHIDDevice.c#L1819-L1833).
Display validation and device removal retain separate error origins and messages,
with the existing `target_changed` code. Other start or mode-restoration errors
stop retries; restoration errors remain visible and require manual Retry restore.
Stop, target selection changes, confirmation cancellation, termination and terminal
errors clear the recovery context. New interruptions begin a new recovery window
after return.

## Verification

On 2026-10-08 (Asia/Seoul), a separate temporary GUI observer used only public APIs
and did not open HID devices. The user performed Control-Command-Q and unlocked
while it was running. The property was true before lock, false at elapsed 29.553,
30.803 and 35.804 seconds, and true again at 38.303 seconds after unlock. No
workspace session or protected-data delegate callback occurred in that cycle;
property polling is required. Console/login values stayed true.

This confirms the signal on that Mac running macOS 26.7.1, not on every macOS 26
version. An earlier observer run ended before its overlap with the user's action
could be confirmed and is excluded from the verdict. The user subsequently
confirmed automatic recovery after one lock/unlock cycle in build 13 without
manual action, including one-finger operation. A subsequent timed cycle failed:
touch did not recover for at least one minute, and the app displayed
`target_changed`. Build 13 has not passed the lock/unlock acceptance check.
Actual HID release/restoration remains NOT_CONFIRMED; sleep/wake verification
remains NOT_RUN.

The first local candidate was build 13 with unchanged release metadata
`0.8.0-beta.2`. One `bash scripts/build-app.sh` run passed release compilation
with warnings as errors and strict ad hoc signature verification. The existing
`bash scripts/test.sh` run passed all 14 logic tests; no tests were added. Existing
Command Line Tools linker search-path warnings were non-fatal. These results
do not establish device restoration or automatic mapping recovery. The installed
build 12 app has not been replaced.

The initial native candidate check encountered a user-reported permission status
issue. A process-path check then found only the installed build 12 running, so
that UI report did not establish build 13's permission state. The two apps have
the same bundle ID but different ad hoc code requirements; an approval mismatch
was a possible cause, not a confirmed TCC diagnosis. After receiving the candidate
path, the user initially reported normal operation. A subsequent process-path
check confirmed that the running app was `dist/Touch Me.app`, build 13. The user
then reported that after lock/unlock, touch behaved as if the app were not
running. The initial report alone was therefore not an acceptance result. In a
later report, the user described normal
touch operation with increasing counters: 2,749 received values, zero posted
downs, two maximum contacts and 765 posted scrolls. The message was "Multitouch
is active." These counters show input processing and scroll-post calls, not
event-delivery confirmation. The user then confirmed that normal touch returned
without restarting, Refresh or Start, and that one-finger operation also worked.
The subsequent measurement reported no recovery for at least one minute and the
message "The selected touch device or display changed" (`target_changed`). That
build's error cancelled saved resume intent. It could originate from the HID removal
callback or the display watchdog; the shared error code does not distinguish
them. This repeated failure overrides the earlier successful cycle as the
acceptance result. No further source change or rebuild was made in response to
the counters. The agent did not change permission settings or read TCC records.

The user then approved the bounded target-error recovery exception and confirmed
normal Quit before rebuilding. Release compilation and strict ad hoc signature
verification passed for build 14. The final source review found that callback
cleanup used a different context from registration; after correcting that
cleanup, one further build produced build 15 and passed the same checks. Build 14
was not launched. The existing build script preserved both earlier candidates.
The latest candidate remains at `dist/Touch Me.app`, with unchanged release
metadata `0.8.0-beta.2`.

The known non-fatal Command Line Tools linker search-path warnings appeared in
both builds. Core gesture logic was unchanged, so the existing logic suite was
not rerun and no tests or diagnostic infrastructure were added. Source review
covered fixed deadlines, same-configuration revalidation, callback ownership and
Stop/error/termination cancellation. Build 15's subsequent user-performed cycle
failed with "The target display changed or is unavailable" (`target_changed`).
The separate origin confirms a display-validation failure, but does not establish
its exact ordering relative to public interruption signals or the recovery
deadline. Build 15 has not passed lock/unlock acceptance. Sleep/wake remains
NOT_RUN. The agent has not replaced the installed app.
After confirming no Touch Me or other mapper process was running, the agent opened
the local build 15 candidate for the next user-performed check. This launch is not
permission or physical-mapping verification.

After the repeated display-validation failure, the development source was updated
to match a unique persistent display UUID, query public display-power state and
classify early display errors for at most two seconds. Read-only review covered
both watchdog and screen-notification paths, unknown power state, wake ordering,
pending expiration, fixed recovery deadlines and user cancellation. The release
`swift build` command from `scripts/build-app.sh`, with warnings as errors, passed.
The known linker search-path warnings remained non-fatal. No tests or probes were
added. After the user confirmed normal Quit and a process check found no active
mapper, `python3 scripts/bundle-app.py .build/out/Products/Release/TouchMe`
produced build 16 and passed strict ad hoc signature verification. The existing
candidate was preserved by the bundle script. Release metadata remains
`0.8.0-beta.2`, and the installed app remains build 12. The agent launched the
local build 16 candidate and confirmed its process path. The user subsequently
confirmed normal recovery after lock/unlock, then reported that mapping resumed
only after approximately thirty seconds. During that wait, the message was
"Checking the saved device and display. Mapping will resume when they are ready."
The duration was user-reported, not instrumented. This confirms functional
recovery for that cycle, with unacceptable latency. Sleep/wake verification of
build 16 remains NOT_RUN.

The subsequent source revision adds scoped recovery activity, faster availability
polling and phase timing logs. No private unlock signal, new dependency, test or
probe was introduced. The cause of the thirty-second delay is not established:
App Nap and synchronous device calls remain candidates. Physical latency
verification of this revision remains NOT_RUN. Release compilation with warnings
as errors passed; the known non-fatal linker search-path warnings remained.
Review covered activity lifetime through automatic Start, pending cancellation,
sleep/session suspension and the unchanged retry cadence. After the user confirmed
normal Quit of build 16 and no mapper process was running, the existing bundle
script produced build 17 and passed strict ad hoc signature verification. The
agent launched that local candidate and confirmed its process path. The installed
app remains build 12. A five-minute OSLog stream filtered only to the app's
`MappingRecovery` category was started for one user-performed cycle; starting it
does not establish a latency result.

On an approved native test setup, run the following separately:

1. Start -> lock -> unlock: release/restore, resume the same target automatically.
2. Start -> lock -> sleep -> wake while locked -> unlock: do not resume before unlock.
   Reversing the unlock/wake order must also wait for both guards to clear.
3. Explicit Stop -> lock/unlock: remain stopped. Stop or target change during
   pending recovery must prevent a later timer or Refresh from starting mapping.
4. Start -> independent display change: stopped, refreshed target, target confirmation required
   when the saved display is no longer eligible.
5. Returning without the saved target or permissions: no unverified Start, give up
   after ten seconds, and keep manual recovery available.
6. Start -> normal Quit -> relaunch: saved true remains eligible for guarded resume.
7. Explicit Stop -> Quit -> relaunch: remains stopped.
8. Restore failure during interruption: recovery error remains visible; Start blocked.
9. Full logout/login: record notification order and verify launch separately from
   mapping. Do not assume every logout has the same notification ordering.

The [build 11 native checklist](build-11-release-checklist.md) retains that build's
historical expectations and NOT_RUN statuses. It is not evidence for the new
recovery behavior. Do not inject device faults or replace the installed app
without an approved native setup.
