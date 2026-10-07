import Foundation
import IOKit
import IOKit.hid
import TouchMappingCore

public struct ContactElements {
    public let x: IOHIDElement
    public let y: IOHIDElement
    public let tip: IOHIDElement
    public let key: String
    public let isDigitizer: Bool
    public var xRange: AxisRange {
        AxisRange(minimum: IOHIDElementGetLogicalMin(x), maximum: IOHIDElementGetLogicalMax(x))
    }
    public var yRange: AxisRange {
        AxisRange(minimum: IOHIDElementGetLogicalMin(y), maximum: IOHIDElementGetLogicalMax(y))
    }
}

public struct HIDCollection {
    public let device: IOHIDDevice
    public let registryID: UInt64
    public let physicalID: UInt64?
    public let vendor: Int
    public let product: Int
    public let usagePage: Int
    public let usage: Int
    public let contacts: [ContactElements]
    public let hasKeyboardElements: Bool
    public let hasTouchScreen: Bool
    public let hasMouse: Bool
    public var isPointer: Bool { hasTouchScreen || hasMouse }
}

public struct TouchDevice {
    public let key: String
    public let vendor: Int
    public let product: Int
    public let collections: [HIDCollection]
    public let groupingVerified: Bool
    public var usableCollections: [HIDCollection] { collections.filter { $0.isPointer && !$0.contacts.isEmpty } }
    public var locationID: UInt32? {
        guard canMap else { return nil }
        let locations = usableCollections.map {
            (IOHIDDeviceGetProperty($0.device, kIOHIDLocationIDKey as CFString) as? NSNumber)?.int64Value
        }
        guard let first = locations.first ?? nil, first > 0, first <= Int64(UInt32.max),
              locations.allSatisfy({ $0 == first }) else { return nil }
        return UInt32(first)
    }
    public var canMap: Bool {
        let pointerCollections = collections.filter { $0.isPointer }
        return groupingVerified && !pointerCollections.isEmpty
            && pointerCollections.allSatisfy { !$0.contacts.isEmpty }
            && !collections.contains { $0.hasKeyboardElements }
    }
    public var label: String { String(format: "USB touch · VID %04X / PID %04X", vendor, product) }
}

public struct DeviceEvidence: Codable {
    public let vendorID: String
    public let productID: String
    public let physicalGroupingVerified: Bool
    public let canStartProof: Bool
    public let collections: [CollectionEvidence]
}

public struct CollectionEvidence: Codable {
    public let usagePage: Int
    public let usage: Int
    public let absoluteContacts: [ContactEvidence]
}

public struct ContactEvidence: Codable {
    public let x: AxisRange
    public let y: AxisRange
    public let tipUsagePage: Int
    public let tipUsage: Int
}

public struct HIDScan {
    public let devices: [TouchDevice]
    public let queryReturnedSet: Bool
    public var evidence: [DeviceEvidence] {
        devices.map { d in
            DeviceEvidence(vendorID: String(format: "0x%04X", d.vendor),
                           productID: String(format: "0x%04X", d.product),
                           physicalGroupingVerified: d.groupingVerified, canStartProof: d.canMap,
                           collections: d.collections.map { c in
                CollectionEvidence(usagePage: c.usagePage, usage: c.usage,
                                   absoluteContacts: c.contacts.map { e in
                    ContactEvidence(x: e.xRange, y: e.yRange,
                                    tipUsagePage: Int(IOHIDElementGetUsagePage(e.tip)),
                                    tipUsage: Int(IOHIDElementGetUsage(e.tip)))
                })
            })
        }
    }
}

public enum HIDDiscovery {
    public static func scan() -> HIDScan {
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        // Discovery only: do not open or schedule this manager.
        IOHIDManagerSetDeviceMatching(manager, [kIOHIDTransportKey: "USB"] as CFDictionary)
        guard let set = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice> else {
            return HIDScan(devices: [], queryReturnedSet: false)
        }
        let collections = set.compactMap(describe)
        let candidateKeys = Set(collections.filter { $0.hasTouchScreen }
            .map(groupKey))
        let grouped = Dictionary(grouping: collections.filter { candidateKeys.contains(groupKey($0)) }, by: groupKey)
        let devices = grouped.compactMap { key, group -> TouchDevice? in
            guard let first = group.first else { return nil }
            return TouchDevice(key: key, vendor: first.vendor, product: first.product,
                               collections: group.sorted { $0.registryID < $1.registryID },
                               groupingVerified: group.allSatisfy { $0.physicalID != nil })
        }.sorted { $0.key < $1.key }
        return HIDScan(devices: devices, queryReturnedSet: true)
    }

