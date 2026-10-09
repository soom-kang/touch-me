import Foundation
import IOKit.hid
import Darwin

/// Uses the mapper's already-open device and restores the verified original pair.
final class P16KTDeviceMode {
    private let locationID: Int
    private let transaction: DeviceModeTransaction
    var needsRestore: Bool { transaction.needsRestore }

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
        Self.integer(collection.device, kIOHIDLocationIDKey) == locationID
    }

    func rebind(to collection: HIDCollection) throws {
        guard Self.integer(collection.device, kIOHIDLocationIDKey) == locationID else {
            throw ProofError.modeUnsupported
        }
        let replacement = try P16KTDeviceMode(collection: collection)
        // Replace stale handles only; preserve the original pair and pending recovery.
        transaction.read = replacement.transaction.read
        transaction.write = replacement.transaction.write
    }

    func enable() throws {
        try transaction.enable()
    }

    func restore() throws {
        do {
            try transaction.restore()
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
