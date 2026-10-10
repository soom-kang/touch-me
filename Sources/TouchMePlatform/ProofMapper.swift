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

public enum MappingStartPolicy: Equatable {
    case manual, automatic, reconnectAutomatic
}

public enum MappingCleanupDisposition: Equatable {
    case none, restored, attachmentEnded
}

public enum ProofError: Error, LocalizedError {
    case missingPermissions, unsupportedDevice, unsupportedDisplay, environmentUnavailable
    case deviceChanged(TargetChangeOrigin)
    case openFailed(IOReturn), readFailed(IOReturn), eventCreationFailed
    case modeUnsupported, modeStateUnexpected, modeReadFailed(IOReturn)
    case modeWriteFailed(IOReturn), modeReadbackMismatch, modeRestoreFailed(IOReturn)
    case reconnectManualStartRequired

    public var errorDescription: String? {
        switch self {
        case .missingPermissions: return "Both Input Monitoring and Accessibility are required."
        case .environmentUnavailable: return "Unlock the Mac and return to its active user session before mapping."
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
        case .reconnectManualStartRequired:
            return "The reconnected panel is already in multitouch mode (2,0). Start mapping manually to keep this mode; Stop will also leave it unchanged."
        case .modeRestoreFailed(let rc):
            if let reason = recoveryJournalDescription(rc) { return reason }
            return String(format: "Original device mode could not be restored (0x%08X). Keep the current connection and retry restoration; a changed attachment cannot authorize recovery.", UInt32(bitPattern: rc))
        }
    }
    public var code: String {
        switch self {
        case .missingPermissions: return "permissions_missing"
        case .environmentUnavailable: return "environment_unavailable"
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
        case .reconnectManualStartRequired: return "reconnect_manual_start_required"
        case .modeRestoreFailed(let rc): return String(format: "mode_restore_0x%08X", UInt32(bitPattern: rc))
        }
    }
}

// App-local reason codes keep the existing public error enum and callbacks.
private func recoveryJournalDescription(_ result: IOReturn) -> String? {
    switch UInt32(bitPattern: result) {
    case 0xE0000F01: return "Another process owns mode recovery. Mapping is blocked; the recovery record is preserved."
    case 0xE0000F02: return "The previous recovery owner could not be safely identified. Mapping is blocked; the recovery record is preserved."
    case 0xE0000F03: return "The mode recovery record is invalid. No guessed mode was written; mapping is blocked."
    case 0xE0000F04: return "The recovery record belongs to a different boot or attachment. Mapping is blocked; reconnecting to the same port does not authorize restoration."
    case 0xE0000F05: return "The device mode does not match the recorded recovery states. No recovery write was authorized."
    case 0xE0000F06: return "The recovery record changed unexpectedly. It was preserved and mapping is blocked."
    case 0xE0000F07: return "The recovery record could not be safely stored or read. Mapping is blocked until it can be safely processed; the record is preserved."
    default: return nil
    }
}

