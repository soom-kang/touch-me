import Foundation
import CoreGraphics
import ColorSync
import ApplicationServices
import IOKit.hid
import TouchMappingCore

public struct DisplayTarget {
    public let id: CGDirectDisplayID
    public let bounds: CGRect
    public let builtIn: Bool
    public let mirrored: Bool
    public let rotated: Bool
    public let persistentUUID: String?
    public var canMap: Bool { !builtIn && !mirrored && !rotated && !bounds.isEmpty && !bounds.isNull }
    public var rect: ScreenRect {
        ScreenRect(x: bounds.minX, y: bounds.minY, width: bounds.width, height: bounds.height)
    }
    public func matchesConfiguration(of other: DisplayTarget) -> Bool {
        persistentUUID != nil && persistentUUID == other.persistentUUID
            && bounds == other.bounds && builtIn == other.builtIn
            && mirrored == other.mirrored && rotated == other.rotated
    }
    public var label: String {
        "Display \(id) · \(Int(bounds.width)) × \(Int(bounds.height))\(builtIn ? " · built-in" : "")"
    }
}

public enum DisplayDiscovery {
    public static func sleepState(for persistentUUID: String) -> Bool? {
        var count: UInt32 = 0
        guard CGGetOnlineDisplayList(0, nil, &count) == .success else { return nil }
        var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
        guard CGGetOnlineDisplayList(count, &ids, &count) == .success else { return nil }
        let matching = ids.prefix(Int(count)).filter { displayUUID($0) == persistentUUID }
        guard matching.count == 1, let id = matching.first else { return nil }
        return CGDisplayIsAsleep(id) != 0
    }

    public static func scan() -> [DisplayTarget] {
        var count: UInt32 = 0
        guard CGGetActiveDisplayList(0, nil, &count) == .success else { return [] }
        var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
        guard CGGetActiveDisplayList(count, &ids, &count) == .success else { return [] }
        return ids.prefix(Int(count)).map { id in
            DisplayTarget(id: id, bounds: CGDisplayBounds(id), builtIn: CGDisplayIsBuiltin(id) != 0,
                          mirrored: CGDisplayIsInMirrorSet(id) != 0,
                          rotated: abs(CGDisplayRotation(id)) > 0.001,
                          persistentUUID: displayUUID(id))
        }
    }

    private static func displayUUID(_ id: CGDirectDisplayID) -> String? {
        guard let uuid = CGDisplayCreateUUIDFromDisplayID(id)?.takeRetainedValue(),
              let value = CFUUIDCreateString(kCFAllocatorDefault, uuid) else { return nil }
        return value as String
    }
}

public struct PermissionState: Codable {
    public let inputMonitoring: Bool
    public let accessibility: Bool
    public var canMap: Bool { inputMonitoring && accessibility }
    public static func current() -> PermissionState {
        PermissionState(inputMonitoring: IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) == kIOHIDAccessTypeGranted,
                        accessibility: AXIsProcessTrusted())
    }
}
