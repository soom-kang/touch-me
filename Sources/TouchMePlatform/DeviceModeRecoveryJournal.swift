import Foundation
import Darwin

struct DeviceModeRecoveryIdentity: Codable, Equatable {
    let bootSession: String
    let hidRegistryID: UInt64
    let usbRegistryID: UInt64
    let locationID: UInt32
    let descriptorSHA256: String

    fileprivate var isValid: Bool {
        UUID(uuidString: bootSession) != nil && hidRegistryID > 0 && usbRegistryID > 0 && locationID > 0
            && descriptorSHA256.utf8.count == 64
            && descriptorSHA256.utf8.allSatisfy { (48...57).contains($0) || (97...102).contains($0) }
    }
}

struct DeviceModeRecoveryOwner: Codable, Equatable {
    let pid: Int32
    let startTimeSeconds: UInt64
    let startTimeMicroseconds: UInt64

    fileprivate var isValid: Bool { pid > 0 && startTimeSeconds > 0 && startTimeMicroseconds < 1_000_000 }

    static func current() throws -> Self {
        guard let owner = try lookup(getpid()) else { throw DeviceModeRecoveryJournalError.ownerUnknown }
        return owner
    }

    /// A missing process is proven by ESRCH. Restricted, partial or otherwise
    /// inconclusive process queries never authorize an orphan recovery.
    static func lookup(_ pid: Int32) throws -> Self? {
        guard pid > 0 else { throw DeviceModeRecoveryJournalError.ownerUnknown }
        var info = proc_bsdinfo()
        let size = Int32(MemoryLayout<proc_bsdinfo>.size)
        let count = withUnsafeMutablePointer(to: &info) {
            proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, $0, size)
        }
        if count == size, info.pbi_pid == UInt32(pid), info.pbi_start_tvsec > 0 {
            return Self(pid: pid, startTimeSeconds: info.pbi_start_tvsec,
                        startTimeMicroseconds: info.pbi_start_tvusec)
        }
        if kill(pid, 0) == -1 && errno == ESRCH { return nil }
        throw DeviceModeRecoveryJournalError.ownerUnknown
    }
}

struct DeviceModeRecoveryRecord: Codable, Equatable {
    let schemaVersion: Int
    let nonce: String
    let identity: DeviceModeRecoveryIdentity
    let owner: DeviceModeRecoveryOwner
    let originalMode: Int
    let originalIdentifier: Int

    var original: DeviceModeTransaction.Pair { (originalMode, originalIdentifier) }
    fileprivate var isValid: Bool {
        schemaVersion == 1 && UUID(uuidString: nonce) != nil && identity.isValid && owner.isValid
            && originalMode == 0 && originalIdentifier == 0
    }
}

struct DeviceModeReconnectGuard: Codable, Equatable {
    let schemaVersion: Int
    let nonce: String
    let identity: DeviceModeRecoveryIdentity
    let outcome: String
    let unchangedRecord: DeviceModeUnchangedDisconnectRecord?

    init(schemaVersion: Int, nonce: String, identity: DeviceModeRecoveryIdentity, outcome: String,
         unchangedRecord: DeviceModeUnchangedDisconnectRecord? = nil) {
        self.schemaVersion = schemaVersion
        self.nonce = nonce
        self.identity = identity
        self.outcome = outcome
        self.unchangedRecord = unchangedRecord
    }

    fileprivate static func from(_ record: DeviceModeRecoveryRecord) -> Self {
        Self(schemaVersion: 1, nonce: record.nonce, identity: record.identity,
             outcome: "disconnected-unrestored")
    }

    fileprivate static func from(_ record: DeviceModeUnchangedDisconnectRecord) -> Self {
        Self(schemaVersion: 1, nonce: record.nonce, identity: record.identity,
             outcome: "disconnected-unchanged", unchangedRecord: record)
    }

