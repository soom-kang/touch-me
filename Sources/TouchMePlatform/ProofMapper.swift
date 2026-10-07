import Foundation
import AppKit
import IOKit
import IOKit.hid
import CoreGraphics
import TouchMappingCore

public enum ProofError: Error, LocalizedError {
    case missingPermissions, unsupportedDevice, unsupportedDisplay, deviceChanged
    case openFailed(IOReturn), readFailed(IOReturn), eventCreationFailed
    case modeUnsupported, modeStateUnexpected, modeReadFailed(IOReturn)
    case modeWriteFailed(IOReturn), modeReadbackMismatch, modeRestoreFailed(IOReturn)

    public var errorDescription: String? {
        switch self {
        case .missingPermissions: return "Both Input Monitoring and Accessibility are required."
        case .unsupportedDevice: return "USB physical grouping or absolute contact descriptor could not be verified."
        case .unsupportedDisplay: return "Select an external display with no rotation or mirroring."
        case .deviceChanged: return "The selected touch device or display changed. Refresh and try again."
        case .openFailed(let rc): return String(format: "Exclusive open failed (0x%08X). Check permission or another mapper.", UInt32(bitPattern: rc))
        case .readFailed(let rc): return String(format: "Contact state read failed (0x%08X).", UInt32(bitPattern: rc))
        case .eventCreationFailed: return "A mouse event could not be created. Mapping stopped."
        case .modeUnsupported: return "The verified P16KT multitouch feature layout was not found."
        case .modeStateUnexpected: return "The device mode or identifier is outside the verified starting states."
        case .modeReadFailed(let rc): return String(format: "Device mode read failed (0x%08X).", UInt32(bitPattern: rc))
        case .modeWriteFailed(let rc): return String(format: "Multitouch mode change failed (0x%08X).", UInt32(bitPattern: rc))
        case .modeReadbackMismatch: return "Multitouch mode readback did not match. Mapping did not start."
        case .modeRestoreFailed(let rc): return String(format: "Original device mode could not be restored (0x%08X). Reconnect the P16KT to the same USB port and retry restoration.", UInt32(bitPattern: rc))
        }
    }
    public var code: String {
        switch self {
        case .missingPermissions: return "permissions_missing"
        case .unsupportedDevice: return "descriptor_unsupported"
        case .unsupportedDisplay: return "display_unsupported"
        case .deviceChanged: return "target_changed"
        case .openFailed(let rc): return String(format: "open_0x%08X", UInt32(bitPattern: rc))
        case .readFailed(let rc): return String(format: "read_0x%08X", UInt32(bitPattern: rc))
        case .eventCreationFailed: return "event_creation_failed"
        case .modeUnsupported: return "mode_descriptor_unsupported"
        case .modeStateUnexpected: return "mode_state_unexpected"
        case .modeReadFailed(let rc): return String(format: "mode_read_0x%08X", UInt32(bitPattern: rc))
        case .modeWriteFailed(let rc): return String(format: "mode_write_0x%08X", UInt32(bitPattern: rc))
        case .modeReadbackMismatch: return "mode_readback_mismatch"
        case .modeRestoreFailed(let rc): return String(format: "mode_restore_0x%08X", UInt32(bitPattern: rc))
        }
    }
}

private struct ContactState {
    let elements: ContactElements
    var x: Int?
    var y: Int?
    var down = false
    var needsCoordinateRefresh = false
}

/// All methods and callbacks execute on the main run loop.
/// Paired P16KT mode changes are scoped to the exclusive mapping session.
/// No raw reports, raw logging, background daemon or shared-mode fallback.
public final class ProofMapper {
    public private(set) var running = false
    public private(set) var receivedValues = 0
    public private(set) var postedDowns = 0
    public private(set) var postedScrolls = 0
    public private(set) var maximumContacts = 0
    public var modeRestorePending: Bool { deviceMode?.control.needsRestore == true }
    public var onChange: (() -> Void)?
    public var onFailure: ((ProofError) -> Void)?
    private var session = ProofSession()
    private var clickSequence = ClickSequence()
    private var releaseEvent: CGEvent?
    private var opened: [HIDCollection] = []
    private var deviceMode: (collection: HIDCollection, control: P16KTDeviceMode)?
    private var contacts: [String: ContactState] = [:]
    private var elementKeys: [String: String] = [:]
    private var target: DisplayTarget?
    private var watchdog: Timer?
    private var pendingTimestamp: UInt64?
    private var flushScheduled = false
    private var generation = 0
    private var preferDigitizer = false
    private var scrollRemainderX = 0.0
    private var scrollRemainderY = 0.0
    private let loop = CFRunLoopGetMain()!
    private let mode = CFRunLoopMode.commonModes.rawValue

