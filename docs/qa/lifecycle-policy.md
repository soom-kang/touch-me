# Mapping lifecycle policy

Ticket: TMQA-002. This clarifies and preserves the current fail-closed behavior;
it does not add automatic wake or session-return mapping.

| Event | Release input and restore device | Saved resume intent | Next action |
| --- | --- | --- | --- |
| Explicit Stop | Yes | Clear | Manual Start after safety conditions pass |
| Sleep or inactive user session | Yes | Clear | Manual Start after returning |
| Display configuration change | Yes | Clear | Refresh, verify target, manual Start |
| Mapper failure | Yes | Clear | Resolve failure and verify target |
| Normal Quit | Yes | Preserve existing value | Resume only if saved target, USB location and permissions match |
| Retry after failed Quit restoration | Retry | Preserve existing value | Do not report success until restoration succeeds |

System interruptions are not evidence that the user pressed Stop, but both
intentionally leave mapping stopped. The UI now explains system interruption
instead of using the generic stop message. A restore error takes precedence over
that informational message. Display changes still refresh device/display state.
Normal Quit cannot restore resume intent already cleared by an earlier event.

## Verification

Cloud source review confirms both environment observer paths use
`stopForEnvironmentChange`, which calls the existing stop path and changes only
the successful-stop message. Failed restoration retains its error. The two
languages document the same policy. Native execution is NOT_RUN.

On an approved native test setup, run the following separately:

1. Start -> sleep -> wake: input released, saved resume false, manual Start needed.
2. Start -> inactive session -> return: same result; record actual notifications.
3. Start -> display change: stopped, refreshed target, target confirmation required
   when the saved display is no longer eligible.
4. Start -> normal Quit -> relaunch: saved true remains eligible for guarded resume.
5. Explicit Stop -> Quit -> relaunch: remains stopped.
6. Restore failure during interruption: recovery error remains visible; Start blocked.
7. Full logout/login: record notification order and verify launch separately from
   mapping. Do not assume every logout has the same notification ordering.

Actual OS/device outcomes remain tracked in [build 11 native checks](build-11-release-checklist.md).
A future decision to preserve intent across system interruptions is a behavior
change and requires independent safety and native regression evidence.
