import Foundation
import CryptoKit
import IOKit
import IOKit.hid
import Darwin

/// Uses the mapper's already-open device and restores the verified original pair.
final class P16KTDeviceMode {
    private let locationID: Int
    private var transaction: DeviceModeTransaction
    private var journal: DeviceModeRecoveryJournal?
    private var attachment: DeviceModeRecoveryIdentity?
    private var ownedRecord: DeviceModeRecoveryRecord?
    private var reconnectGuard: DeviceModeReconnectGuard?
    var needsRestore: Bool {
        transaction.needsRestore || ownedRecord != nil
            || journal?.hasOwnedActiveRecord == true
            || journal?.hasPendingReconnectAcknowledgement == true
            || journal?.hasPendingUnchangedDisconnect == true
    }
    var attachmentDescriptorSHA256: String? { attachment?.descriptorSHA256 }
    var attachmentIdentity: DeviceModeRecoveryIdentity? { attachment }
    var originalPair: DeviceModeTransaction.Pair { transaction.original }

    init(collection: HIDCollection) throws {
        let device = collection.device
        guard collection.vendor == 0x0457, collection.product == 0x0819,
              collection.usagePage == 0x0D, collection.usage == 0x04,
              let transport = IOHIDDeviceGetProperty(device, kIOHIDTransportKey as CFString) as? String,
              transport.caseInsensitiveCompare("USB") == .orderedSame,
              Self.integer(device, kIOHIDVendorIDKey) == 0x0457,
              Self.integer(device, kIOHIDProductIDKey) == 0x0819,
              Self.integer(device, kIOHIDPrimaryUsagePageKey) == 0x0D,
              Self.integer(device, kIOHIDPrimaryUsageKey) == 0x04,
              let locationID = Self.integer(device, kIOHIDLocationIDKey), locationID > 0 else {
            throw ProofError.modeUnsupported
        }
        let elements = IOHIDDeviceCopyMatchingElements(device, nil, 0) as? [IOHIDElement] ?? []
        func feature(usage: UInt32, reportID: UInt32, maximum: Int) -> IOHIDElement? {
            let matches = elements.filter {
                IOHIDElementGetType($0) == kIOHIDElementTypeFeature
                    && IOHIDElementGetUsagePage($0) == 0x0D && IOHIDElementGetUsage($0) == usage
                    && IOHIDElementGetReportID($0) == reportID
                    && IOHIDElementGetReportSize($0) == 8 && IOHIDElementGetReportCount($0) == 1
                    && IOHIDElementGetLogicalMin($0) == 0 && IOHIDElementGetLogicalMax($0) == maximum
            }
            return matches.count == 1 ? matches.first : nil
        }
        func hasConfigurationParent(_ element: IOHIDElement) -> Bool {
            guard let parent = IOHIDElementGetParent(element) else { return false }
            return IOHIDElementGetUsagePage(parent) == 0x0D && IOHIDElementGetUsage(parent) == 0x23
        }
        let reportFeatures = elements.filter {
            IOHIDElementGetType($0) == kIOHIDElementTypeFeature && IOHIDElementGetReportID($0) == 7
        }
        guard let mode = feature(usage: 0x52, reportID: 7, maximum: 10),
              let identifier = feature(usage: 0x53, reportID: 7, maximum: 10),
              feature(usage: 0x55, reportID: 8, maximum: 20) != nil,
              hasConfigurationParent(mode), hasConfigurationParent(identifier),
              reportFeatures.count == 2 else {
            throw ProofError.modeUnsupported
        }
        self.locationID = locationID
        transaction = try DeviceModeTransaction(
            read: { (try Self.read(device: device, element: mode),
                     try Self.read(device: device, element: identifier)) },
            write: { try Self.write(device: device, mode: mode, identifier: identifier, pair: $0) })
    }

    func isAtOriginalLocation(_ collection: HIDCollection) -> Bool {
        if let attachment { return (try? Self.recoveryIdentity(collection)) == attachment }
        return Self.integer(collection.device, kIOHIDLocationIDKey) == locationID
    }

    func rebind(to collection: HIDCollection) throws {
        guard isAtOriginalLocation(collection) else {
            throw DeviceModeRecoveryJournalError.identityChanged
        }
        let replacement = try P16KTDeviceMode(collection: collection)
        // Replace stale handles only; preserve the original pair and pending recovery.
        transaction.read = replacement.transaction.read
        transaction.write = replacement.transaction.write
    }

    func enable() throws {
        if let journal, let attachment {
            try verifyAttachment()
            let current = try transaction.read()
            guard current.mode == transaction.original.mode, current.identifier == transaction.original.identifier else {
                throw DeviceModeRecoveryJournalError.unexpectedState
            }
            if transaction.original.mode == 0 {
                // Keep the durable record and exclusive lease through a partial write.
                do {
                    ownedRecord = try journal.persistBeforeEnable(identity: attachment, original: transaction.original)
                } catch {
                    // Atomic installation may have succeeded before directory sync failed.
                    ownedRecord = try journal.ownedActiveRecord()
                    throw error
                }
            }
        }
        try transaction.enable()
    }

