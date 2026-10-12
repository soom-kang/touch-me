# Touch Me QA fault evidence — 2026-10-12

[QA report](2026-10-12-qa-report.md) · source `65a8e71e5825bb8caca2357a713ef4d80c1b092a`

## Post-fix validation

TMQA-006/007은 현재 수정한 checkout에서 source-level 검증을 통과했습니다.
`bash scripts/test.sh`는 38개, `python3 -m unittest discover -s Tests/PackagingTests -v`는
22개를 각각 한 번 실행해 PASS입니다. 새 regression은 기존 test target과 fixture에만
추가했으며 명령, 합의와 실행 한계는 [보고서](2026-10-12-qa-report.md)에 기록합니다.

아래 명령과 출력은 **수정 전 baseline `65a8e71`의 재현 기록**입니다. 특히 journal
예시는 당시의 no-record 분기를 복사하므로 수정된 production 경로의 검증에 사용하지
않습니다. 수정 후의 판정에는 실제 `confirmNoActiveRecord()`와 packaging script를
실행하는 기존 suite를 사용합니다. 과거 실패 결과는 보존하며 새 native acceptance로
바꾸지 않습니다. 이후 [로컬 native build](2026-10-12-native-build.md)의 산출물 검사를
통과했으며 이때도 fault suite를 재실행하거나 GUI/장치 복구를 실행하지 않았습니다.

이 문서는 실행한 두 local fault check의 입력, 명령과 결과를 보존합니다.
아래 예시는 재현용 임시 경로를 생성하며 설치 앱, repository `dist`, 실제 recovery
records와 HID 장치를 사용하지 않습니다. 새로운 test runner나 repository 실행 파일을
추가하지 않았습니다. Native app 전체 경로의 관측 결과는 아닙니다.

Journal의 원래 실행은 `/private/tmp/touch-me-qa-20261012-journal-check`를 사용했습니다.
아래 명령은 같은 production source와 보존한 harness를 새 임시 경로에서 실행할 수
있도록 경로 생성만 바꿨습니다. 이 문서 안의 재현 명령도 2026-10-12에 실행해
같은 결과를 확인했습니다. 검증용 임시 파일은 제품 산출물이 아닙니다.

## Packaging check

Observed on 2026-10-12 (Asia/Seoul), source HEAD `65a8e71`.
Scope: existing `PackagingTests` fixture, temporary copies only. Native tools are
mocked; the fixture binary and images are intentionally invalid. This establishes
the Python output-file sequence, not native DMG or app behavior.

Run from `/Users/soom.kang/Desktop/work/2.services/touch-me`:

```bash
python3 - <<'PY'
import hashlib
import importlib.util
import pathlib
from unittest.mock import patch

path = pathlib.Path('Tests/PackagingTests/test_packaging.py').resolve()
spec = importlib.util.spec_from_file_location('touchme_packaging_fixture', path)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
case = module.PackagingTests()
case.setUp()
try:
    case.bundle()
    case.run_script('package-dmg.py')
    image = next((case.root / 'dist').glob('*.dmg'))
    sidecar = image.with_suffix('.dmg.sha256')
    old_image = image.read_bytes()
    old_sidecar = sidecar.read_text()
    original_write = pathlib.Path.write_text
    def denied_checksum(path, *args, **kwargs):
        if path == sidecar:
            raise PermissionError('fixture: checksum sidecar denied')
        return original_write(path, *args, **kwargs)
    def replacement_image(command, **kwargs):
        result = case.native(command, **kwargs)
        if command[0] == 'hdiutil':
            pathlib.Path(command[-1]).write_bytes(b'NOT a DMG: second fixture version')
        return result
    try:
        with patch.object(pathlib.Path, 'write_text', denied_checksum):
            case.run_script('package-dmg.py', native=replacement_image)
    except PermissionError:
        print('EXPECTED_FAILURE: checksum sidecar write rejected')
    print('ACTIVE_IMAGE_PRESERVED:', image.read_bytes() == old_image)
    print('ACTIVE_SIDECAR_PRESERVED:', sidecar.read_text() == old_sidecar)
    print('ACTIVE_PAIR_MATCHES:', sidecar.read_text().split()[0] == hashlib.sha256(image.read_bytes()).hexdigest())
    archived = list((case.root / 'dist' / 'previous-builds').glob('*.dmg'))
    print('PREVIOUS_IMAGE_ARCHIVED:', len(archived) == 1 and archived[0].read_bytes() == old_image)
    print('ARCHIVED_MATCHING_SIDECARS:', len(list((case.root / 'dist' / 'previous-builds').glob('*.dmg.sha256'))))
finally:
    case.doCleanups()
PY
```

