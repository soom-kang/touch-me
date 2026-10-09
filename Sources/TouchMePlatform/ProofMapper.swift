import Foundation
import AppKit
import IOKit
import IOKit.hid
import CoreGraphics
import TouchMappingCore
import OSLog

public enum TargetChangeOrigin {
    case touchDeviceRemoval, displayValidation
}

public enum ProofError: Error, LocalizedError {
    case missingPermissions, unsupportedDevice, unsupportedDisplay
    case deviceChanged(TargetChangeOrigin)
    case openFailed(IOReturn), readFailed(IOReturn), eventCreationFailed
    case modeUnsupported, modeStateUnexpected, modeReadFailed(IOReturn)
    case modeWriteFailed(IOReturn), modeReadbackMismatch, modeRestoreFailed(IOReturn)

    public var errorDescription: String? {
        switch self {
        case .missingPermissions: return "Both Input Monitoring and Accessibility are required."
        case .unsupportedDevice: return "USB physical grouping or absolute contact descriptor could not be verified."
        case .unsupportedDisplay: return "Select an external display with no rotation or mirroring."
        case .deviceChanged(.touchDeviceRemoval): return "The touch device disconnected. Check its USB connection, then refresh."
        case .deviceChanged(.displayValidation): return "The target display changed or is unavailable. Refresh and try again."
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
    public var onFailure: ((ProofError, DisplayTarget?) -> Void)?
    /// May stop mapping for a temporary app-session interruption before input checks.
    public var onEnvironmentCheck: (() -> Void)?
    public var onDisplaySleep: (() -> Void)?
    private var session = ProofSession()
    private var clickSequence = ClickSequence()
    private var releaseEvent: CGEvent?
    private var opened: [HIDCollection] = []
    private var deviceMode: (collection: HIDCollection, control: P16KTDeviceMode)?
    private var contacts: [String: ContactElements] = [:]
    private var frameAssembler = HIDContactFrameAssembler()
    private var elementKeys: [String: String] = [:]
    private var target: DisplayTarget?
    private var watchdog: Timer?
    private var flushScheduled = false
    private var generation = 0
    private var preferDigitizer = false
    private var scrollRemainderX = 0.0
    private var scrollRemainderY = 0.0
    private let loop = CFRunLoopGetMain()!
    private let mode = CFRunLoopMode.commonModes.rawValue

    public init() {}

    public var activeDisplayTarget: DisplayTarget? { target }

    public func start(device: TouchDevice, display: DisplayTarget, expectedDisplay: DisplayTarget? = nil) throws {
        precondition(Thread.isMainThread)
        let resumeStartedAt = ProcessInfo.processInfo.systemUptime
        let recoveryLog = Logger(subsystem: "io.github.soom-kang.touchme", category: "MappingRecovery")
        func resumePhase(_ phase: String) {
            guard expectedDisplay != nil else { return }
            recoveryLog.notice("Resume phase \(phase, privacy: .public), elapsed \(ProcessInfo.processInfo.systemUptime - resumeStartedAt, format: .fixed(precision: 3))s")
        }
        resumePhase("begin")
        defer { resumePhase("exit") }
        if let error = stop() { throw error }
        resumePhase("cleanup_finished")
        guard PermissionState.current().canMap else { throw ProofError.missingPermissions }
        // Refresh immediately before opening; a saved VID/PID is insufficient.
        let scan = HIDDiscovery.scan()
        resumePhase("device_scan_finished")
        guard scan.devices.count == 1, let fresh = scan.devices.first(where: { $0.key == device.key }), fresh.canMap,
              fresh.usableCollections.count == 1 else {
            throw ProofError.unsupportedDevice
        }
        guard let uuid = display.persistentUUID else { throw ProofError.unsupportedDisplay }
        guard let freshDisplay = DisplayDiscovery.scan().first(where: { $0.id == display.id }),
              freshDisplay.persistentUUID == uuid, freshDisplay.canMap else {
            if expectedDisplay != nil { throw ProofError.deviceChanged(.displayValidation) }
            throw ProofError.unsupportedDisplay
        }
        if let expectedDisplay, !freshDisplay.matchesConfiguration(of: expectedDisplay) {
            throw ProofError.deviceChanged(.displayValidation)
        }
        resumePhase("display_scan_finished")
        target = freshDisplay
        receivedValues = 0
        postedDowns = 0
        postedScrolls = 0
        maximumContacts = 0
        let context = Unmanaged.passUnretained(self).toOpaque()
        do {
            for collection in fresh.usableCollections {
                let rc = IOHIDDeviceOpen(collection.device, IOOptionBits(kIOHIDOptionsTypeSeizeDevice))
                resumePhase("device_open_finished")
                guard rc == kIOReturnSuccess else { throw ProofError.openFailed(rc) }
                opened.append(collection)
                let control = try P16KTDeviceMode(collection: collection)
                resumePhase("mode_read_finished")
                deviceMode = (collection, control)
                try control.enable()
                resumePhase("mode_enable_finished")
                for e in collection.contacts {
                    // Verify an initial tip state; actual coordinates still require callbacks.
                    let down = try currentValue(for: e.tip).integer != 0
                    contacts[e.key] = e
                    frameAssembler.addContact(key: e.key, down: down)
                    for el in [e.x, e.y, e.tip] {
                        elementKeys["\(collection.registryID):\(IOHIDElementGetCookie(el))"] = e.key
                    }
                }
                IOHIDDeviceRegisterInputValueCallback(collection.device, { context, result, sender, value in
                    guard let context else { return }
                    let mapper = Unmanaged<ProofMapper>.fromOpaque(context).takeUnretainedValue()
                    guard mapper.acceptsCallback(from: sender) else { return }
                    if result != kIOReturnSuccess {
                        mapper.onEnvironmentCheck?()
                        guard mapper.acceptsCallback(from: sender) else { return }
                        mapper.fail(.readFailed(result))
                        return
                    }
                    mapper.receive(value)
                }, context)
                IOHIDDeviceRegisterRemovalCallback(collection.device, { context, _, sender in
                    guard let context else { return }
                    let mapper = Unmanaged<ProofMapper>.fromOpaque(context).takeUnretainedValue()
                    guard mapper.acceptsCallback(from: sender) else { return }
                    mapper.onEnvironmentCheck?()
                    guard mapper.acceptsCallback(from: sender) else { return }
                    mapper.fail(.deviceChanged(.touchDeviceRemoval))
                }, context)
                IOHIDDeviceScheduleWithRunLoop(collection.device, loop, mode)
                resumePhase("contact_read_finished")
            }
            _ = post(session.start())
            running = true
            if frameAssembler.allLifted { _ = session.update(contacts: []) }
            watchdog = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in self?.checkEnvironment() }
            if let watchdog { RunLoop.main.add(watchdog, forMode: .common) }
            onChange?()
            resumePhase("running")
        } catch {
            resumePhase("rollback")
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
        let context = Unmanaged.passUnretained(self).toOpaque()
        for c in opened {
            IOHIDDeviceRegisterInputValueCallback(c.device, nil, context)
            IOHIDDeviceRegisterRemovalCallback(c.device, nil, context)
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
        frameAssembler = HIDContactFrameAssembler()
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
              let key = elementKeys["\(id):\(IOHIDElementGetCookie(el))"], let elements = contacts[key] else { return }
        let timestamp = IOHIDValueGetTimeStamp(value)
        let field: HIDContactField
        switch IOHIDElementGetCookie(el) {
        case IOHIDElementGetCookie(elements.x): field = .x
        case IOHIDElementGetCookie(elements.y): field = .y
        case IOHIDElementGetCookie(elements.tip): field = .tip
        default: return
        }
        if let pending = frameAssembler.pendingTimestamp, pending != timestamp {
            guard canProcessFrame() else { return }
        }
        do {
            if let frame = try frameAssembler.receive(key: key, field: field,
                value: HIDContactValue(integer: IOHIDValueGetIntegerValue(value), timestamp: timestamp),
                read: readCoordinate) {
                process(frame)
            }
        } catch let error as ProofError {
            fail(error)
            return
        } catch {
            fail(.readFailed(kIOReturnError))
            return
        }
        guard running else { return }
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

    private func acceptsCallback(from sender: UnsafeMutableRawPointer?) -> Bool {
        guard running, let sender else { return false }
        return opened.contains { Unmanaged.passUnretained($0.device).toOpaque() == sender }
    }

    private func canProcessFrame() -> Bool {
        guard running else { return false }
        onEnvironmentCheck?()
        guard running, target != nil else { return false }
        guard PermissionState.current().canMap else { fail(.missingPermissions); return false }
        return true
    }

    private func flush() {
        guard frameAssembler.pendingTimestamp != nil, canProcessFrame() else { return }
        do {
            if let frame = try frameAssembler.flush(read: readCoordinate) { process(frame) }
        } catch let error as ProofError {
            fail(error)
        } catch {
            fail(.readFailed(kIOReturnError))
        }
    }

    private func readCoordinate(key: String, field: HIDContactField) throws -> HIDContactValue {
        guard let elements = contacts[key] else { throw ProofError.readFailed(kIOReturnError) }
        switch field {
        case .x: return try currentValue(for: elements.x)
        case .y: return try currentValue(for: elements.y)
        case .tip: return try currentValue(for: elements.tip)
        }
    }

    private func process(_ frame: HIDContactFrame) {
        guard running, let target else { return }
        let downs = frame.contacts.filter(\.down)
        let digitizer = downs.filter { contacts[$0.key]?.isDigitizer == true }
        if !digitizer.isEmpty { preferDigitizer = true }
        if downs.isEmpty { preferDigitizer = false }
        let active = preferDigitizer ? digitizer : downs
        if !downs.isEmpty && active.count != 1 { clickSequence.cancelTap() }
        maximumContacts = max(maximumContacts, active.count)
        if active.count != 2 {
            scrollRemainderX = 0
            scrollRemainderY = 0
        }
        let mappedContacts = active.compactMap { state -> ProofContact? in
            guard let elements = contacts[state.key], let x = state.x, let y = state.y,
                  let point = CoordinateMapper.map(x: x, y: y, xRange: elements.xRange,
                                                   yRange: elements.yRange, to: target.rect) else { return nil }
            return ProofContact(id: state.key, point: point)
        }
        // Reject the whole gesture rather than interpreting partial data as a tap/lift.
        if mappedContacts.count != active.count || (active.isEmpty && !downs.isEmpty) {
            clickSequence.cancelTap()
            scrollRemainderX = 0
            scrollRemainderY = 0
            guard post(session.rejectContact()) else { fail(.eventCreationFailed); return }
            onChange?()
            return
        }
        guard post(session.update(contacts: mappedContacts), completedTap: downs.isEmpty) else { fail(.eventCreationFailed); return }
        onChange?()
    }

    private func currentValue(for element: IOHIDElement) throws -> HIDContactValue {
        let valuePointer = UnsafeMutablePointer<Unmanaged<IOHIDValue>>.allocate(capacity: 1)
        defer { valuePointer.deallocate() }
        let rc = IOHIDDeviceGetValue(IOHIDElementGetDevice(element), element, valuePointer)
        guard rc == kIOReturnSuccess else { throw ProofError.readFailed(rc) }
        let value = valuePointer.pointee.takeUnretainedValue()
        return HIDContactValue(integer: IOHIDValueGetIntegerValue(value), timestamp: IOHIDValueGetTimeStamp(value))
    }

    @discardableResult
    private func post(_ actions: [ProofAction], completedTap: Bool = false) -> Bool {
        // A drag-start Down must not inherit a preceding tap's double-click count.
        if actions.contains(where: { if case .drag = $0 { return true }; return false }) {
            clickSequence.cancelTap()
        }
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
        guard running else { return }
        onEnvironmentCheck?()
        guard running, let target else { return }
        guard PermissionState.current().canMap else { fail(.missingPermissions); return }
        if let uuid = target.persistentUUID, DisplayDiscovery.sleepState(for: uuid) == true {
            onDisplaySleep?()
            guard running else { return }
            fail(.deviceChanged(.displayValidation))
            return
        }
        let matching = DisplayDiscovery.scan().filter { $0.persistentUUID == target.persistentUUID }
        guard matching.count == 1, let current = matching.first,
              current.canMap, current.matchesConfiguration(of: target) else {
            fail(.deviceChanged(.displayValidation))
            return
        }
        self.target = current
    }

    private func fail(_ error: ProofError) {
        let previousDisplay = target
        let restoreError = stop()
        onFailure?(restoreError ?? error, previousDisplay)
    }
}
