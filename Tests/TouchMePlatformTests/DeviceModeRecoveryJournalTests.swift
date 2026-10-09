import Foundation
import Testing
@testable import TouchMePlatform

struct DeviceModeRecoveryJournalTests {
    private enum Failure: Error { case ownerQuery, directorySync }
    private let oldOwner = DeviceModeRecoveryOwner(pid: 123_456, startTimeSeconds: 100, startTimeMicroseconds: 1)
    private let newOwner = DeviceModeRecoveryOwner(pid: 123_457, startTimeSeconds: 101, startTimeMicroseconds: 2)
    private let identity = DeviceModeRecoveryIdentity(bootSession: "00000000-0000-0000-0000-000000000001",
        hidRegistryID: 100, usbRegistryID: 200, locationID: 300, descriptorSHA256: String(repeating: "a", count: 64))

    private func directory() -> URL {
        URL(fileURLWithPath: "/private/tmp", isDirectory: true)
            .appendingPathComponent("touch-me-journal-test-" + UUID().uuidString, isDirectory: true)
    }

    @Test func survivingRecordRequiresMatchingReadbackAndHandlesAlreadyOriginal() throws {
        let directory = directory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let first = try DeviceModeRecoveryJournal.acquire(directory: directory, owner: oldOwner)
        let record = try first.persistBeforeEnable(identity: identity, original: (0, 0))
        #expect(try first.load() == record)
        first.close()

        let restarted = try DeviceModeRecoveryJournal.acquire(directory: directory, owner: newOwner, ownerLookup: { _ in nil })
        defer { restarted.close() }
        #expect(try restarted.recoveryAction(for: record, identity: identity, current: (2, 0)) == .restoreOriginal)
        #expect(throws: DeviceModeRecoveryJournalError.self) {
            try restarted.removeAfterReadback(record, identity: identity, current: (2, 0))
        }
        #expect(try restarted.load() == record)
        // An earlier restoration may have succeeded just before its owner died.
        #expect(try restarted.recoveryAction(for: record, identity: identity, current: (0, 0)) == .alreadyOriginal)
        try restarted.removeAfterReadback(record, identity: identity, current: (0, 0))
        #expect(try restarted.load() == nil)
        #expect(throws: DeviceModeRecoveryJournalError.self) {
            try restarted.recoveryAction(for: record, identity: identity, current: (2, 0))
        }
    }

    @Test func initialModeTwoPendingRecordAndDifferentNonceCannotAuthorizeChanges() throws {
        let directory = directory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let journal = try DeviceModeRecoveryJournal.acquire(directory: directory, owner: oldOwner)
        defer { journal.close() }
        #expect(throws: DeviceModeRecoveryJournalError.self) {
            try journal.persistBeforeEnable(identity: identity, original: (2, 0))
        }
        #expect(try journal.load() == nil)
        let record = try journal.persistBeforeEnable(identity: identity, original: (0, 0))
        #expect(throws: DeviceModeRecoveryJournalError.self) {
            try journal.persistBeforeEnable(identity: identity, original: (0, 0))
        }
        let different = DeviceModeRecoveryRecord(schemaVersion: 1, nonce: UUID().uuidString, identity: identity,
            owner: oldOwner, originalMode: 0, originalIdentifier: 0)
        #expect(throws: DeviceModeRecoveryJournalError.self) {
            try journal.removeAfterReadback(different, identity: identity, current: (0, 0))
        }
        #expect(try journal.load() == record)
        // The live owner may complete its own exact-nonce transaction.
        try journal.removeAfterReadback(record, identity: identity, current: (0, 0))
    }

    @Test func changedIdentityAliveReusedAndUnknownOwnersPreserveRecord() throws {
        let directory = directory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let first = try DeviceModeRecoveryJournal.acquire(directory: directory, owner: oldOwner)
        let record = try first.persistBeforeEnable(identity: identity, original: (0, 0))
        first.close()

        let reused = DeviceModeRecoveryOwner(pid: oldOwner.pid, startTimeSeconds: 999, startTimeMicroseconds: 0)
        for live in [oldOwner, reused] {
            let journal = try DeviceModeRecoveryJournal.acquire(directory: directory, owner: newOwner, ownerLookup: { _ in live })
            #expect(throws: DeviceModeRecoveryJournalError.self) {
                try journal.recoveryAction(for: record, identity: identity, current: (2, 0))
            }
            #expect(try journal.load() == record)
            journal.close()
        }
        let unknown = try DeviceModeRecoveryJournal.acquire(directory: directory, owner: newOwner,
            ownerLookup: { _ in throw Failure.ownerQuery })
        #expect(throws: DeviceModeRecoveryJournalError.self) {
            try unknown.recoveryAction(for: record, identity: identity, current: (2, 0))
        }
        #expect(try unknown.load() == record)
        unknown.close()

        let journal = try DeviceModeRecoveryJournal.acquire(directory: directory, owner: newOwner, ownerLookup: { _ in nil })
        defer { journal.close() }
        let rebooted = DeviceModeRecoveryIdentity(bootSession: UUID().uuidString, hidRegistryID: identity.hidRegistryID,
            usbRegistryID: identity.usbRegistryID, locationID: identity.locationID, descriptorSHA256: identity.descriptorSHA256)
        #expect(throws: DeviceModeRecoveryJournalError.self) {
            try journal.recoveryAction(for: record, identity: rebooted, current: (2, 0))
        }
        #expect(throws: DeviceModeRecoveryJournalError.self) {
            try journal.recoveryAction(for: record, identity: identity, current: (2, 1))
        }
        #expect(try journal.load() == record)
    }

    @Test func malformedAndSymlinkRecordsFailBeforeFeatureWrite() throws {
        let directory = directory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let journal = try DeviceModeRecoveryJournal.acquire(directory: directory, owner: oldOwner)
        defer { journal.close() }
        let recordURL = directory.appendingPathComponent("mode-recovery.json")
        let malformed = Data("{\"schemaVersion\":999}".utf8)
        try malformed.write(to: recordURL)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: recordURL.path)
        var featureWrites = 0
        #expect(throws: DeviceModeRecoveryJournalError.self) {
            _ = try journal.persistBeforeEnable(identity: identity, original: (0, 0))
            featureWrites += 1
        }
        #expect(featureWrites == 0)
        #expect(try Data(contentsOf: recordURL) == malformed)
        try FileManager.default.removeItem(at: recordURL)

        let target = directory.appendingPathComponent("untouched-target")
        let original = Data("preserve".utf8)
        try original.write(to: target)
        try FileManager.default.createSymbolicLink(at: recordURL, withDestinationURL: target)
        #expect(throws: DeviceModeRecoveryJournalError.self) {
            _ = try journal.persistBeforeEnable(identity: identity, original: (0, 0))
            featureWrites += 1
        }
        #expect(featureWrites == 0)
        #expect(try Data(contentsOf: target) == original)
    }

    @Test func competingLeaseIsRejectedAndClosingDoesNotDeleteRecord() throws {
        let directory = directory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let first = try DeviceModeRecoveryJournal.acquire(directory: directory, owner: oldOwner)
        let record = try first.persistBeforeEnable(identity: identity, original: (0, 0))
        #expect(throws: DeviceModeRecoveryJournalError.self) {
            try DeviceModeRecoveryJournal.acquire(directory: directory, owner: newOwner)
        }
        first.close()
        let second = try DeviceModeRecoveryJournal.acquire(directory: directory, owner: newOwner, ownerLookup: { _ in nil })
        defer { second.close() }
        #expect(try second.load() == record)
    }

    @Test func removalSyncRetryRequiresSameRecordAndOriginalWithoutAnotherUnlink() throws {
        let directory = directory()
        defer { try? FileManager.default.removeItem(at: directory) }
        var failSync = false
        var syncs = 0
        let journal = try DeviceModeRecoveryJournal.acquire(directory: directory, owner: oldOwner, directorySync: { _ in
            syncs += 1
            if failSync { throw Failure.directorySync }
        })
        defer { journal.close() }
        let record = try journal.persistBeforeEnable(identity: identity, original: (0, 0))
        failSync = true
        #expect(throws: Failure.self) {
            try journal.removeAfterReadback(record, identity: identity, current: (0, 0))
        }
        #expect(try journal.load() == nil)
        #expect(throws: DeviceModeRecoveryJournalError.self) {
            try journal.recoveryAction(for: record, identity: identity, current: (2, 0))
        }
        #expect(throws: DeviceModeRecoveryJournalError.self) {
            try journal.persistBeforeEnable(identity: identity, original: (0, 0))
        }
        failSync = false
        #expect(try journal.recoveryAction(for: record, identity: identity, current: (0, 0)) == .alreadyOriginal)
        try journal.removeAfterReadback(record, identity: identity, current: (0, 0))
        #expect(try journal.load() == nil)
        #expect(syncs == 3)
    }
}