Actual output; shell exit `0` because the expected error is caught:

```text
EXPECTED_FAILURE: checksum sidecar write rejected
ACTIVE_IMAGE_PRESERVED: False
ACTIVE_SIDECAR_PRESERVED: True
ACTIVE_PAIR_MATCHES: False
PREVIOUS_IMAGE_ARCHIVED: True
ARCHIVED_MATCHING_SIDECARS: 0
```

Source: `scripts/package-dmg.py:144-154`. The old output is renamed, the new image
becomes the final output, then the hash is read and the final checksum is written.
A sidecar permission failure leaves the old checksum beside the new image.
Existing coverage at `Tests/PackagingTests/test_packaging.py:200-211` injects an
earlier `hdiutil` failure only.

Suggested P2 ticket: stage the new DMG and its verified sidecar before promoting
the pair. Any finalization failure must preserve or clearly recover the previous
complete pair; archived output must retain its associated digest. Extend the
existing test module with this focused failure boundary when implementing a fix.

## Journal check

Source: `65a8e71e5825bb8caca2357a713ef4d80c1b092a`, unchanged production files
`Sources/TouchMePlatform/DeviceModeTransaction.swift` and
`Sources/TouchMePlatform/DeviceModeRecoveryJournal.swift`.

### Scope

The equivalent check uses the production journal's supplied-owner,
ownerLookup and directorySync seams. All identity, mode and process inputs are
synthetic. No HID device, mode feature report, GUI or app process is opened or
changed. The temporary main.swift stubs only the three ProofError cases referenced
by DeviceModeTransaction and compiles the actual production journal/transaction.
It repeats ProofMapper.restorePreviousMode's no-record branch; it does not execute
the native P16KTDeviceMode or the AppKit model.

### Reproduction

1. An old owner persists original `(0,0)` and closes the lease.
2. A new owner, with the predecessor lookup returning nil, authorizes recovery
   from injected current `(2,0)`.
3. Original-pair readback is represented by injected `(0,0)`.
4. `removeAfterReadback` unlinks the old record, then injected directorySync fails.
5. The retained journal can still authorize `.alreadyOriginal` for the exact
   pending record, but `hasOwnedActiveRecord` is false.
6. Closing/reacquiring the journal loses pendingRemoval. The production no-record
   branch returns success without calling directorySync.

```bash
cd /Users/soom.kang/Desktop/work/2.services/touch-me
TASK_QA_TMP="$(mktemp -d /private/tmp/touch-me-qa-XXXXXX)"
cat > "$TASK_QA_TMP/main.swift" <<'SWIFT'
import Foundation
import Darwin

enum ProofError: Error {
    case modeStateUnexpected, modeReadbackMismatch, reconnectManualStartRequired
}
enum InjectedFailure: Error { case directorySync }

let fixture = URL(fileURLWithPath: "/private/tmp", isDirectory: true)
    .appendingPathComponent("touch-me-qa-predecessor-" + UUID().uuidString, isDirectory: true)
defer { try? FileManager.default.removeItem(at: fixture) }
let oldOwner = DeviceModeRecoveryOwner(pid: 123456, startTimeSeconds: 100, startTimeMicroseconds: 1)
let newOwner = DeviceModeRecoveryOwner(pid: 123457, startTimeSeconds: 101, startTimeMicroseconds: 2)
let identity = DeviceModeRecoveryIdentity(bootSession: "00000000-0000-0000-0000-000000000001",
    hidRegistryID: 100, usbRegistryID: 200, locationID: 300, descriptorSHA256: String(repeating: "a", count: 64))
let first = try DeviceModeRecoveryJournal.acquire(directory: fixture, owner: oldOwner)
let record = try first.persistBeforeEnable(identity: identity, original: (0, 0))
first.close()

var failSync = true
var retainedSyncCalls = 0
let predecessor = try DeviceModeRecoveryJournal.acquire(directory: fixture, owner: newOwner,
    ownerLookup: { _ in nil }, directorySync: { _ in
        retainedSyncCalls += 1
        if failSync { throw InjectedFailure.directorySync }
    })
let action = try predecessor.recoveryAction(for: record, identity: identity, current: (2, 0))
precondition(action == .restoreOriginal)
print("predecessor_recovery_authorized=true (injected pair only; no hardware I/O)")
var removeThrew = false
do {
    try predecessor.removeAfterReadback(record, identity: identity, current: (0, 0))
} catch InjectedFailure.directorySync {
    removeThrew = true
}
precondition(removeThrew)
let visibleAfterFailure = try predecessor.load()
precondition(visibleAfterFailure == nil)
precondition(!predecessor.hasOwnedActiveRecord)
print("unlink_succeeded_directory_sync_failed=true")
print("active_record_visible=false")
print("has_owned_active_record=false")
let retainedAction = try predecessor.recoveryAction(for: record, identity: identity, current: (0, 0))
precondition(retainedAction == .alreadyOriginal)
print("retained_lease_can_retry_same_record=true")
predecessor.close()

var reacquiredSyncCalls = 0
let retry = try DeviceModeRecoveryJournal.acquire(directory: fixture, owner: newOwner,
    ownerLookup: { _ in nil }, directorySync: { _ in reacquiredSyncCalls += 1 })
defer { retry.close() }
func productionNoRecordBranch(_ journal: DeviceModeRecoveryJournal) throws -> Bool {
    guard try journal.load() != nil else {
        _ = try journal.loadReconnectGuard()
        return true
    }
    return false
}
let productionBranchReturnedSuccess = try productionNoRecordBranch(retry)
precondition(productionBranchReturnedSuccess)
precondition(reacquiredSyncCalls == 0)
print("close_reacquire_no_record_branch_returns_success=true")
print("directory_sync_calls_after_reacquire=\(reacquiredSyncCalls)")
print("directory_sync_calls_before_close=\(retainedSyncCalls)")
print("PASS: lost pending predecessor removal is reproducible using production journal")
SWIFT
swiftc -target arm64-apple-macosx26.0 \
  -module-cache-path "$TASK_QA_TMP/module-cache" \
  Sources/TouchMePlatform/DeviceModeTransaction.swift \
  Sources/TouchMePlatform/DeviceModeRecoveryJournal.swift \
  "$TASK_QA_TMP/main.swift" -o "$TASK_QA_TMP/check"
"$TASK_QA_TMP/check"
```