    func prepareStart(policy: MappingStartPolicy, expectedDescriptor: String?) throws {
        guard let journal, let attachment else { throw DeviceModeRecoveryJournalError.identityChanged }
        reconnectGuard = try journal.loadReconnectGuard()
        if policy != .manual, let reconnectGuard {
            guard reconnectGuard.identity.bootSession == attachment.bootSession,
                  reconnectGuard.identity.locationID == attachment.locationID,
                  reconnectGuard.identity.descriptorSHA256 == attachment.descriptorSHA256 else {
                throw DeviceModeRecoveryJournalError.identityChanged
            }
        }
        if policy == .reconnectAutomatic {
            guard let expected = expectedDescriptor ?? reconnectGuard?.identity.descriptorSHA256,
                  expected == attachment.descriptorSHA256 else {
                throw DeviceModeRecoveryJournalError.identityChanged
            }
        }
        if policy == .reconnectAutomatic || (policy == .automatic && reconnectGuard != nil) {
            try transaction.requireDefaultModeForAutomaticReconnect()
        }
    }

    /// Input is still inactive; a failed durable acknowledgement rolls back Start.
    func acknowledgeReconnect() throws {
        guard let reconnectGuard, let journal else { return }
        try verifyAttachment()
        try journal.acknowledgeReconnectGuard(reconnectGuard)
        self.reconnectGuard = nil
    }

    func attachmentHasEnded() throws -> Bool {
        guard let attachment else { return false }
        return try Self.attachmentHasEnded(attachment)
    }

    /// Ended attachment records are preserved, never restored onto a new device.
    func retireDisconnected() throws {
        guard let journal, let attachment else { throw DeviceModeRecoveryJournalError.identityChanged }
        try preserveFailedAcknowledgement()
        if let record = try ownedRecord ?? journal.load() {
            guard record.identity == attachment else { throw DeviceModeRecoveryJournalError.identityChanged }
            ownedRecord = record
            try journal.retireDisconnected(record, bootSession: Self.currentBootSession(),
                                           attachmentEnded: { try Self.attachmentHasEnded(attachment) })
            ownedRecord = nil
        } else {
            guard !transaction.needsRestore else { throw DeviceModeRecoveryJournalError.recordChanged }
            try journal.retireUnchangedAttachment(identity: attachment, original: transaction.original,
                                                  bootSession: Self.currentBootSession(),
                                                  attachmentEnded: { try Self.attachmentHasEnded(attachment) })
        }
        journal.close()
    }

    /// Called only after exclusive HID open; diagnostics never attach a journal.
    func attachRecovery(_ journal: DeviceModeRecoveryJournal, collection: HIDCollection) throws {
        self.journal = journal
        attachment = try Self.recoveryIdentity(collection)
        guard let record = try journal.load(), let attachment else { return }
        try verifyAttachment()
        let current = try transaction.read()
        switch try journal.recoveryAction(for: record, identity: attachment, current: current) {
        case .alreadyOriginal: break
        case .restoreOriginal:
            try verifyAttachment()
            try transaction.write(record.original)
        }
        let restored = try transaction.read()
        try verifyAttachment()
        try journal.removeAfterReadback(record, identity: attachment, current: restored)
        // A predecessor's mode 2 must not become this session's original value.
        transaction = try DeviceModeTransaction(read: transaction.read, write: transaction.write)
    }

    static func recoveryIdentity(_ collection: HIDCollection) throws -> DeviceModeRecoveryIdentity {
        guard let physicalID = collection.physicalID, physicalID > 0,
              let rawLocation = integer(collection.device, kIOHIDLocationIDKey),
              let location = UInt32(exactly: rawLocation), location > 0,
              let descriptor = IOHIDDeviceGetProperty(collection.device, kIOHIDReportDescriptorKey as CFString) as? Data,
              !descriptor.isEmpty else { throw DeviceModeRecoveryJournalError.identityChanged }
        return DeviceModeRecoveryIdentity(bootSession: try currentBootSession(), hidRegistryID: collection.registryID,
            usbRegistryID: physicalID, locationID: location,
            descriptorSHA256: SHA256.hash(data: descriptor).map { String(format: "%02x", $0) }.joined())
    }

    static func currentBootSession() throws -> String {
        var size = 0
        guard sysctlbyname("kern.bootsessionuuid", nil, &size, nil, 0) == 0, size > 1 else {
            throw DeviceModeRecoveryJournalError.identityChanged
        }
        var boot = [CChar](repeating: 0, count: size)
        guard sysctlbyname("kern.bootsessionuuid", &boot, &size, nil, 0) == 0 else {
            throw DeviceModeRecoveryJournalError.identityChanged
        }
        return String(cString: boot)
    }