    public init() {}

    public func start(device: TouchDevice, display: DisplayTarget) throws {
        precondition(Thread.isMainThread)
        if let error = stop() { throw error }
        guard PermissionState.current().canMap else { throw ProofError.missingPermissions }
        // Refresh immediately before opening; a saved VID/PID is insufficient.
        let scan = HIDDiscovery.scan()
        guard scan.devices.count == 1, let fresh = scan.devices.first(where: { $0.key == device.key }), fresh.canMap,
              fresh.usableCollections.count == 1 else {
            throw ProofError.unsupportedDevice
        }
        guard let uuid = display.persistentUUID,
              let freshDisplay = DisplayDiscovery.scan().first(where: { $0.id == display.id }),
              freshDisplay.persistentUUID == uuid, freshDisplay.canMap else {
            throw ProofError.unsupportedDisplay
        }
        target = freshDisplay
        receivedValues = 0
        postedDowns = 0
        postedScrolls = 0
        maximumContacts = 0
        let context = Unmanaged.passUnretained(self).toOpaque()
        do {
            for collection in fresh.usableCollections {
                let rc = IOHIDDeviceOpen(collection.device, IOOptionBits(kIOHIDOptionsTypeSeizeDevice))
                guard rc == kIOReturnSuccess else { throw ProofError.openFailed(rc) }
                opened.append(collection)
                let control = try P16KTDeviceMode(collection: collection)
                deviceMode = (collection, control)
                try control.enable()
                for e in collection.contacts {
                    var state = ContactState(elements: e)
                    // Verify an initial tip state; actual coordinates still require callbacks.
                    state.down = try currentValue(for: e.tip) != 0
                    state.needsCoordinateRefresh = state.down
                    contacts[e.key] = state
                    for el in [e.x, e.y, e.tip] {
                        elementKeys["\(collection.registryID):\(IOHIDElementGetCookie(el))"] = e.key
                    }
                }
                IOHIDDeviceRegisterInputValueCallback(collection.device, { context, result, _, value in
                    guard let context else { return }
                    let mapper = Unmanaged<ProofMapper>.fromOpaque(context).takeUnretainedValue()
                    if result != kIOReturnSuccess { mapper.fail(.readFailed(result)); return }
                    mapper.receive(value)
                }, context)
                IOHIDDeviceRegisterRemovalCallback(collection.device, { context, _, _ in
                    guard let context else { return }
                    Unmanaged<ProofMapper>.fromOpaque(context).takeUnretainedValue().fail(.deviceChanged)
                }, context)
                IOHIDDeviceScheduleWithRunLoop(collection.device, loop, mode)
            }
            _ = post(session.start())
            running = true
            if contacts.values.allSatisfy({ !$0.down }) { _ = session.update(points: []) }
            watchdog = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in self?.checkEnvironment() }
            onChange?()
        } catch {
            let restoreError = stop()
            if let restoreError { throw restoreError }
            throw error
        }
    }

    @discardableResult
    public func stop() -> ProofError? {
        precondition(Thread.isMainThread)
        // Release before clearing the target or closing devices, including rollback.
        _ = post(session.stop())
        if let releaseEvent {
            releaseEvent.timestamp = DispatchTime.now().uptimeNanoseconds
            releaseEvent.post(tap: .cghidEventTap)
            self.releaseEvent = nil
        }
        clickSequence.reset()
        running = false
        generation += 1
        watchdog?.invalidate()
        watchdog = nil
        for c in opened {
            IOHIDDeviceRegisterInputValueCallback(c.device, nil, nil)
            IOHIDDeviceRegisterRemovalCallback(c.device, nil, nil)
            IOHIDDeviceUnscheduleFromRunLoop(c.device, loop, mode)
        }
        var restoreError: ProofError?
        if let deviceMode {
            var openedForRestore: IOHIDDevice?
            do {
                if deviceMode.control.needsRestore,
                   !opened.contains(where: { $0.registryID == deviceMode.collection.registryID }) {
                    // A reconnected USB device has a new service and HID handle.
                    // Rebind only one verified panel at the original USB location.
                    let scan = HIDDiscovery.scan()
                    guard scan.devices.count == 1, let fresh = scan.devices.first,
                          fresh.canMap, fresh.vendor == deviceMode.collection.vendor,
                          fresh.product == deviceMode.collection.product,
                          fresh.usableCollections.count == 1,
                          let collection = fresh.usableCollections.first,
                          deviceMode.control.isAtOriginalLocation(collection) else {
                        throw ProofError.modeRestoreFailed(kIOReturnNoDevice)
                    }
                    let rc = IOHIDDeviceOpen(collection.device, IOOptionBits(kIOHIDOptionsTypeSeizeDevice))
                    guard rc == kIOReturnSuccess else { throw ProofError.modeRestoreFailed(rc) }
                    openedForRestore = collection.device
                    try deviceMode.control.rebind(to: collection)
                    self.deviceMode = (collection, deviceMode.control)
                }
                try deviceMode.control.restore()
                self.deviceMode = nil
            } catch let error as ProofError {
                if case .modeRestoreFailed = error { restoreError = error }
                else { restoreError = .modeRestoreFailed(kIOReturnError) }
            } catch {
                restoreError = .modeRestoreFailed(kIOReturnError)
            }
            if let openedForRestore {
                IOHIDDeviceClose(openedForRestore, IOOptionBits(kIOHIDOptionsTypeNone))
            }
        }
        for c in opened {
            IOHIDDeviceClose(c.device, IOOptionBits(kIOHIDOptionsTypeNone))
        }
        opened.removeAll()
        contacts.removeAll()
        elementKeys.removeAll()
        target = nil
        pendingTimestamp = nil
        flushScheduled = false
        preferDigitizer = false
        scrollRemainderX = 0
        scrollRemainderY = 0
        onChange?()
        return restoreError
    }

    private func receive(_ value: IOHIDValue) {
        guard running else { return }
        let el = IOHIDValueGetElement(value)
        let device = IOHIDElementGetDevice(el)
        var id: UInt64 = 0
        guard IORegistryEntryGetRegistryEntryID(IOHIDDeviceGetService(device), &id) == KERN_SUCCESS,
              let key = elementKeys["\(id):\(IOHIDElementGetCookie(el))"], var state = contacts[key] else { return }
        let timestamp = IOHIDValueGetTimeStamp(value)
        if let pendingTimestamp, pendingTimestamp != timestamp { flush() }
        guard running else { return }
        self.pendingTimestamp = timestamp
        let number = IOHIDValueGetIntegerValue(value)
        switch IOHIDElementGetCookie(el) {
        case IOHIDElementGetCookie(state.elements.x): state.x = number
        case IOHIDElementGetCookie(state.elements.y): state.y = number
        case IOHIDElementGetCookie(state.elements.tip):
            let down = number != 0
            if down && !state.down { state.needsCoordinateRefresh = true }
            state.down = down
        default: return
        }
        contacts[key] = state
        receivedValues += 1
        if !flushScheduled {
            flushScheduled = true
            let currentGeneration = generation
            DispatchQueue.main.async { [weak self] in
                guard let self, self.generation == currentGeneration else { return }
                self.flushScheduled = false
                self.flush()
            }
        }
    }

    private func flush() {
        guard running, let target else { return }
        guard PermissionState.current().canMap else { fail(.missingPermissions); return }
        // Reused slots must start from the driver's last reported position, not
        // this app's previous gesture. Unchanged axes may have no new callback.
        do {
            for key in Array(contacts.keys) {
                guard var state = contacts[key], state.down, state.needsCoordinateRefresh else { continue }
                state.x = try currentValue(for: state.elements.x)
                state.y = try currentValue(for: state.elements.y)
                state.needsCoordinateRefresh = false
                contacts[key] = state
            }
        } catch let error as ProofError {
            fail(error)
            return
        } catch {
            fail(.readFailed(kIOReturnError))
            return
        }
        let downs = contacts.values.filter(\.down)
        let digitizer = downs.filter { $0.elements.isDigitizer }
        if !digitizer.isEmpty { preferDigitizer = true }
        if downs.isEmpty { preferDigitizer = false }
        let active = preferDigitizer ? digitizer : downs
        if !downs.isEmpty && active.count != 1 { clickSequence.cancelTap() }
        maximumContacts = max(maximumContacts, active.count)
        if active.count != 2 {
            scrollRemainderX = 0
            scrollRemainderY = 0
        }
        // Unknown X/Y abort this gesture until all fingers lift.
        // Never fabricate a zero coordinate from the descriptor's logical minimum.
        if active.contains(where: { $0.x == nil || $0.y == nil }) {
            clickSequence.cancelTap()
            scrollRemainderX = 0
            scrollRemainderY = 0
            _ = post(session.rejectContact())
            onChange?()
            return
        }
        let points = active.compactMap { state -> MappedPoint? in
            guard let x = state.x, let y = state.y else { return nil }
            return CoordinateMapper.map(x: x, y: y, xRange: state.elements.xRange, yRange: state.elements.yRange, to: target.rect)
        }
        if points.count != active.count { clickSequence.cancelTap() }
        guard post(session.update(points: points), completedTap: downs.isEmpty) else { fail(.eventCreationFailed); return }
        onChange?()
    }

    private func currentValue(for element: IOHIDElement) throws -> Int {
        let valuePointer = UnsafeMutablePointer<Unmanaged<IOHIDValue>>.allocate(capacity: 1)
        defer { valuePointer.deallocate() }
        let rc = IOHIDDeviceGetValue(IOHIDElementGetDevice(element), element, valuePointer)
        guard rc == kIOReturnSuccess else { throw ProofError.readFailed(rc) }
        return IOHIDValueGetIntegerValue(valuePointer.pointee.takeUnretainedValue())
    }

    @discardableResult
    private func post(_ actions: [ProofAction], completedTap: Bool = false) -> Bool {
        for action in actions {
            if case .scroll(let dx, let dy, let point) = action {
                clickSequence.cancelTap()
                scrollRemainderX += dx
                scrollRemainderY += dy
                guard scrollRemainderX.isFinite, scrollRemainderY.isFinite else { return false }
                let sx = Int32(min(max(scrollRemainderX.rounded(), Double(Int32.min)), Double(Int32.max)))
                let sy = Int32(min(max(scrollRemainderY.rounded(), Double(Int32.min)), Double(Int32.max)))
                guard sx != 0 || sy != 0 else { continue }
                let position = CGPoint(x: point.x, y: point.y)
                guard let event = CGEvent(scrollWheelEvent2Source: nil, units: .pixel,
                                          wheelCount: 2, wheel1: sy, wheel2: sx, wheel3: 0),
                      let movement = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved,
                                             mouseCursorPosition: position, mouseButton: .left) else { return false }
                event.location = position
                // Keep the live pointer on the touch target without a preceding tap.
                movement.post(tap: .cghidEventTap)
                event.post(tap: .cghidEventTap)
                scrollRemainderX -= Double(sx)
                scrollRemainderY -= Double(sy)
                postedScrolls += 1
                continue
            }
            scrollRemainderX = 0
            scrollRemainderY = 0
            let type: CGEventType
            let point: MappedPoint
            switch action {
            case .down(let p): type = .leftMouseDown; point = p
            case .drag(let p):
                clickSequence.move(to: p)
                type = .leftMouseDragged; point = p
            case .up(let p): type = .leftMouseUp; point = p
            case .scroll: continue
            }
            let position = CGPoint(x: point.x, y: point.y)
            let event: CGEvent
            if let created = CGEvent(mouseEventSource: nil, mouseType: type,
                                     mouseCursorPosition: position, mouseButton: .left) {
                event = created
            } else if type == .leftMouseUp, let releaseEvent {
                event = releaseEvent
                event.location = position
                event.timestamp = DispatchTime.now().uptimeNanoseconds
            } else { return false }
            if type == .leftMouseDown {
                // Do not press unless a fallback release event is already available.
                guard let release = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp,
                                            mouseCursorPosition: position, mouseButton: .left) else { return false }
                let count = clickSequence.begin(at: point, time: ProcessInfo.processInfo.systemUptime,
                                                interval: NSEvent.doubleClickInterval)
                release.setIntegerValueField(.mouseEventClickState, value: count)
                releaseEvent = release
            }
            event.setIntegerValueField(.mouseEventClickState, value: clickSequence.count)
            event.post(tap: .cghidEventTap)
            if type == .leftMouseDown { postedDowns += 1 }
            if type == .leftMouseDragged { releaseEvent?.location = position }
            if type == .leftMouseUp {
                releaseEvent = nil
                clickSequence.end(completedTap: completedTap)
            }
        }
        return true
    }

    private func checkEnvironment() {
        guard running, let target else { return }
        guard PermissionState.current().canMap else { fail(.missingPermissions); return }
        guard let current = DisplayDiscovery.scan().first(where: { $0.id == target.id }),
              current.persistentUUID == target.persistentUUID,
              current.canMap, current.bounds == target.bounds else { fail(.deviceChanged); return }
    }

    private func fail(_ error: ProofError) {
        let restoreError = stop()
        onFailure?(restoreError ?? error)
    }
}