    fileprivate var isValid: Bool {
        guard schemaVersion == 1, UUID(uuidString: nonce) != nil, identity.isValid else { return false }
        switch outcome {
        case "disconnected-unrestored": return unchangedRecord == nil
        case "disconnected-unchanged":
            guard let unchangedRecord else { return false }
            return unchangedRecord.isValid && unchangedRecord.nonce == nonce && unchangedRecord.identity == identity
        default: return false
        }
    }
}

struct DeviceModeUnchangedDisconnectRecord: Codable, Equatable {
    let schemaVersion: Int
    let nonce: String
    let identity: DeviceModeRecoveryIdentity
    let owner: DeviceModeRecoveryOwner
    let originalMode: Int
    let originalIdentifier: Int

    fileprivate var isValid: Bool {
        schemaVersion == 1 && UUID(uuidString: nonce) != nil && identity.isValid && owner.isValid
            && (originalMode == 0 || originalMode == 2) && originalIdentifier == 0
    }
}

private struct DeviceModeUnchangedArchive: Codable, Equatable {
    let schemaVersion: Int
    let outcome: String
    let record: DeviceModeUnchangedDisconnectRecord

    init(record: DeviceModeUnchangedDisconnectRecord) {
        schemaVersion = 1
        outcome = "disconnected-unchanged"
        self.record = record
    }

    var isValid: Bool {
        schemaVersion == 1 && outcome == "disconnected-unchanged" && record.isValid
    }
}

private struct DeviceModeDisconnectedArchive: Codable, Equatable {
    let schemaVersion: Int
    let outcome: String
    let record: DeviceModeRecoveryRecord

    init(record: DeviceModeRecoveryRecord) {
        schemaVersion = 1
        outcome = "disconnected-unrestored"
        self.record = record
    }

    var isValid: Bool {
        schemaVersion == 1 && outcome == "disconnected-unrestored" && record.isValid
    }
}

enum DeviceModeRecoveryJournalError: Error, LocalizedError {
    case busy, unsafePath, invalidRecord, identityChanged, ownerAlive, ownerChanged, ownerUnknown
    case unexpectedState, recordChanged
    case ioFailure(operation: String, code: Int32)

    var errorDescription: String? {
        switch self {
        case .busy: return "Another process holds the device-mode recovery lease."
        case .unsafePath: return "The device-mode recovery path or file is not privately owned and safe."
        case .invalidRecord: return "The previous device-mode recovery record is malformed or unsupported."
        case .identityChanged: return "The boot session, continuously attached device or descriptor changed."
        case .ownerAlive: return "The recorded device-mode owner is still running."
        case .ownerChanged: return "The recorded PID now belongs to a different process."
        case .ownerUnknown: return "The recorded owner's lifetime cannot be verified."
        case .unexpectedState: return "The measured device mode does not authorize recovery."
        case .recordChanged: return "The recovery record is missing, already pending or no longer matches this lease."
        case .ioFailure(let operation, let code): return "Recovery journal \(operation) failed (errno \(code))."
        }
    }
}

/// A nonblocking cross-process lease. Keep this object alive until readback and
/// journal removal finish. Closing or process exit releases the lock, never the
/// record. PID/start-time metadata remains an additional fail-closed guard even
/// when a crashed owner's flock has already been released by the kernel.
final class DeviceModeRecoveryJournal {
    enum RecoveryAction: Equatable { case alreadyOriginal, restoreOriginal }
    typealias OwnerLookup = (Int32) throws -> DeviceModeRecoveryOwner?
    private static let recordName = "mode-recovery.json"
    private static let lockName = "mode-recovery.lock"
    private static let reconnectGuardName = "reconnect-required.json"
    private let owner: DeviceModeRecoveryOwner
    private let ownerLookup: OwnerLookup
    private let directorySync: (Int32) throws -> Void
    private var directoryFD: Int32
    private var lockFD: Int32
    private var ownedNonce: String?
    private var pendingRemoval: DeviceModeRecoveryRecord?
    private var pendingRetirement: DeviceModeRecoveryRecord?
    private var pendingRetirementGuard: DeviceModeReconnectGuard?
    private var pendingGuardAcknowledgement: DeviceModeReconnectGuard?
    private var pendingUnchangedDisconnect: DeviceModeUnchangedDisconnectRecord?
    var hasOwnedActiveRecord: Bool { ownedNonce != nil }
    var hasPendingReconnectAcknowledgement: Bool { pendingGuardAcknowledgement != nil }
    var hasPendingUnchangedDisconnect: Bool { pendingUnchangedDisconnect != nil }