    static func attachmentHasEnded(_ identity: DeviceModeRecoveryIdentity) throws -> Bool {
        guard try currentBootSession() == identity.bootSession else {
            throw DeviceModeRecoveryJournalError.identityChanged
        }
        // Successful empty matching proves that this registered active service
        // ended; failure or an invalid iterator proves neither presence nor absence.
        func isActive(_ id: UInt64) throws -> Bool {
            guard let matching = IORegistryEntryIDMatching(id) else {
                throw DeviceModeRecoveryJournalError.identityChanged
            }
            var iterator: io_iterator_t = 0
            let result = IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator)
            guard result == KERN_SUCCESS else { throw ProofError.modeRestoreFailed(result) }
            guard iterator != 0 else { return false }
            defer { IOObjectRelease(iterator) }
            let service = IOIteratorNext(iterator)
            if service != 0 { IOObjectRelease(service); return true }
            guard IOIteratorIsValid(iterator) != 0 else {
                throw DeviceModeRecoveryJournalError.identityChanged
            }
            return false
        }
        let hidActive = try isActive(identity.hidRegistryID)
        let usbActive = try isActive(identity.usbRegistryID)
        return !hidActive && !usbActive
    }

    private func verifyAttachment() throws {
        guard let attachment else { return }
        let scan = HIDDiscovery.scan()
        guard scan.queryReturnedSet, scan.devices.count == 1, let device = scan.devices.first,
              device.canMap, device.usableCollections.count == 1,
              let collection = device.usableCollections.first,
              try Self.recoveryIdentity(collection) == attachment else {
            throw DeviceModeRecoveryJournalError.identityChanged
        }
    }

    func restore() throws {
        do {
            try preserveFailedAcknowledgement()
            if ownedRecord == nil, let journal, journal.hasOwnedActiveRecord {
                guard let record = try journal.ownedActiveRecord() else {
                    throw DeviceModeRecoveryJournalError.recordChanged
                }
                ownedRecord = record
            }
            guard needsRestore else { journal?.close(); return }
            try verifyAttachment()
            if journal != nil {
                let current = try transaction.read()
                guard current.identifier == 0, current.mode == 0 || current.mode == 2 else {
                    throw DeviceModeRecoveryJournalError.unexpectedState
                }
            }
            try transaction.restore()
            if let ownedRecord, let journal, let attachment {
                let restored = try transaction.read()
                try verifyAttachment()
                try journal.removeAfterReadback(ownedRecord, identity: attachment, current: restored)
                self.ownedRecord = nil
            }
            journal?.close()
        } catch let error as DeviceModeRecoveryJournalError {
            throw error
        } catch let error as ProofError {
            switch error {
            case .modeReadFailed(let result), .modeWriteFailed(let result):
                throw ProofError.modeRestoreFailed(result)
            default:
                throw ProofError.modeRestoreFailed(kIOReturnError)
            }
        } catch {
            throw ProofError.modeRestoreFailed(kIOReturnError)
        }
    }

    private func preserveFailedAcknowledgement() throws {
        guard let reconnectGuard, let journal, journal.hasPendingReconnectAcknowledgement else { return }
        try journal.preserveReconnectGuardAfterFailedAcknowledgement(reconnectGuard)
        self.reconnectGuard = nil
    }

    private static func write(device: IOHIDDevice, mode: IOHIDElement,
                              identifier: IOHIDElement, pair: DeviceModeTransaction.Pair) throws {
        let timestamp = mach_absolute_time()
        let modeValue = IOHIDValueCreateWithIntegerValue(kCFAllocatorDefault, mode, timestamp, pair.mode)
        let identifierValue = IOHIDValueCreateWithIntegerValue(kCFAllocatorDefault, identifier, timestamp, pair.identifier)
        let values = [mode: modeValue, identifier: identifierValue] as CFDictionary
        let result = IOHIDDeviceSetValueMultiple(device, values)
        guard result == kIOReturnSuccess else { throw ProofError.modeWriteFailed(result) }
    }

    private static func read(device: IOHIDDevice, element: IOHIDElement) throws -> Int {
        let pointer = UnsafeMutablePointer<Unmanaged<IOHIDValue>>.allocate(capacity: 1)
        defer { pointer.deallocate() }
        let result = IOHIDDeviceGetValueWithOptions(device, element, pointer,
            IOHIDDeviceGetValueOptions.withUpdate.rawValue)
        guard result == kIOReturnSuccess else { throw ProofError.modeReadFailed(result) }
        return IOHIDValueGetIntegerValue(pointer.pointee.takeUnretainedValue())
    }

    private static func integer(_ device: IOHIDDevice, _ key: String) -> Int? {
        (IOHIDDeviceGetProperty(device, key as CFString) as? NSNumber)?.intValue
    }
}
