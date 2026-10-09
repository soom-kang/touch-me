import Foundation
import IOKit
import IOKit.hid
import OSLog
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
    fileprivate let descriptorVerified: Bool
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
        HIDMappingEligibility.canMap(groupingVerified: groupingVerified, collections: collections.map {
            HIDMappingEligibility.Collection(descriptorVerified: $0.descriptorVerified, isPointer: $0.isPointer,
                                             contactCount: $0.contacts.count, hasKeyboardElements: $0.hasKeyboardElements)
        })
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
    private static let recoveryLog = Logger(subsystem: "io.github.soom-kang.touchme", category: "MappingRecovery")

    private struct DeviceMetadata {
        let device: IOHIDDevice
        let registryID: UInt64
        let physicalID: UInt64?
        let vendor: Int
        let product: Int
        let usagePage: Int
        let usage: Int
        let hasTouchScreen: Bool?
        let hasMouse: Bool?
        var groupKey: String {
            "\(vendor):\(product):\(physicalID.map(String.init) ?? "unverified-\(registryID)")"
        }
    }

    public static func scan() -> HIDScan {
        let startedAt = ProcessInfo.processInfo.systemUptime
        func phase(_ name: String, count: Int = 0) {
            recoveryLog.notice("HID discovery \(name, privacy: .public), elapsed \(ProcessInfo.processInfo.systemUptime - startedAt, format: .fixed(precision: 3))s, count \(count)")
        }
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        phase("manager_created")
        // Discovery only: do not open or schedule this manager.
        IOHIDManagerSetDeviceMatching(manager, [kIOHIDTransportKey: "USB"] as CFDictionary)
        phase("matching_finished")
        guard let set = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice> else {
            phase("copy_devices_failed")
            return HIDScan(devices: [], queryReturnedSet: false)
        }
        phase("copy_devices_finished", count: set.count)
        let metadata = set.compactMap(readMetadata)
        phase("metadata_finished", count: metadata.count)

        var described: [UInt64: HIDCollection] = [:]
        var candidateKeys: Set<String> = []
        // UsagePairs covers every device behavior; PrimaryUsage can hide a composite touchscreen.
        // Missing or malformed metadata falls back to the complete descriptor.
        for item in metadata where item.hasTouchScreen != false {
            let collection = describe(item)
            described[item.registryID] = collection
            if item.hasTouchScreen == true || collection.hasTouchScreen {
                candidateKeys.insert(item.groupKey)
            }
        }
        // Keep every sibling, including keyboard and mouse interfaces, in the safety checks.
        for item in metadata where candidateKeys.contains(item.groupKey) && described[item.registryID] == nil {
            described[item.registryID] = describe(item)
        }
        phase("full_descriptors_finished", count: described.count)
        let collections = metadata.compactMap { item -> HIDCollection? in
            candidateKeys.contains(item.groupKey) ? described[item.registryID] : nil
        }
        let grouped = Dictionary(grouping: collections, by: groupKey)
        let devices = grouped.compactMap { key, group -> TouchDevice? in
            guard let first = group.first else { return nil }
            return TouchDevice(key: key, vendor: first.vendor, product: first.product,
                               collections: group.sorted { $0.registryID < $1.registryID },
                               groupingVerified: group.allSatisfy { $0.physicalID != nil })
        }.sorted { $0.key < $1.key }
        phase("finished", count: devices.count)
        return HIDScan(devices: devices, queryReturnedSet: true)
    }

    private static func groupKey(_ c: HIDCollection) -> String {
        "\(c.vendor):\(c.product):\(c.physicalID.map(String.init) ?? "unverified-\(c.registryID)")"
    }

    private static func integer(_ d: IOHIDDevice, _ key: String) -> Int {
        (IOHIDDeviceGetProperty(d, key as CFString) as? NSNumber)?.intValue ?? -1
    }

    private static func readMetadata(_ device: IOHIDDevice) -> DeviceMetadata? {
        guard (IOHIDDeviceGetProperty(device, kIOHIDTransportKey as CFString) as? String)?
            .caseInsensitiveCompare("USB") == .orderedSame else { return nil }
        let vendor = integer(device, kIOHIDVendorIDKey), product = integer(device, kIOHIDProductIDKey)
        guard vendor > 0, product >= 0 else { return nil }
        let service = IOHIDDeviceGetService(device)
        var registryID: UInt64 = 0
        guard service != 0, IORegistryEntryGetRegistryEntryID(service, &registryID) == KERN_SUCCESS else { return nil }
        let usages = usagePairs(device)
        return DeviceMetadata(device: device, registryID: registryID, physicalID: usbAncestor(service),
                              vendor: vendor, product: product,
                              usagePage: integer(device, kIOHIDPrimaryUsagePageKey),
                              usage: integer(device, kIOHIDPrimaryUsageKey),
                              hasTouchScreen: usages.map { $0.contains { $0.page == 0x0D && $0.usage == 0x04 } },
                              hasMouse: usages.map { $0.contains { $0.page == 0x01 && $0.usage == 0x02 } })
    }

    private static func usagePairs(_ device: IOHIDDevice) -> [(page: UInt32, usage: UInt32)]? {
        guard let pairs = IOHIDDeviceGetProperty(device, kIOHIDDeviceUsagePairsKey as CFString) as? [[String: Any]],
              !pairs.isEmpty else { return nil }
        var usages: [(page: UInt32, usage: UInt32)] = []
        for pair in pairs {
            guard let page = pair[kIOHIDDeviceUsagePageKey] as? NSNumber,
                  let usage = pair[kIOHIDDeviceUsageKey] as? NSNumber,
                  CFGetTypeID(page) == CFNumberGetTypeID(), CFGetTypeID(usage) == CFNumberGetTypeID() else { return nil }
            let pageValue = page.int64Value, usageValue = usage.int64Value
            guard pageValue >= 0, pageValue <= Int64(UInt32.max),
                  usageValue >= 0, usageValue <= Int64(UInt32.max),
                  page.doubleValue == Double(pageValue), usage.doubleValue == Double(usageValue) else { return nil }
            usages.append((UInt32(pageValue), UInt32(usageValue)))
        }
        return usages
    }

    private static func conforms(_ elements: [IOHIDElement], page: UInt32, usage: UInt32) -> Bool {
        elements.contains {
            guard IOHIDElementGetType($0) == kIOHIDElementTypeCollection,
                  IOHIDElementGetUsagePage($0) == page, IOHIDElementGetUsage($0) == usage else { return false }
            let type = IOHIDElementGetCollectionType($0)
            return type == kIOHIDElementCollectionTypeApplication || type == kIOHIDElementCollectionTypePhysical
        }
    }

    private static func describe(_ metadata: DeviceMetadata) -> HIDCollection {
        let device = metadata.device, registryID = metadata.registryID
        let elements = IOHIDDeviceCopyMatchingElements(device, nil, 0) as? [IOHIDElement] ?? []
        var touchScreen = conforms(elements, page: 0x0D, usage: 0x04)
        var mouse = conforms(elements, page: 0x01, usage: 0x02)
        let descriptorVerified = !elements.isEmpty
            && (metadata.hasTouchScreen != true || touchScreen)
            && (metadata.hasMouse != true || mouse)
        if elements.isEmpty {
            // Preserve legacy classification if the full query failed but a filtered query succeeds.
            // Metadata-confirmed panels remain candidates; incomplete descriptors never authorize mapping.
            touchScreen = metadata.hasTouchScreen ?? IOHIDDeviceConformsTo(device, 0x0D, 0x04)
            mouse = metadata.hasMouse ?? IOHIDDeviceConformsTo(device, 0x01, 0x02)
        }
        let keyboard = elements.contains { IOHIDElementGetUsagePage($0) == 0x07 }
        let input = elements.filter {
            let type = IOHIDElementGetType($0)
            return type == kIOHIDElementTypeInput_Misc || type == kIOHIDElementTypeInput_Button || type == kIOHIDElementTypeInput_Axis
        }
        var groups = Dictionary(grouping: input, by: contactCookie)
        let fingerCookies = Set(elements.filter {
            IOHIDElementGetType($0) == kIOHIDElementTypeCollection
                && IOHIDElementGetUsagePage($0) == 0x0D && IOHIDElementGetUsage($0) == 0x22
        }.map { IOHIDElementGetCookie($0) })
        // Empty Finger collections are incomplete too; do not silently drop them.
        for cookie in fingerCookies where groups[cookie] == nil { groups[cookie] = [] }
        func isAxis(_ element: IOHIDElement, usage: UInt32) -> Bool {
            IOHIDElementGetUsagePage(element) == 0x01 && IOHIDElementGetUsage(element) == usage
        }
        func isTip(_ element: IOHIDElement) -> Bool {
            (IOHIDElementGetUsagePage(element) == 0x0D && IOHIDElementGetUsage(element) == 0x42)
                || (IOHIDElementGetUsagePage(element) == 0x09 && IOHIDElementGetUsage(element) == 1)
        }
        func axisEvidence(_ element: IOHIDElement) -> HIDContactLayout.Axis {
            HIDContactLayout.Axis(range: AxisRange(minimum: IOHIDElementGetLogicalMin(element),
                                                   maximum: IOHIDElementGetLogicalMax(element)),
                                  isRelative: IOHIDElementIsRelative(element))
        }
        let layout = groups.map { cookie, group in
            HIDContactLayout.Group(cookie: cookie, isFinger: fingerCookies.contains(cookie),
                x: group.filter { isAxis($0, usage: 0x30) }.map(axisEvidence),
                y: group.filter { isAxis($0, usage: 0x31) }.map(axisEvidence),
                tipCount: group.filter(isTip).count,
                hasDigitizerTip: group.contains {
                    IOHIDElementGetUsagePage($0) == 0x0D && IOHIDElementGetUsage($0) == 0x42
                })
        }
        let verifiedCookies = HIDContactLayout.validatedCookies(layout)
        var contacts: [ContactElements] = []
        for cookie in verifiedCookies ?? [] {
            guard let group = groups[cookie],
                  let x = group.first(where: { isAxis($0, usage: 0x30) }),
                  let y = group.first(where: { isAxis($0, usage: 0x31) }),
                  let tip = group.first(where: isTip) else { continue }
            contacts.append(ContactElements(x: x, y: y, tip: tip, key: "\(registryID):\(cookie)",
                                             isDigitizer: IOHIDElementGetUsagePage(tip) == 0x0D))
        }
        return HIDCollection(device: device, registryID: registryID, physicalID: metadata.physicalID,
                             vendor: metadata.vendor, product: metadata.product, usagePage: metadata.usagePage,
                             usage: metadata.usage, contacts: contacts.sorted { $0.key < $1.key },
                             hasKeyboardElements: keyboard,
                             hasTouchScreen: touchScreen, hasMouse: mouse,
                             descriptorVerified: descriptorVerified && verifiedCookies != nil)
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