Compile: exit 0. Run: exit 0.

```text
predecessor_recovery_authorized=true (injected pair only; no hardware I/O)
unlink_succeeded_directory_sync_failed=true
active_record_visible=false
has_owned_active_record=false
retained_lease_can_retry_same_record=true
close_reacquire_no_record_branch_returns_success=true
directory_sync_calls_after_reacquire=0
directory_sync_calls_before_close=1
PASS: lost pending predecessor removal is reproducible using production journal
```

The first compile attempt used the default module cache and failed with a sandbox
permission error at `/Users/soom.kang/.cache/clang/ModuleCache`; no executable ran.
The corrected private temporary cache resolved that environment failure. The next
compile exposed two throwing precondition autoclosures in the temporary harness;
they were corrected to evaluate throwing calls before assertions. Production
source was unchanged.

### Production trace

- `DeviceModeRecoveryJournal.swift:558-563`: unlink, pendingRemoval, directory sync,
  clearing pendingRemoval only after successful sync.
- `DeviceModeRecoveryJournal.swift:189`: hasOwnedActiveRecord reports ownedNonce,
  which the predecessor lease never sets.
- `P16KTDeviceMode.swift:15-19`: needsRestore omits pendingRemoval.
- `P16KTDeviceMode.swift:174-176`: removal failure escapes before replacing the
  transaction's predecessor snapshot.
- `P16KTDeviceMode.swift:249`: needsRestore false closes the journal on rollback.
- `ProofMapper.swift:412-416,438-446`: startup recovery has a local control and
  closes its journal; a retry returns when the record is absent.
- `ProofUI.swift:839-841,846-865`: a successful retry clears startupRecoveryError
  and reports mapping stopped despite no successful retry of the directory sync.

### Interpretation

[Verified] The pending removal state is lost when the predecessor lease closes;
the equivalent retry branch returns without a directory-sync call.

[Source-traced] Production does not retain that predecessor control/pending state
across this failure, and Retry can clear the UI error.

[Inference] A subsequent power interruption may leave a stale active record on
storage because removal was not confirmed durable. This experiment does not
simulate power loss and does not prove actual filesystem replay or an unsafe
device-mode write. The observed defect is premature cleanup success reporting.

### Existing coverage

`DeviceModeRecoveryJournalTests.swift:149-198` retains the old-owner journal and
checks the same-record retry directly. It does not cover new-owner lifetime and
production no-record retry. TMQA-003 is the owning recovery ticket; its build 23
physical continuous-attachment PASS is retained and does not cover this injected
failure path.

### Acceptance criterion

Retain the exact predecessor's pending directory-sync cleanup until it succeeds,
or provide an equivalent explicit durable-completion path. Under injected unlink
success plus sync failure, Retry must complete sync for the same record before
reporting cleanup success. It must not add a device-mode write, overwrite a new
record, unlink again or reuse mismatched ownership/identity evidence. Use the
existing test target/seams rather than new test infrastructure.