    private init(directoryFD: Int32, lockFD: Int32, owner: DeviceModeRecoveryOwner,
                 ownerLookup: @escaping OwnerLookup, directorySync: @escaping (Int32) throws -> Void) {
        self.directoryFD = directoryFD
        self.lockFD = lockFD
        self.owner = owner
        self.ownerLookup = ownerLookup
        self.directorySync = directorySync
    }

    static func acquire(directory: URL? = nil, owner suppliedOwner: DeviceModeRecoveryOwner? = nil,
                        ownerLookup: @escaping OwnerLookup = DeviceModeRecoveryOwner.lookup,
                        directorySync: ((Int32) throws -> Void)? = nil) throws -> DeviceModeRecoveryJournal {
        let owner = try suppliedOwner ?? DeviceModeRecoveryOwner.current()
        guard owner.isValid else { throw DeviceModeRecoveryJournalError.ownerUnknown }
        let target: URL
        if let directory {
            target = directory
        } else {
            let support = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                                      appropriateFor: nil, create: false)
            let application = support.appendingPathComponent("io.github.soom-kang.touchme", isDirectory: true)
            let fd = try privateDirectory(application)
            Darwin.close(fd)
            target = application.appendingPathComponent("mode-recovery", isDirectory: true)
        }
        let directoryFD = try privateDirectory(target)
        let lockFD = openat(directoryFD, lockName, O_RDWR | O_CREAT | O_CLOEXEC | O_NOFOLLOW, 0o600)
        guard lockFD >= 0 else {
            let error = pathError("open lock")
            Darwin.close(directoryFD)
            throw error
        }
        do {
            try secureFile(lockFD)
            guard flock(lockFD, LOCK_EX | LOCK_NB) == 0 else {
                if errno == EWOULDBLOCK { throw DeviceModeRecoveryJournalError.busy }
                throw DeviceModeRecoveryJournalError.ioFailure(operation: "lock", code: errno)
            }
            return DeviceModeRecoveryJournal(directoryFD: directoryFD, lockFD: lockFD, owner: owner,
                                             ownerLookup: ownerLookup, directorySync: directorySync ?? Self.syncDirectory)
        } catch {
            Darwin.close(lockFD)
            Darwin.close(directoryFD)
            throw error
        }
    }

    deinit { close() }

    func close() {
        if lockFD >= 0 { _ = flock(lockFD, LOCK_UN); Darwin.close(lockFD); lockFD = -1 }
        if directoryFD >= 0 { Darwin.close(directoryFD); directoryFD = -1 }
    }

    func load() throws -> DeviceModeRecoveryRecord? {
        guard let record: DeviceModeRecoveryRecord = try loadFile(Self.recordName) else { return nil }
        guard record.isValid else { throw DeviceModeRecoveryJournalError.invalidRecord }
        return record
    }

    /// Recover the caller's exact installation after a failed directory sync.
    /// A record from another lease or process is never adopted by this accessor.
    func ownedActiveRecord() throws -> DeviceModeRecoveryRecord? {
        guard let ownedNonce, let record = try load(), record.nonce == ownedNonce, record.owner == owner else {
            return nil
        }
        return record
    }

    /// A fixed guard path avoids scanning historical archives. An unconfirmed
    /// unlink remains a guard in this lease until its directory sync succeeds.
    func loadReconnectGuard() throws -> DeviceModeReconnectGuard? {
        let present: DeviceModeReconnectGuard? = try loadFile(Self.reconnectGuardName)
        if let pendingGuardAcknowledgement {
            guard present == nil || present == pendingGuardAcknowledgement else {
                throw DeviceModeRecoveryJournalError.recordChanged
            }
            try verifyArchive(for: pendingGuardAcknowledgement)
            return pendingGuardAcknowledgement
        }
        guard let present else { return nil }
        try verifyArchive(for: present)
        return present
    }

    /// Retirement never writes a device mode or claims successful restoration.
    /// The caller proves that both recorded native services ended in this boot.
    func retireDisconnected(_ record: DeviceModeRecoveryRecord, bootSession: String,
                            attachmentEnded: () throws -> Bool) throws {
        guard record.isValid else { throw DeviceModeRecoveryJournalError.invalidRecord }
        guard bootSession == record.identity.bootSession, try attachmentEnded() else {
            throw DeviceModeRecoveryJournalError.identityChanged
        }
        guard pendingGuardAcknowledgement == nil, pendingUnchangedDisconnect == nil else {
            throw DeviceModeRecoveryJournalError.recordChanged
        }
        let reconnectGuard = DeviceModeReconnectGuard.from(record)
        let archive = DeviceModeDisconnectedArchive(record: record)
        let present = try load()
        if let pendingRemoval {
            guard pendingRemoval == record, present == nil else { throw DeviceModeRecoveryJournalError.recordChanged }
        }
        if let pendingRetirement {
            guard pendingRetirement == record, present == nil,
                  let pendingRetirementGuard, try loadReconnectGuard() == pendingRetirementGuard,
                  try loadFile(Self.archiveName(record.nonce)) == archive else {
                throw DeviceModeRecoveryJournalError.recordChanged
            }
        } else {
            let finishingRemoval = pendingRemoval != nil
            guard finishingRemoval || present == record else { throw DeviceModeRecoveryJournalError.recordChanged }
            try authorizeOwner(record)
            let retainedGuard = try compatibleGuard(for: reconnectGuard)
            try installFile(archive, named: Self.archiveName(record.nonce))
            try installFile(retainedGuard, named: Self.reconnectGuardName)
            // Recheck evidence and the exact active record before removing it.
            guard try attachmentEnded(), try load() == (finishingRemoval ? nil : record) else {
                throw DeviceModeRecoveryJournalError.recordChanged
            }
            try authorizeOwner(record)
            if !finishingRemoval {
                guard unlinkat(directoryFD, Self.recordName, 0) == 0 else {
                    throw Self.pathError("retire active record")
                }
            }
            pendingRetirement = record
            pendingRetirementGuard = retainedGuard
        }
        try directorySync(directoryFD)
        pendingRetirement = nil
        pendingRetirementGuard = nil
        pendingRemoval = nil
        ownedNonce = nil
    }

    /// An unchanged attachment has no active mode-change record. Persist its
    /// reconstructable gate first so a crash cannot lose the disconnect origin.
    func retireUnchangedAttachment(identity: DeviceModeRecoveryIdentity, original: DeviceModeTransaction.Pair,
                                   bootSession: String, attachmentEnded: () throws -> Bool) throws {
        guard identity.isValid, original.identifier == 0, original.mode == 0 || original.mode == 2 else {
            throw DeviceModeRecoveryJournalError.unexpectedState
        }
        guard bootSession == identity.bootSession, try attachmentEnded() else {
            throw DeviceModeRecoveryJournalError.identityChanged
        }
        guard pendingRemoval == nil, pendingRetirement == nil, pendingGuardAcknowledgement == nil,
              try load() == nil else { throw DeviceModeRecoveryJournalError.recordChanged }
        let rawGuard: DeviceModeReconnectGuard? = try loadFile(Self.reconnectGuardName)
        if let rawGuard, !rawGuard.isValid { throw DeviceModeRecoveryJournalError.invalidRecord }
        if let pendingUnchangedDisconnect {
            guard pendingUnchangedDisconnect.identity == identity,
                  pendingUnchangedDisconnect.originalMode == original.mode,
                  pendingUnchangedDisconnect.originalIdentifier == original.identifier else {
                throw DeviceModeRecoveryJournalError.recordChanged
            }
        } else if let existing = rawGuard?.unchangedRecord, existing.identity == identity,
                  existing.originalMode == original.mode, existing.originalIdentifier == original.identifier {
            // Reuse the captured owner and nonce, never substitute this process.
            pendingUnchangedDisconnect = existing
        } else {
            pendingUnchangedDisconnect = DeviceModeUnchangedDisconnectRecord(schemaVersion: 1,
                nonce: UUID().uuidString, identity: identity, owner: owner,
                originalMode: original.mode, originalIdentifier: original.identifier)
        }
        guard let record = pendingUnchangedDisconnect else { throw DeviceModeRecoveryJournalError.recordChanged }
        let reconnectGuard = try compatibleGuard(for: DeviceModeReconnectGuard.from(record))
        try installFile(reconnectGuard, named: Self.reconnectGuardName)
        try installFile(DeviceModeUnchangedArchive(record: record), named: Self.archiveName(record.nonce))
        guard try attachmentEnded(), try load() == nil else { throw DeviceModeRecoveryJournalError.recordChanged }
        pendingUnchangedDisconnect = nil
    }

    /// Call after native preparation and durable baseline-zero ownership, or
    /// informed manual acceptance, before starting input. Failed Start rollback
    /// must re-persist a pending acknowledgement before releasing this lease.
    func acknowledgeReconnectGuard(_ reconnectGuard: DeviceModeReconnectGuard) throws {
        guard reconnectGuard.isValid, pendingRemoval == nil, pendingRetirement == nil,
              pendingUnchangedDisconnect == nil else {
            throw DeviceModeRecoveryJournalError.recordChanged
        }
        if let pendingGuardAcknowledgement {
            let present: DeviceModeReconnectGuard? = try loadFile(Self.reconnectGuardName)
            guard pendingGuardAcknowledgement == reconnectGuard, present == nil else {
                throw DeviceModeRecoveryJournalError.recordChanged
            }
            try verifyArchive(for: reconnectGuard)
        } else {
            guard try loadReconnectGuard() == reconnectGuard else {
                throw DeviceModeRecoveryJournalError.recordChanged
            }
            guard unlinkat(directoryFD, Self.reconnectGuardName, 0) == 0 else {
                throw Self.pathError("acknowledge reconnect guard")
            }
            pendingGuardAcknowledgement = reconnectGuard
        }
        try directorySync(directoryFD)
        pendingGuardAcknowledgement = nil
    }

    /// Rollback restores the durable gate before dropping a failed Start's lease.
    /// Keep pending ownership even if reinstallation succeeds but sync fails.
    func preserveReconnectGuardAfterFailedAcknowledgement(_ reconnectGuard: DeviceModeReconnectGuard) throws {
        guard pendingGuardAcknowledgement == reconnectGuard else {
            throw DeviceModeRecoveryJournalError.recordChanged
        }
        try verifyArchive(for: reconnectGuard)
        try installFile(reconnectGuard, named: Self.reconnectGuardName)
        pendingGuardAcknowledgement = nil
    }

    private func compatibleGuard(for reconnectGuard: DeviceModeReconnectGuard) throws -> DeviceModeReconnectGuard {
        guard let existing = try loadReconnectGuard() else { return reconnectGuard }
        guard existing.identity.bootSession == reconnectGuard.identity.bootSession,
              existing.identity.locationID == reconnectGuard.identity.locationID,
              existing.identity.descriptorSHA256 == reconnectGuard.identity.descriptorSHA256 else {
            throw DeviceModeRecoveryJournalError.recordChanged
        }
        // A fresh attempt can end before acknowledging its predecessor's gate.
        // Preserve that exact validated guard while archiving the newer record.
        return existing
    }

    private static func archiveName(_ nonce: String) -> String { "disconnected-\(nonce).json" }

    private func verifyArchive(for reconnectGuard: DeviceModeReconnectGuard) throws {
        guard reconnectGuard.isValid else { throw DeviceModeRecoveryJournalError.invalidRecord }
        if let record = reconnectGuard.unchangedRecord {
            let expected = DeviceModeUnchangedArchive(record: record)
            if let present: DeviceModeUnchangedArchive = try loadFile(Self.archiveName(reconnectGuard.nonce)) {
                guard present.isValid, present == expected else { throw DeviceModeRecoveryJournalError.invalidRecord }
            } else {
                // The private guard contains the exact captured pair and owner.
                // Complete only an absent archive; never repair an existing file.
                try installFile(expected, named: Self.archiveName(reconnectGuard.nonce))
            }
        } else if let archive: DeviceModeDisconnectedArchive = try loadFile(Self.archiveName(reconnectGuard.nonce)),
                  archive.isValid, DeviceModeReconnectGuard.from(archive.record) == reconnectGuard {
            return
        } else {
            throw DeviceModeRecoveryJournalError.invalidRecord
        }
    }

    private func loadFile<Value: Decodable>(_ name: String) throws -> Value? {
        try verifyLease()
        let fd = openat(directoryFD, name, O_RDONLY | O_CLOEXEC | O_NOFOLLOW)
        guard fd >= 0 else {
            if errno == ENOENT { return nil }
            throw Self.pathError("open record")
        }
        defer { Darwin.close(fd) }
        try Self.secureFile(fd)
        var info = stat()
        guard fstat(fd, &info) == 0 else { throw Self.pathError("stat record") }
        guard info.st_size > 0, info.st_size <= 16_384 else { throw DeviceModeRecoveryJournalError.invalidRecord }
        var bytes = [UInt8](repeating: 0, count: Int(info.st_size) + 1)
        var total = 0
        while total < bytes.count {
            let capacity = bytes.count - total
            let count = bytes.withUnsafeMutableBytes { Darwin.read(fd, $0.baseAddress!.advanced(by: total), capacity) }
            if count < 0 {
                if errno == EINTR { continue }
                throw Self.pathError("read record")
            }
            if count == 0 { break }
            total += count
        }
        guard total == Int(info.st_size),
              let value = try? JSONDecoder().decode(Value.self, from: Data(bytes.prefix(total))) else {
            throw DeviceModeRecoveryJournalError.invalidRecord
        }
        return value
    }

    private func installFile<Value: Codable & Equatable>(_ value: Value, named name: String) throws {
        if let present: Value = try loadFile(name) {
            guard present == value else { throw DeviceModeRecoveryJournalError.recordChanged }
            try directorySync(directoryFD)
            return
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(value)
        let temporary = ".\(name)-\(UUID().uuidString).tmp"
        let fd = openat(directoryFD, temporary, O_WRONLY | O_CREAT | O_EXCL | O_CLOEXEC | O_NOFOLLOW, 0o600)
        guard fd >= 0 else { throw Self.pathError("create retirement file") }
        defer { Darwin.close(fd); _ = unlinkat(directoryFD, temporary, 0) }
        try Self.secureFile(fd)
        try data.withUnsafeBytes { buffer in
            var offset = 0
            while offset < data.count {
                let count = Darwin.write(fd, buffer.baseAddress!.advanced(by: offset), data.count - offset)
                if count < 0 && errno == EINTR { continue }
                guard count > 0 else { throw Self.pathError("write retirement file") }
                offset += count
            }
        }
        guard fsync(fd) == 0 else { throw Self.pathError("sync retirement file") }
        try verifyLease()
        guard renameatx_np(directoryFD, temporary, directoryFD, name, UInt32(RENAME_EXCL)) == 0 else {
            if errno == EEXIST { throw DeviceModeRecoveryJournalError.recordChanged }
            throw Self.pathError("install retirement file")
        }
        try directorySync(directoryFD)
    }

    /// Returning successfully is the gate for the caller's first feature write.
    /// An existing record is never overwritten, even when its original is 0.
    func persistBeforeEnable(identity: DeviceModeRecoveryIdentity,
                             original: DeviceModeTransaction.Pair) throws -> DeviceModeRecoveryRecord {
        guard identity.isValid, original.mode == 0, original.identifier == 0 else {
            throw DeviceModeRecoveryJournalError.unexpectedState
        }
        guard pendingRemoval == nil, pendingRetirement == nil, pendingGuardAcknowledgement == nil,
              pendingUnchangedDisconnect == nil,
              try load() == nil else { throw DeviceModeRecoveryJournalError.recordChanged }
        let record = DeviceModeRecoveryRecord(schemaVersion: 1, nonce: UUID().uuidString, identity: identity,
                                              owner: owner, originalMode: original.mode, originalIdentifier: original.identifier)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(record)
        let temporary = ".mode-recovery-\(record.nonce).tmp"
        let fd = openat(directoryFD, temporary, O_WRONLY | O_CREAT | O_EXCL | O_CLOEXEC | O_NOFOLLOW, 0o600)
        guard fd >= 0 else { throw Self.pathError("create record") }
        defer { Darwin.close(fd); _ = unlinkat(directoryFD, temporary, 0) }
        try Self.secureFile(fd)
        try data.withUnsafeBytes { buffer in
            var offset = 0
            while offset < data.count {
                let count = Darwin.write(fd, buffer.baseAddress!.advanced(by: offset), data.count - offset)
                if count < 0 && errno == EINTR { continue }
                guard count > 0 else { throw Self.pathError("write record") }
                offset += count
            }
        }
        guard fsync(fd) == 0 else { throw Self.pathError("sync record") }
        try verifyLease()
        guard renameatx_np(directoryFD, temporary, directoryFD, Self.recordName, UInt32(RENAME_EXCL)) == 0 else {
            if errno == EEXIST { throw DeviceModeRecoveryJournalError.recordChanged }
            throw Self.pathError("install record")
        }
        // Preserve ownership if directory sync fails after atomic installation:
        // no feature write is authorized, and the installed record remains.
        ownedNonce = record.nonce
        try directorySync(directoryFD)
        return record
    }

    func recoveryAction(for record: DeviceModeRecoveryRecord, identity: DeviceModeRecoveryIdentity,
                        current: DeviceModeTransaction.Pair) throws -> RecoveryAction {
        try authorize(record, identity: identity)
        guard current.identifier == 0 else { throw DeviceModeRecoveryJournalError.unexpectedState }
        if current.mode == record.originalMode { return .alreadyOriginal }
        // After unlink, Retry may finish durable directory sync only. It must
        // never turn a later mode change into a new device recovery write.
        guard pendingRemoval == nil, current.mode == 2 else { throw DeviceModeRecoveryJournalError.unexpectedState }
        return .restoreOriginal
    }

    func removeAfterReadback(_ record: DeviceModeRecoveryRecord, identity: DeviceModeRecoveryIdentity,
                             current: DeviceModeTransaction.Pair) throws {
        try authorize(record, identity: identity)
        guard current.mode == record.originalMode, current.identifier == record.originalIdentifier else {
            throw DeviceModeRecoveryJournalError.unexpectedState
        }
        if pendingRemoval == nil {
            guard unlinkat(directoryFD, Self.recordName, 0) == 0 else { throw Self.pathError("remove record") }
            pendingRemoval = record
        }
        try directorySync(directoryFD)
        pendingRemoval = nil
        ownedNonce = nil
    }

    private func authorize(_ record: DeviceModeRecoveryRecord, identity: DeviceModeRecoveryIdentity) throws {
        guard record.isValid else { throw DeviceModeRecoveryJournalError.invalidRecord }
        guard identity.isValid, identity == record.identity else { throw DeviceModeRecoveryJournalError.identityChanged }
        guard pendingRetirement == nil else { throw DeviceModeRecoveryJournalError.recordChanged }
        let present = try load()
        if let pendingRemoval {
            guard pendingRemoval == record, present == nil else { throw DeviceModeRecoveryJournalError.recordChanged }
            return
        }
        guard present == record else { throw DeviceModeRecoveryJournalError.recordChanged }
        try authorizeOwner(record)
    }

    private func authorizeOwner(_ record: DeviceModeRecoveryRecord) throws {
        if ownedNonce == record.nonce, record.owner == owner { return }
        let live: DeviceModeRecoveryOwner?
        do { live = try ownerLookup(record.owner.pid) }
        catch { throw DeviceModeRecoveryJournalError.ownerUnknown }
        if let live {
            throw live == record.owner ? DeviceModeRecoveryJournalError.ownerAlive : DeviceModeRecoveryJournalError.ownerChanged
        }
    }

    private func verifyLease() throws {
        guard directoryFD >= 0, lockFD >= 0 else {
            throw DeviceModeRecoveryJournalError.ioFailure(operation: "closed lease", code: EBADF)
        }
        var held = stat(), named = stat()
        guard fstat(lockFD, &held) == 0,
              fstatat(directoryFD, Self.lockName, &named, AT_SYMLINK_NOFOLLOW) == 0,
              held.st_dev == named.st_dev, held.st_ino == named.st_ino,
              (named.st_mode & mode_t(S_IFMT)) == mode_t(S_IFREG), named.st_nlink == 1 else {
            throw DeviceModeRecoveryJournalError.unsafePath
        }
    }

    private static func privateDirectory(_ url: URL) throws -> Int32 {
        guard url.isFileURL, url.lastPathComponent != ".", url.lastPathComponent != ".." else {
            throw DeviceModeRecoveryJournalError.unsafePath
        }
        let parent = open(url.deletingLastPathComponent().path, O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW_ANY)
        guard parent >= 0 else { throw pathError("open parent directory") }
        defer { Darwin.close(parent) }
        if mkdirat(parent, url.lastPathComponent, 0o700) == 0 {
            guard fsync(parent) == 0 else { throw pathError("sync parent directory") }
        } else if errno != EEXIST { throw pathError("create directory") }
        let fd = openat(parent, url.lastPathComponent, O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW)
        guard fd >= 0 else { throw pathError("open directory") }
        var info = stat()
        guard fstat(fd, &info) == 0, (info.st_mode & mode_t(S_IFMT)) == mode_t(S_IFDIR),
              info.st_uid == geteuid(), info.st_mode & 0o077 == 0 else {
            Darwin.close(fd)
            throw DeviceModeRecoveryJournalError.unsafePath
        }
        return fd
    }

    private static func secureFile(_ fd: Int32) throws {
        var info = stat()
        guard fstat(fd, &info) == 0, (info.st_mode & mode_t(S_IFMT)) == mode_t(S_IFREG),
              info.st_uid == geteuid(), info.st_nlink == 1, info.st_mode & 0o777 == 0o600 else {
            throw DeviceModeRecoveryJournalError.unsafePath
        }
    }

    private static func pathError(_ operation: String) -> DeviceModeRecoveryJournalError {
        errno == ELOOP || errno == ENOTDIR ? .unsafePath : .ioFailure(operation: operation, code: errno)
    }

    private static func syncDirectory(_ fd: Int32) throws {
        guard fsync(fd) == 0 else { throw pathError("sync directory") }
    }
}
