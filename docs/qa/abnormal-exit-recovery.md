# Abnormal exit recovery boundary

Ticket: TMQA-003. Status: hardware premise UNTESTED; investigation and documentation
provided, runtime recovery remains open. This change does not write new feature
values or add a recovery journal based on an unverified device assumption.

## What the source establishes

`P16KTDeviceMode` retains originalMode, originalIdentifier and needsRestore in
memory. For a verified original mode 0, enable marks recovery pending before
writing mode 2. An initial mode 2 is accepted and left unchanged. Normal Stop or
Quit restores only when the current process owns a pending change.

A crash, SIGKILL, or power loss can skip that cleanup. If the panel remains at
mode 2, a new process cannot distinguish its predecessor's change from a device
that legitimately started in mode 2. A later Stop does not establish restoration
of a value known only to the previous process. Whether that premise occurs on
actual P16KT hardware has not been established by cloud QA.

## Current user guidance

Use Stop and normal Quit. Preserve restoration errors. Do not continue an upgrade
or removal while a known recovery failure is unresolved. Same-port reconnect and
Retry are for a recovery state the running process still holds; they are not a
promised cross-crash restoration mechanism. Do not force mode 0 on an arbitrary
panel or treat process disappearance as successful restoration.

## Verification plan before a runtime change

First use an injected feature-I/O backend, not a physical-device crash:

| Case | Required result |
| --- | --- |
| Original 0 -> enable -> normal restore | Write 2 then restore 0 with matching readback |
| Original 2 -> enable -> normal restore | No unnecessary mode write |
| Write error after partial change | Pending recovery retained until verified |
| Readback mismatch | Start fails; restoration failure remains visible |
| Process state lost, device mock remains 2 | Demonstrate lost predecessor state without pretending it was recovered |
| Different location/descriptor/device | No recovery write to unverified replacement |
| Stale or malformed recovery record | No guessed mode write |

Then, only on an approved controlled native setup, measure owner exit and device
reconnect behavior. Record the before/after mode, identifier, connection, build,
termination condition, and successful recovery method. Do not run forced-crash
hardware tests as part of the ordinary packaging or Swift test command.

## Decision gate

If hardware reliably resets, document the exact verified conditions and residual
limits. If it can retain mode changes, design a minimal journal only after those
results are known. A journal must be written before a change, survive partial
writes, bind to a verified physical device, and be removed only after readback
proves recovery. A stale journal or reused USB port must not authorize writes to
a different unit. Do not choose mode 0 merely because it is common.

Acceptance requires approved backend fault tests and native evidence for the
selected policy. Documentation alone does not close the runtime risk. Track the
native checks in [the release checklist](build-11-release-checklist.md).

## 2026-10-09 disposition (TMQA-003)

**BLOCKED — not resolved by the macOS QA fix branch.** This cloud executor has no
macOS/P16KT device access, and the user's Mac is outside the authorized scope.
`DeviceModeTransaction` now exposes the existing mode ownership logic to injected
I/O (TMQA-005). Its process-loss case explicitly preserves the limit: a new owner
observing mode 2 does not know whether a predecessor changed it from 0. Adding a
journal without a verified identity/reset policy would turn that uncertainty
into potentially incorrect writes to a replacement panel on a reused USB port.
No journal, guessed reset, or cross-process feature write is introduced.

To unblock: use a separately authorized controlled Apple Silicon/macOS 26+
setup and one identified P16KT on a recorded USB-C connection. Record original
mode/identifier, normal restoration, then (only with explicit fault-test
approval) whether a process crash and a panel power cycle retain or reset the
mode. Record both original-0 and original-2 cases, device identity across
re-enumeration, and whether swapping a unit on the same port is distinguishable.
Choose the reset procedure or identity-bound journal only from those results.
The existing runtime risk remains open until that policy and native acceptance
are verified. Passing an injected-I/O test cannot close this ticket.
