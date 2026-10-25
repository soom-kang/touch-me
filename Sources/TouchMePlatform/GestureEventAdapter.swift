import AppKit
import CoreGraphics
import TouchMappingCore

public enum PinchAvailability: Equatable {
    case available, unsupportedOS, eventFormatUnavailable
}

/// Undocumented gesture fields are confined here. No input is posted by the
/// availability check. A successful post does not prove the recipient handled it.
/// Format reference: LinearMouse, GestureKit/GestureEvent+Zoom.swift (MIT).
/// Round-trip verified on macOS 26.7.1; do not infer support on another OS major.
final class GestureEventAdapter {
    enum Result { case posted, skipped, failed }
    typealias MagnificationFactory = (Double, MagnificationPhase, MappedPoint) -> CGEvent?

    private let send: (CGEvent) -> Void
    private let makeMagnification: MagnificationFactory
    private let physicalInputHeld: () -> Bool
    private var terminalEvents: (ended: CGEvent, cancelled: CGEvent)?

    init(send: @escaping (CGEvent) -> Void = { $0.post(tap: .cghidEventTap) },
         makeMagnification: @escaping MagnificationFactory = GestureEventAdapter.magnificationEvent,
         physicalInputHeld: @escaping () -> Bool = GestureEventAdapter.hasPhysicalInput) {
        self.send = send
        self.makeMagnification = makeMagnification
        self.physicalInputHeld = physicalInputHeld
    }

    static func availability(majorVersion: Int = ProcessInfo.processInfo.operatingSystemVersion.majorVersion) -> PinchAvailability {
        guard majorVersion == 26 else { return .unsupportedOS }
        let phases: [(MagnificationPhase, NSEvent.Phase)] = [
            (.began, .began), (.changed, .changed), (.ended, .ended), (.cancelled, .cancelled)
        ]
        for (phase, expected) in phases {
            for delta in phase == .changed ? [-0.125, 0.125] : [0.0] {
                guard let event = magnificationEvent(delta: delta, phase: phase, at: MappedPoint(x: 0, y: 0)),
                      let native = NSEvent(cgEvent: event), native.type == .magnify,
                      native.phase == expected, abs(native.magnification - delta) < 0.000001 else {
                    return .eventFormatUnavailable
                }
            }
        }
        return .available
    }

    static func magnificationEvent(delta: Double, phase: MagnificationPhase, at point: MappedPoint) -> CGEvent? {
        guard delta.isFinite, delta > -1, delta <= Double(Float.greatestFiniteMagnitude),
              point.x.isFinite, point.y.isFinite,
              phase == .changed || delta == 0,
              let event = CGEvent(source: nil), let type = CGEventType(rawValue: 29),
              let subtype = CGEventField(rawValue: 110), let amount = CGEventField(rawValue: 113),
              let phaseField = CGEventField(rawValue: 132) else { return nil }
        let nativePhase: CGGesturePhase
        switch phase {
        case .began: nativePhase = .began
        case .changed: nativePhase = .changed
        case .ended: nativePhase = .ended
        case .cancelled: nativePhase = .cancelled
        }
        event.type = type
        event.flags = []
        event.location = CGPoint(x: point.x, y: point.y)
        event.setIntegerValueField(subtype, value: 8)
        event.setDoubleValueField(amount, value: delta)
        event.setIntegerValueField(phaseField, value: Int64(nativePhase.rawValue))
        return event
    }

    func magnify(delta: Double, phase: MagnificationPhase, at point: MappedPoint) -> Result {
        switch phase {
        case .began:
            guard terminalEvents == nil,
                  let began = makeMagnification(delta, .began, point),
                  let ended = makeMagnification(0, .ended, point),
                  let cancelled = makeMagnification(0, .cancelled, point),
                  let movement = Self.movement(at: point) else { return .failed }
            terminalEvents = (ended, cancelled)
            send(movement)
            send(began)
        case .changed:
            guard terminalEvents != nil, let event = makeMagnification(delta, .changed, point) else { return .failed }
            send(event)
        case .ended, .cancelled:
            // Core may have begun a gesture whose event allocation failed.
            guard let events = terminalEvents else { return .skipped }
            terminalEvents = nil
            let event = phase == .ended ? events.ended : events.cancelled
            event.timestamp = DispatchTime.now().uptimeNanoseconds
            send(event)
        }
        return .posted
    }

    func cancel() {
        guard let events = terminalEvents else { return }
        terminalEvents = nil
        events.cancelled.timestamp = DispatchTime.now().uptimeNanoseconds
        send(events.cancelled)
    }

    func perform(_ action: SystemGesture, at point: MappedPoint) -> Result {
        guard !physicalInputHeld() else { return .skipped }
        guard let events = Self.systemEvents(action, at: point) else { return .failed }
        // All events, including key-up, exist before any key is pressed.
        events.forEach(send)
        return .posted
    }

    static func systemEvents(_ action: SystemGesture, at point: MappedPoint) -> [CGEvent]? {
        let key: CGKeyCode
        switch action {
        case .missionControl: key = 126 // Control-Up
        case .nextSpace: key = 124 // Control-Right
        case .previousSpace: key = 123 // Control-Left
        }
        guard let source = CGEventSource(stateID: .privateState),
              let movement = movement(at: point),
              let controlDown = CGEvent(keyboardEventSource: source, virtualKey: 59, keyDown: true),
              let down = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: false),
              let controlUp = CGEvent(keyboardEventSource: source, virtualKey: 59, keyDown: false) else { return nil }
        for event in [down, up] {
            // Arrow keys carry numericPad/secondaryFn flags needed by system
            // shortcuts. Replacing them with Control alone prevents switching.
            event.flags.insert(.maskControl)
            event.setIntegerValueField(.keyboardEventAutorepeat, value: 0)
        }
        // Flags on the arrow pair leave a synthesized Control state behind.
        // A complete modifier pair releases it before another gesture begins.
        controlDown.flags.insert(.maskControl)
        controlUp.flags = []
        return [movement, controlDown, down, up, controlUp]
    }

    private static func movement(at point: MappedPoint) -> CGEvent? {
        guard point.x.isFinite, point.y.isFinite else { return nil }
        return CGEvent(mouseEventSource: nil, mouseType: .mouseMoved,
                       mouseCursorPosition: CGPoint(x: point.x, y: point.y), mouseButton: .left)
    }

    private static func hasPhysicalInput() -> Bool {
        let modifiers: CGEventFlags = [.maskShift, .maskControl, .maskAlternate, .maskCommand, .maskSecondaryFn]
        if !CGEventSource.flagsState(.hidSystemState).intersection(modifiers).isEmpty { return true }
        return (0..<32).contains { index in
            guard let button = CGMouseButton(rawValue: UInt32(index)) else { return false }
            return CGEventSource.buttonState(.hidSystemState, button: button)
        }
    }
}
