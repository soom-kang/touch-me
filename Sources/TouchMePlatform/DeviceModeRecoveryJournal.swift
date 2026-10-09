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
    private let owner: DeviceModeRecoveryOwner
    private let ownerLookup: OwnerLookup
    private let directorySync: (Int32) throws -> Void
    private var directoryFD: Int32
    private var lockFD: Int32
    private var ownedNonce: String?
    private var pendingRemoval: DeviceModeRecoveryRecord?

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
        try verifyLease()
        let fd = openat(directoryFD, Self.recordName, O_RDONLY | O_CLOEXEC | O_NOFOLLOW)
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
              let record = try? JSONDecoder().decode(DeviceModeRecoveryRecord.self, from: Data(bytes.prefix(total))),
              record.isValid else { throw DeviceModeRecoveryJournalError.invalidRecord }
        return record
    }

    /// Returning successfully is the gate for the caller's first feature write.
    /// An existing record is never overwritten, even when its original is 0.
    func persistBeforeEnable(identity: DeviceModeRecoveryIdentity,
                             original: DeviceModeTransaction.Pair) throws -> DeviceModeRecoveryRecord {
        guard identity.isValid, original.mode == 0, original.identifier == 0 else {
            throw DeviceModeRecoveryJournalError.unexpectedState
        }
        guard pendingRemoval == nil, try load() == nil else { throw DeviceModeRecoveryJournalError.recordChanged }
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
        let present = try load()
        if let pendingRemoval {
            guard pendingRemoval == record, present == nil else { throw DeviceModeRecoveryJournalError.recordChanged }
            return
        }
        guard present == record else { throw DeviceModeRecoveryJournalError.recordChanged }
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