    private static func groupKey(_ c: HIDCollection) -> String {
        "\(c.vendor):\(c.product):\(c.physicalID.map(String.init) ?? "unverified-\(c.registryID)")"
    }

    private static func integer(_ d: IOHIDDevice, _ key: String) -> Int {
        (IOHIDDeviceGetProperty(d, key as CFString) as? NSNumber)?.intValue ?? -1
    }

    private static func describe(_ device: IOHIDDevice) -> HIDCollection? {
        guard (IOHIDDeviceGetProperty(device, kIOHIDTransportKey as CFString) as? String)?
            .caseInsensitiveCompare("USB") == .orderedSame else { return nil }
        let vendor = integer(device, kIOHIDVendorIDKey), product = integer(device, kIOHIDProductIDKey)
        guard vendor > 0, product >= 0 else { return nil }
        let service = IOHIDDeviceGetService(device)
        var registryID: UInt64 = 0
        guard service != 0, IORegistryEntryGetRegistryEntryID(service, &registryID) == KERN_SUCCESS else { return nil }
        let elements = IOHIDDeviceCopyMatchingElements(device, nil, 0) as? [IOHIDElement] ?? []
        let keyboard = elements.contains { IOHIDElementGetUsagePage($0) == 0x07 }
        let input = elements.filter {
            let type = IOHIDElementGetType($0)
            return type == kIOHIDElementTypeInput_Misc || type == kIOHIDElementTypeInput_Button || type == kIOHIDElementTypeInput_Axis
        }
        let groups = Dictionary(grouping: input, by: contactCookie)
        var contacts: [ContactElements] = []
        for (cookie, group) in groups {
            let xs = group.filter { IOHIDElementGetUsagePage($0) == 0x01 && IOHIDElementGetUsage($0) == 0x30 && !IOHIDElementIsRelative($0) }
            let ys = group.filter { IOHIDElementGetUsagePage($0) == 0x01 && IOHIDElementGetUsage($0) == 0x31 && !IOHIDElementIsRelative($0) }
            let tips = group.filter {
                (IOHIDElementGetUsagePage($0) == 0x0D && IOHIDElementGetUsage($0) == 0x42)
                    || (IOHIDElementGetUsagePage($0) == 0x09 && IOHIDElementGetUsage($0) == 1)
            }
            // Ambiguous descriptors are rejected, rather than guessing a finger.
            guard xs.count == 1, ys.count == 1, tips.count == 1, cookie != 0 else { continue }
            let e = ContactElements(x: xs[0], y: ys[0], tip: tips[0], key: "\(registryID):\(cookie)",
                                    isDigitizer: IOHIDElementGetUsagePage(tips[0]) == 0x0D)
            if e.xRange.isValid && e.yRange.isValid { contacts.append(e) }
        }
        return HIDCollection(device: device, registryID: registryID, physicalID: usbAncestor(service),
                             vendor: vendor, product: product, usagePage: integer(device, kIOHIDPrimaryUsagePageKey),
                             usage: integer(device, kIOHIDPrimaryUsageKey), contacts: contacts.sorted { $0.key < $1.key },
                             hasKeyboardElements: keyboard,
                             hasTouchScreen: IOHIDDeviceConformsTo(device, 0x0D, 0x04),
                             hasMouse: IOHIDDeviceConformsTo(device, 0x01, 0x02))
    }

    private static func contactCookie(_ element: IOHIDElement) -> UInt32 {
        var parent = IOHIDElementGetParent(element)
        var outermost: UInt32 = 0
        while let current = parent {
            outermost = IOHIDElementGetCookie(current)
            if IOHIDElementGetUsagePage(current) == 0x0D && IOHIDElementGetUsage(current) == 0x22 {
                return outermost // Digitizer Finger collection.
            }
            parent = IOHIDElementGetParent(current)
        }
        return outermost
    }

    private static func usbAncestor(_ service: io_service_t) -> UInt64? {
        var current = service
        IOObjectRetain(current)
        defer { IOObjectRelease(current) }
        for _ in 0..<24 {
            if IOObjectConformsTo(current, "IOUSBHostDevice") != 0 || IOObjectConformsTo(current, "IOUSBDevice") != 0 {
                var id: UInt64 = 0
                return IORegistryEntryGetRegistryEntryID(current, &id) == KERN_SUCCESS ? id : nil
            }
            var parent: io_registry_entry_t = 0
            guard IORegistryEntryGetParentEntry(current, kIOServicePlane, &parent) == KERN_SUCCESS else { return nil }
            IOObjectRelease(current)
            current = parent
        }
        return nil
    }
}
