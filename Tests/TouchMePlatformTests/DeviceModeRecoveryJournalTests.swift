import Foundation
import Testing
@testable import TouchMePlatform

struct DeviceModeRecoveryJournalTests {
    private enum Failure: Error { case ownerQuery, attachmentQuery, directorySync }
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
            try journal.retireUnchangedAttachment(identity: self.identity, original: (2, 0),
                bootSession: self.identity.bootSession, attachmentEnded: { true })
        }
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
        for ended in [false, true] {
            let directory = directory()
            defer { try? FileManager.default.removeItem(at: directory) }
            var failSync = true
            var syncs = 0
            let journal = try DeviceModeRecoveryJournal.acquire(directory: directory, owner: oldOwner, directorySync: { _ in
                syncs += 1
                if failSync { throw Failure.directorySync }
            })
            defer { journal.close() }
            // A failed first installation returns no record to its caller, but
            // the exact owned record still lets rollback remove it safely.
            #expect(throws: Failure.self) { try journal.persistBeforeEnable(identity: self.identity, original: (0, 0)) }
            #expect(journal.hasOwnedActiveRecord)
            let record = try #require(try journal.ownedActiveRecord())
            #expect(try journal.load() == record)
            #expect(throws: Failure.self) {
                try journal.removeAfterReadback(record, identity: self.identity, current: (0, 0))
            }
            #expect(try journal.load() == nil)
            #expect(try journal.ownedActiveRecord() == nil)
            #expect(throws: DeviceModeRecoveryJournalError.self) {
                try journal.recoveryAction(for: record, identity: self.identity, current: (2, 0))
            }
            #expect(throws: DeviceModeRecoveryJournalError.self) {
                try journal.persistBeforeEnable(identity: self.identity, original: (0, 0))
            }
            failSync = false
            if ended {
                // The services can disappear between readback and sync Retry.
                // The cached removal then becomes a file-only retirement.
                let changed = DeviceModeRecoveryRecord(schemaVersion: 1, nonce: UUID().uuidString,
                    identity: identity, owner: oldOwner, originalMode: 0, originalIdentifier: 0)
                #expect(throws: DeviceModeRecoveryJournalError.self) {
                    try journal.retireDisconnected(changed, bootSession: self.identity.bootSession, attachmentEnded: { true })
                }
                try journal.retireDisconnected(record, bootSession: identity.bootSession, attachmentEnded: { true })
                #expect(try journal.loadReconnectGuard()?.nonce == record.nonce)
                #expect(syncs == 5)
            } else {
                #expect(try journal.recoveryAction(for: record, identity: identity, current: (0, 0)) == .alreadyOriginal)
                try journal.removeAfterReadback(record, identity: identity, current: (0, 0))
                #expect(syncs == 3)
            }
            #expect(try journal.load() == nil)
            #expect(try journal.ownedActiveRecord() == nil)
            #expect(!journal.hasOwnedActiveRecord)
        }
    }

    @Test func endedAttachmentsArchiveOwnedAndProvenDeadRecordsBeforeFreshEnable() throws {
        for previousProcess in [false, true] {
            let directory = directory()
            defer { try? FileManager.default.removeItem(at: directory) }
            let first = try DeviceModeRecoveryJournal.acquire(directory: directory, owner: oldOwner)
            let record = try first.persistBeforeEnable(identity: identity, original: (0, 0))
            let journal: DeviceModeRecoveryJournal
            if previousProcess {
                first.close()
                journal = try DeviceModeRecoveryJournal.acquire(directory: directory, owner: newOwner,
                                                               ownerLookup: { _ in nil })
            } else {
                journal = first
            }
            defer { journal.close() }
            try journal.retireDisconnected(record, bootSession: identity.bootSession, attachmentEnded: { true })
            #expect(try journal.load() == nil)
            let reconnectGuard = try #require(try journal.loadReconnectGuard())
            #expect(reconnectGuard.nonce == record.nonce)
            #expect(reconnectGuard.identity == identity)
            #expect(reconnectGuard.outcome == "disconnected-unrestored")
            let archiveURL = directory.appendingPathComponent("disconnected-\(record.nonce).json")
            let archive = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: archiveURL)) as? [String: Any])
            #expect(archive["outcome"] as? String == "disconnected-unrestored")
            let archivedRecord = try #require(archive["record"] as? [String: Any])
            #expect(archivedRecord["nonce"] as? String == record.nonce)
            #expect(archivedRecord["originalMode"] as? Int == 0)

            // The fixed guard survives process loss independently of preferences.
            journal.close()
            let next = try DeviceModeRecoveryJournal.acquire(directory: directory, owner: newOwner,
                                                            ownerLookup: { _ in nil })
            defer { next.close() }
            #expect(try next.loadReconnectGuard() == reconnectGuard)
            let freshIdentity = DeviceModeRecoveryIdentity(bootSession: identity.bootSession,
                hidRegistryID: identity.hidRegistryID + 1, usbRegistryID: identity.usbRegistryID + 1,
                locationID: identity.locationID, descriptorSHA256: identity.descriptorSHA256)
            let fresh = try next.persistBeforeEnable(identity: freshIdentity, original: (0, 0))
            #expect(fresh.nonce != record.nonce)
            // A second detach before activation must not conflict with the old gate.
            try next.retireDisconnected(fresh, bootSession: identity.bootSession, attachmentEnded: { true })
            #expect(try next.loadReconnectGuard() == reconnectGuard)
            #expect(try next.load() == nil)
            let resumed = try next.persistBeforeEnable(identity: freshIdentity, original: (0, 0))
            try next.acknowledgeReconnectGuard(reconnectGuard)
            #expect(try next.loadReconnectGuard() == nil)
            #expect(try next.load() == resumed)
            #expect(FileManager.default.fileExists(atPath: archiveURL.path))
        }
    }

    @Test func retirementRejectsUncertainAttachmentBootNonceAndOwners() throws {
        enum Refusal: CaseIterable {
            case attachmentPresent, attachmentQuery, changedBoot, changedNonce
            case ownerAlive, ownerReused, ownerQuery
        }
        for refusal in Refusal.allCases {
            let directory = directory()
            defer { try? FileManager.default.removeItem(at: directory) }
            let first = try DeviceModeRecoveryJournal.acquire(directory: directory, owner: oldOwner)
            let record = try first.persistBeforeEnable(identity: identity, original: (0, 0))
            let journal: DeviceModeRecoveryJournal
            if [.ownerAlive, .ownerReused, .ownerQuery].contains(refusal) {
                first.close()
                journal = try DeviceModeRecoveryJournal.acquire(directory: directory, owner: newOwner,
                    ownerLookup: { _ in
                        if refusal == .ownerQuery { throw Failure.ownerQuery }
                        if refusal == .ownerReused {
                            return DeviceModeRecoveryOwner(pid: self.oldOwner.pid, startTimeSeconds: 999,
                                                           startTimeMicroseconds: 0)
                        }
                        return self.oldOwner
                    })
            } else {
                journal = first
            }
            defer { journal.close() }
            let input = refusal == .changedNonce
                ? DeviceModeRecoveryRecord(schemaVersion: 1, nonce: UUID().uuidString, identity: identity,
                                           owner: oldOwner, originalMode: 0, originalIdentifier: 0)
                : record
            let attempt = {
                try journal.retireDisconnected(input,
                    bootSession: refusal == .changedBoot ? UUID().uuidString : self.identity.bootSession,
                    attachmentEnded: {
                        if refusal == .attachmentQuery { throw Failure.attachmentQuery }
                        return refusal != .attachmentPresent
                    })
            }
            if refusal == .attachmentQuery {
                #expect(throws: Failure.self) { try attempt() }
            } else {
                #expect(throws: DeviceModeRecoveryJournalError.self) { try attempt() }
            }
            #expect(try journal.load() == record)
            #expect(try journal.loadReconnectGuard() == nil)
            #expect(!FileManager.default.fileExists(
                atPath: directory.appendingPathComponent("disconnected-\(record.nonce).json").path))
        }
    }

    @Test func retirementSyncFailuresRetryWithoutOverwritingOrNewEnable() throws {
        for phase in 1...3 {
            let directory = directory()
            defer { try? FileManager.default.removeItem(at: directory) }
            var syncs = 0
            var failAt: Int?
            let journal = try DeviceModeRecoveryJournal.acquire(directory: directory, owner: oldOwner,
                directorySync: { _ in
                    syncs += 1
                    if syncs == failAt { throw Failure.directorySync }
                })
            defer { journal.close() }
            let record = try journal.persistBeforeEnable(identity: identity, original: (0, 0))
            failAt = syncs + phase
            #expect(throws: Failure.self) {
                try journal.retireDisconnected(record, bootSession: self.identity.bootSession,
                                               attachmentEnded: { true })
            }
            #expect(try journal.load() == (phase == 3 ? nil : record))
            #expect(throws: DeviceModeRecoveryJournalError.self) {
                try journal.persistBeforeEnable(identity: self.identity, original: (0, 0))
            }
            failAt = nil
            try journal.retireDisconnected(record, bootSession: identity.bootSession, attachmentEnded: { true })
            #expect(try journal.load() == nil)
            #expect(try journal.loadReconnectGuard()?.nonce == record.nonce)
            let archives = try FileManager.default.contentsOfDirectory(atPath: directory.path)
                .filter { $0.hasPrefix("disconnected-") }
            #expect(archives == ["disconnected-\(record.nonce).json"])
        }
    }

    @Test func guardAcknowledgementRetryOnlySyncsAndPreservesArchive() throws {
        let directory = directory()
        defer { try? FileManager.default.removeItem(at: directory) }
        var failSync = false
        var syncs = 0
        let journal = try DeviceModeRecoveryJournal.acquire(directory: directory, owner: oldOwner,
            directorySync: { _ in
                syncs += 1
                if failSync { throw Failure.directorySync }
            })
        defer { journal.close() }
        let record = try journal.persistBeforeEnable(identity: identity, original: (0, 0))
        try journal.retireDisconnected(record, bootSession: identity.bootSession, attachmentEnded: { true })
        let reconnectGuard = try #require(try journal.loadReconnectGuard())
        let freshIdentity = DeviceModeRecoveryIdentity(bootSession: identity.bootSession,
            hidRegistryID: identity.hidRegistryID + 1, usbRegistryID: identity.usbRegistryID + 1,
            locationID: identity.locationID, descriptorSHA256: identity.descriptorSHA256)
        let fresh = try journal.persistBeforeEnable(identity: freshIdentity, original: (0, 0))
        let changed = DeviceModeReconnectGuard(schemaVersion: 1, nonce: UUID().uuidString, identity: identity,
                                               outcome: "disconnected-unrestored")
        #expect(throws: DeviceModeRecoveryJournalError.self) { try journal.acknowledgeReconnectGuard(changed) }
        failSync = true
        #expect(throws: Failure.self) { try journal.acknowledgeReconnectGuard(reconnectGuard) }
        #expect(!FileManager.default.fileExists(atPath: directory.appendingPathComponent("reconnect-required.json").path))
        #expect(try journal.loadReconnectGuard() == reconnectGuard)
        #expect(journal.hasPendingReconnectAcknowledgement)
        #expect(throws: DeviceModeRecoveryJournalError.self) {
            try journal.preserveReconnectGuardAfterFailedAcknowledgement(changed)
        }
        #expect(throws: Failure.self) {
            try journal.preserveReconnectGuardAfterFailedAcknowledgement(reconnectGuard)
        }
        #expect(FileManager.default.fileExists(atPath: directory.appendingPathComponent("reconnect-required.json").path))
        #expect(try journal.loadReconnectGuard() == reconnectGuard)
        #expect(journal.hasPendingReconnectAcknowledgement)
        failSync = false
        try journal.preserveReconnectGuardAfterFailedAcknowledgement(reconnectGuard)
        #expect(!journal.hasPendingReconnectAcknowledgement)
        // A cable removal during failed Start can retire its newer active
        // record while preserving the predecessor's re-persisted guard.
        try journal.retireDisconnected(fresh, bootSession: identity.bootSession, attachmentEnded: { true })
        #expect(try journal.load() == nil)
        #expect(try journal.loadReconnectGuard() == reconnectGuard)
        failSync = true
        #expect(throws: Failure.self) { try journal.acknowledgeReconnectGuard(reconnectGuard) }
        #expect(throws: DeviceModeRecoveryJournalError.self) {
            try journal.persistBeforeEnable(identity: self.identity, original: (0, 0))
        }
        failSync = false
        let beforeRetry = syncs
        try journal.acknowledgeReconnectGuard(reconnectGuard)
        #expect(syncs == beforeRetry + 1)
        #expect(try journal.loadReconnectGuard() == nil)
        #expect(FileManager.default.fileExists(
            atPath: directory.appendingPathComponent("disconnected-\(record.nonce).json").path))
    }

    @Test func unchangedDisconnectGuardSurvivesCrashBeforeArchiveForBothSupportedModes() throws {
        struct Archive: Decodable { let record: DeviceModeUnchangedDisconnectRecord }
        for originalMode in [0, 2] {
            let directory = directory()
            defer { try? FileManager.default.removeItem(at: directory) }
            var failSync = false
            let first = try DeviceModeRecoveryJournal.acquire(directory: directory, owner: oldOwner,
                directorySync: { _ in if failSync { throw Failure.directorySync } })
            #expect(throws: Failure.self) {
                try first.retireUnchangedAttachment(identity: self.identity, original: (originalMode, 0),
                    bootSession: self.identity.bootSession, attachmentEnded: { throw Failure.attachmentQuery })
            }
            #expect(!first.hasPendingUnchangedDisconnect)
            #expect(try first.loadReconnectGuard() == nil)
            failSync = true
            #expect(throws: Failure.self) {
                try first.retireUnchangedAttachment(identity: self.identity, original: (originalMode, 0),
                    bootSession: self.identity.bootSession, attachmentEnded: { true })
            }
            #expect(first.hasPendingUnchangedDisconnect)
            #expect(try first.load() == nil)
            let guardURL = directory.appendingPathComponent("reconnect-required.json")
            let guardBytes = try Data(contentsOf: guardURL)
            let captured = try JSONDecoder().decode(DeviceModeReconnectGuard.self, from: guardBytes)
            let capturedRecord = try #require(captured.unchangedRecord)
            #expect(capturedRecord.owner == oldOwner)
            #expect(capturedRecord.originalMode == originalMode)
            let archiveURL = directory.appendingPathComponent("disconnected-\(captured.nonce).json")
            #expect(!FileManager.default.fileExists(atPath: archiveURL.path))
            first.close()

            let restarted = try DeviceModeRecoveryJournal.acquire(directory: directory, owner: newOwner)
            // Only a genuinely absent canonical archive can be reconstructed,
            // using the guard's original owner and pair after process loss.
            #expect(try restarted.loadReconnectGuard() == captured)
            let archive = try JSONDecoder().decode(Archive.self, from: Data(contentsOf: archiveURL))
            #expect(archive.record == capturedRecord)
            try restarted.retireUnchangedAttachment(identity: identity, original: (originalMode, 0),
                bootSession: identity.bootSession, attachmentEnded: { true })
            #expect(!restarted.hasPendingUnchangedDisconnect)
            #expect(try restarted.loadReconnectGuard() == captured)
            #expect(try restarted.load() == nil)

            let foreign = DeviceModeRecoveryIdentity(bootSession: identity.bootSession,
                hidRegistryID: identity.hidRegistryID + 1, usbRegistryID: identity.usbRegistryID + 1,
                locationID: identity.locationID + 1, descriptorSHA256: identity.descriptorSHA256)
            #expect(throws: DeviceModeRecoveryJournalError.self) {
                try restarted.retireUnchangedAttachment(identity: foreign, original: (originalMode, 0),
                    bootSession: self.identity.bootSession, attachmentEnded: { true })
            }
            #expect(restarted.hasPendingUnchangedDisconnect)
            #expect(try Data(contentsOf: guardURL) == guardBytes)
            restarted.close()

            let final = try DeviceModeRecoveryJournal.acquire(directory: directory, owner: newOwner)
            defer { final.close() }
            let damaged = Data("{\"schemaVersion\":999}".utf8)
            try damaged.write(to: archiveURL)
            #expect(throws: DeviceModeRecoveryJournalError.self) { try final.loadReconnectGuard() }
            #expect(try Data(contentsOf: archiveURL) == damaged)
            #expect(try Data(contentsOf: guardURL) == guardBytes)
        }
    }

    @Test func reconnectGuardsRequireTheirExactPrivateArchive() throws {
        enum Damage: CaseIterable { case malformedArchive, changedArchiveNonce, symlinkGuard }
        for damage in Damage.allCases {
            let directory = directory()
            defer { try? FileManager.default.removeItem(at: directory) }
            let journal = try DeviceModeRecoveryJournal.acquire(directory: directory, owner: oldOwner)
            defer { journal.close() }
            let record = try journal.persistBeforeEnable(identity: identity, original: (0, 0))
            try journal.retireDisconnected(record, bootSession: identity.bootSession, attachmentEnded: { true })
            let guardURL = directory.appendingPathComponent("reconnect-required.json")
            let archiveURL = directory.appendingPathComponent("disconnected-\(record.nonce).json")
            if damage == .symlinkGuard {
                let copiedGuard = directory.appendingPathComponent("copied-guard.json")
                try Data(contentsOf: guardURL).write(to: copiedGuard)
                try FileManager.default.removeItem(at: guardURL)
                try FileManager.default.createSymbolicLink(at: guardURL, withDestinationURL: copiedGuard)
            } else if damage == .malformedArchive {
                try Data("{\"schemaVersion\":999}".utf8).write(to: archiveURL)
            } else {
                var archive = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: archiveURL)) as? [String: Any])
                var archivedRecord = try #require(archive["record"] as? [String: Any])
                archivedRecord["nonce"] = UUID().uuidString
                archive["record"] = archivedRecord
                try JSONSerialization.data(withJSONObject: archive).write(to: archiveURL)
            }
            #expect(throws: DeviceModeRecoveryJournalError.self) { try journal.loadReconnectGuard() }
            #expect(FileManager.default.fileExists(atPath: archiveURL.path))
        }
    }
}