private func modeRecoveryProofError(_ error: Error) -> ProofError {
    if let error = error as? DeviceModeRecoveryJournalError {
        let code: UInt32
        switch error {
        case .busy, .ownerAlive: code = 0xE0000F01
        case .ownerChanged, .ownerUnknown: code = 0xE0000F02
        case .invalidRecord: code = 0xE0000F03
        case .identityChanged: code = 0xE0000F04
        case .unexpectedState: code = 0xE0000F05
        case .recordChanged: code = 0xE0000F06
        case .unsafePath, .ioFailure: code = 0xE0000F07
        }
        return .modeRestoreFailed(IOReturn(bitPattern: code))
    }
    if let error = error as? ProofError { return error }
    return .modeRestoreFailed(kIOReturnError)
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
    public var modeRestorePending: Bool {
        deviceMode?.control.needsRestore == true || stoppedObservationJournal?.hasPendingUnchangedDisconnect == true
    }
    public private(set) var lastCleanupDisposition: MappingCleanupDisposition = .none
    public var reconnectExpectedDescriptorSHA256: String?
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
    private var stoppedAttachment: (identity: DeviceModeRecoveryIdentity, original: DeviceModeTransaction.Pair)?
    private var stoppedObservationJournal: DeviceModeRecoveryJournal?
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

    public func start(device: TouchDevice, display: DisplayTarget, expectedDisplay: DisplayTarget? = nil,
                      startPolicy: MappingStartPolicy = .manual) throws {
        precondition(Thread.isMainThread)
        let expectedReconnectDescriptor = reconnectExpectedDescriptorSHA256
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
        guard scan.queryReturnedSet, scan.devices.count == 1, let fresh = scan.devices.first(where: { $0.key == device.key }), fresh.canMap,
              fresh.usableCollections.count == 1 else {
            throw ProofError.unsupportedDevice
        }
        guard fresh.locationID == device.locationID else { throw ProofError.unsupportedDevice }
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
        func verifyOpenedEnvironment() throws {
            guard PermissionState.current().canMap else { throw ProofError.missingPermissions }
            guard NSApplication.shared.isProtectedDataAvailable,
                  let currentSession = CGSessionCopyCurrentDictionary() as? [String: Any],
                  currentSession["kCGSSessionOnConsoleKey"] as? Bool == true,
                  currentSession["kCGSessionLoginDoneKey"] as? Bool == true else {
                throw ProofError.environmentUnavailable
            }
            let displays = DisplayDiscovery.scan().filter { $0.persistentUUID == uuid }
            guard displays.count == 1, let current = displays.first, current.canMap,
                  current.matchesConfiguration(of: freshDisplay), CGDisplayIsAsleep(current.id) == 0 else {
                throw ProofError.deviceChanged(.displayValidation)
            }
            target = current
        }
        do {
            for collection in fresh.usableCollections {
                let rc = IOHIDDeviceOpen(collection.device, IOOptionBits(kIOHIDOptionsTypeSeizeDevice))
                resumePhase("device_open_finished")
                guard rc == kIOReturnSuccess else { throw ProofError.openFailed(rc) }
                opened.append(collection)
                try verifyOpenedEnvironment()
                let control = try P16KTDeviceMode(collection: collection)
                resumePhase("mode_read_finished")
                deviceMode = (collection, control)
                let journal = try DeviceModeRecoveryJournal.acquire()
                try control.attachRecovery(journal, collection: collection)
                try control.prepareStart(policy: startPolicy, expectedDescriptor: expectedReconnectDescriptor)
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
            try verifyOpenedEnvironment()
            try deviceMode?.control.acknowledgeReconnect()
            _ = post(session.start())
            running = true
            stoppedAttachment = nil
            if frameAssembler.allLifted { _ = session.update(contacts: []) }
            watchdog = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in self?.checkEnvironment() }
            if let watchdog { RunLoop.main.add(watchdog, forMode: .common) }
            onChange?()
            resumePhase("running")
        } catch {
            resumePhase("rollback")
            let restoreError = stop(recoverPreviousOwner: false)
            if let restoreError { throw restoreError }
            throw modeRecoveryProofError(error)
        }
    }

    @discardableResult
    public func stop() -> ProofError? {
        stop(recoverPreviousOwner: true)
    }

    /// Bounded display-change classification can outlive the first HID cleanup.
    /// This observes exact old services and performs journal I/O only after they end.
    public func observeStoppedAttachment() throws -> Bool {
        precondition(Thread.isMainThread)
        do {
            guard let stoppedAttachment,
                  try P16KTDeviceMode.attachmentHasEnded(stoppedAttachment.identity) else { return false }
            if deviceMode != nil {
                if let error = stop() { throw error }
                guard lastCleanupDisposition == .attachmentEnded else { return false }
            } else {
                let journal = try stoppedObservationJournal ?? DeviceModeRecoveryJournal.acquire()
                stoppedObservationJournal = journal
                try journal.retireUnchangedAttachment(identity: stoppedAttachment.identity, original: stoppedAttachment.original,
                                                      bootSession: P16KTDeviceMode.currentBootSession(),
                                                      attachmentEnded: { try P16KTDeviceMode.attachmentHasEnded(stoppedAttachment.identity) })
                journal.close()
                stoppedObservationJournal = nil
                reconnectExpectedDescriptorSHA256 = stoppedAttachment.identity.descriptorSHA256
                lastCleanupDisposition = .attachmentEnded
            }
            self.stoppedAttachment = nil
            onChange?()
            return true
        } catch {
            if stoppedObservationJournal?.hasPendingUnchangedDisconnect != true {
                stoppedObservationJournal?.close()
                stoppedObservationJournal = nil
            }
            onChange?()
            throw modeRecoveryProofError(error)
        }
    }

    public func cancelStoppedAttachmentObservation() {
        // Cancel resume intent without discarding a file transition that needs Retry.
        guard stoppedObservationJournal?.hasPendingUnchangedDisconnect != true else { return }
        stoppedObservationJournal?.close()
        stoppedObservationJournal = nil
        stoppedAttachment = nil
    }

    private func stop(recoverPreviousOwner: Bool) -> ProofError? {
        precondition(Thread.isMainThread)
        lastCleanupDisposition = .none
        let hadControl = deviceMode != nil
        if let control = deviceMode?.control, running || control.needsRestore,
           let identity = control.attachmentIdentity {
            stoppedAttachment = (identity, control.originalPair)
        }
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
                if try deviceMode.control.attachmentHasEnded() {
                    try deviceMode.control.retireDisconnected()
                    reconnectExpectedDescriptorSHA256 = deviceMode.control.attachmentDescriptorSHA256
                    self.deviceMode = nil
                    stoppedAttachment = nil
                    lastCleanupDisposition = .attachmentEnded
                    Logger(subsystem: "io.github.soom-kang.touchme", category: "MappingRecovery")
                        .notice("Ended attachment archived as unrestored; waiting for a fresh connection")
                } else {
                    if deviceMode.control.needsRestore,
                       !opened.contains(where: { $0.registryID == deviceMode.collection.registryID }) {
                        // Rebind stale handles only for the recorded continuous attachment.
                        // A re-enumerated or replacement unit is rejected even on the same port.
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
                    lastCleanupDisposition = .restored
                }
            } catch {
                if let identity = deviceMode.control.attachmentIdentity {
                    stoppedAttachment = (identity, deviceMode.control.originalPair)
                }
                let failure = modeRecoveryProofError(error)
                if case .modeRestoreFailed = failure { restoreError = failure }
                else { restoreError = .modeRestoreFailed(kIOReturnError) }
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
        if recoverPreviousOwner, !hadControl, restoreError == nil {
            do {
                if stoppedObservationJournal != nil { _ = try observeStoppedAttachment() }
                try restorePreviousMode()
            }
            catch { restoreError = modeRecoveryProofError(error) }
        }
        onChange?()
        return restoreError
    }

    private func restorePreviousMode() throws {
        let journal = try DeviceModeRecoveryJournal.acquire()
        defer { journal.close() }
        guard let record = try journal.load() else {
            _ = try journal.loadReconnectGuard()
            return
        }
        if try P16KTDeviceMode.attachmentHasEnded(record.identity) {
            try journal.retireDisconnected(record, bootSession: P16KTDeviceMode.currentBootSession(),
                                           attachmentEnded: { try P16KTDeviceMode.attachmentHasEnded(record.identity) })
            reconnectExpectedDescriptorSHA256 = record.identity.descriptorSHA256
            lastCleanupDisposition = .attachmentEnded
            Logger(subsystem: "io.github.soom-kang.touchme", category: "MappingRecovery")
                .notice("Ended predecessor attachment archived without a device-mode write")
            return
        }
        guard PermissionState.current().inputMonitoring else { throw ProofError.missingPermissions }
        let scan = HIDDiscovery.scan()
        guard scan.queryReturnedSet, scan.devices.count == 1, let device = scan.devices.first,
              device.canMap, device.usableCollections.count == 1,
              let collection = device.usableCollections.first,
              try P16KTDeviceMode.recoveryIdentity(collection) == record.identity else {
            throw DeviceModeRecoveryJournalError.identityChanged
        }
        let result = IOHIDDeviceOpen(collection.device, IOOptionBits(kIOHIDOptionsTypeSeizeDevice))
        guard result == kIOReturnSuccess else { throw ProofError.modeRestoreFailed(result) }
        do {
            let control = try P16KTDeviceMode(collection: collection)
            try control.attachRecovery(journal, collection: collection)
        } catch {
            let close = IOHIDDeviceClose(collection.device, IOOptionBits(kIOHIDOptionsTypeNone))
            if close != kIOReturnSuccess { throw ProofError.modeRestoreFailed(close) }
            throw error
        }
        let close = IOHIDDeviceClose(collection.device, IOOptionBits(kIOHIDOptionsTypeNone))
        guard close == kIOReturnSuccess else { throw ProofError.modeRestoreFailed(close) }
        Logger(subsystem: "io.github.soom-kang.touchme", category: "MappingRecovery")
            .notice("Previous mode recovery verified; record cleared before mapping resume")
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
        let failure = lastCleanupDisposition == .attachmentEnded
            ? ProofError.deviceChanged(.touchDeviceRemoval) : (restoreError ?? error)
        onFailure?(failure, previousDisplay)
    }
}
