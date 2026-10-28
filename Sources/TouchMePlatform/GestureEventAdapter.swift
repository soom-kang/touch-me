import AppKit
import CoreGraphics
import TouchMappingCore

public enum PinchAvailability: Equatable {
    case available, unsupportedOS, eventFormatUnavailable
}

public enum PageSwipeAvailability: Equatable {
    case available, unsupportedOS, eventFormatUnavailable
}

/// Undocumented gesture fields are confined here. No input is posted by the
/// availability check. A successful post does not prove the recipient handled it.
/// Pinch format reference: LinearMouse, GestureKit/GestureEvent+Zoom.swift (MIT).
/// Scroll companion format reference: Mac Mouse Fix, GestureScrollSimulator.m.
/// Format conversion alone does not verify native page-swipe behavior.
final class GestureEventAdapter {
    enum Result { case posted, skipped, failed }
    typealias MagnificationFactory = (Double, MagnificationPhase, MappedPoint) -> CGEvent?
    typealias ScrollFactory = (Int32, Int32, ScrollPhase, MappedPoint) -> CGEvent?

    private struct ScrollEvents {
        let scroll: CGEvent
        let companion: CGEvent?
    }

    private struct ScrollState {
        let anchor: MappedPoint
        let ended: ScrollEvents
        let cancelled: ScrollEvents
        var remainderX: Double
        var remainderY: Double
    }

    private let send: (CGEvent) -> Void
    private let makeMagnification: MagnificationFactory
    private let makeScroll: ScrollFactory
    private let makeScrollCompanion: ScrollFactory
    let pageSwipeAvailability: PageSwipeAvailability
    private let physicalInputHeld: () -> Bool
    private var terminalEvents: (ended: CGEvent, cancelled: CGEvent)?
    private var scrollState: ScrollState?

    init(send: @escaping (CGEvent) -> Void = { $0.post(tap: .cghidEventTap) },
         makeMagnification: @escaping MagnificationFactory = GestureEventAdapter.magnificationEvent,
         makeScroll: @escaping ScrollFactory = GestureEventAdapter.scrollEvent,
         makeScrollCompanion: @escaping ScrollFactory = GestureEventAdapter.scrollCompanionEvent,
         pageSwipeAvailability: PageSwipeAvailability = GestureEventAdapter.pageSwipeAvailability(),
         physicalInputHeld: @escaping () -> Bool = GestureEventAdapter.hasPhysicalInput) {
        self.send = send
        self.makeMagnification = makeMagnification
        self.makeScroll = makeScroll
        self.makeScrollCompanion = makeScrollCompanion
        self.pageSwipeAvailability = pageSwipeAvailability
        self.physicalInputHeld = physicalInputHeld
    }

    static func scrollEvent(dx: Int32, dy: Int32, phase: ScrollPhase, at point: MappedPoint) -> CGEvent? {
        guard point.x.isFinite, point.y.isFinite,
              phase != .began || dx != 0 || dy != 0,
              (phase != .ended && phase != .cancelled) || (dx == 0 && dy == 0),
              let event = CGEvent(scrollWheelEvent2Source: nil, units: .pixel,
                                  wheelCount: 2, wheel1: dy, wheel2: dx, wheel3: 0) else { return nil }
        let nativePhase: CGScrollPhase
        switch phase {
        case .began: nativePhase = .began
        case .changed: nativePhase = .changed
        case .ended: nativePhase = .ended
        case .cancelled: nativePhase = .cancelled
        }
        event.location = CGPoint(x: point.x, y: point.y)
        event.setIntegerValueField(.scrollWheelEventIsContinuous, value: 1)
        event.setIntegerValueField(.scrollWheelEventScrollPhase, value: Int64(nativePhase.rawValue))
        event.setIntegerValueField(.scrollWheelEventMomentumPhase, value: Int64(CGMomentumScrollPhase.none.rawValue))
        return event
    }

    static func scrollCompanionEvent(dx: Int32, dy: Int32, phase: ScrollPhase, at point: MappedPoint) -> CGEvent? {
        guard point.x.isFinite, point.y.isFinite,
              phase != .began || dx != 0 || dy != 0,
              (phase != .ended && phase != .cancelled) || (dx == 0 && dy == 0),
              let event = CGEvent(source: nil), let type = CGEventType(rawValue: 29),
              let subtype = CGEventField(rawValue: 110), let deltaX = CGEventField(rawValue: 116),
              let deltaY = CGEventField(rawValue: 119), let phaseField = CGEventField(rawValue: 132) else { return nil }
        let nativePhase: CGGesturePhase
        switch phase {
        case .began: nativePhase = .began
        case .changed: nativePhase = .changed
        case .ended: nativePhase = .ended
        case .cancelled: nativePhase = .cancelled
        }
        event.type = type
        event.location = CGPoint(x: point.x, y: point.y)
        event.setIntegerValueField(subtype, value: 6)
        // Use the same displacement as the public scroll, without app-specific
        // sensitivity tuning. Recipient behavior still requires device testing.
        event.setDoubleValueField(deltaX, value: Double(dx))
        event.setDoubleValueField(deltaY, value: Double(dy))
        event.setIntegerValueField(phaseField, value: Int64(nativePhase.rawValue))
        return event
    }

    static func pageSwipeAvailability(
        majorVersion: Int = ProcessInfo.processInfo.operatingSystemVersion.majorVersion,
        makeCompanion: ScrollFactory = GestureEventAdapter.scrollCompanionEvent
    ) -> PageSwipeAvailability {
        guard majorVersion == 26 else { return .unsupportedOS }
        let phases: [(ScrollPhase, NSEvent.Phase, Int32, Int32)] = [
            (.began, .began, 12, -8), (.changed, .changed, -3, 4),
            (.ended, .ended, 0, 0), (.cancelled, .cancelled, 0, 0)
        ]
        guard let subtype = CGEventField(rawValue: 110), let deltaX = CGEventField(rawValue: 116),
              let deltaY = CGEventField(rawValue: 119) else { return .eventFormatUnavailable }
        for (phase, expected, dx, dy) in phases {
            guard let event = makeCompanion(dx, dy, phase, MappedPoint(x: 0, y: 0)),
                  let native = NSEvent(cgEvent: event), native.type == .gesture, native.phase == expected,
                  let roundTrip = native.cgEvent,
                  roundTrip.getIntegerValueField(subtype) == 6,
                  roundTrip.getDoubleValueField(deltaX) == Double(dx),
                  roundTrip.getDoubleValueField(deltaY) == Double(dy) else { return .eventFormatUnavailable }
        }
        return .available
    }

    private func scrollEvents(dx: Int32, dy: Int32, phase: ScrollPhase, at point: MappedPoint) -> ScrollEvents? {
        guard let scroll = makeScroll(dx, dy, phase, point) else { return nil }
        guard pageSwipeAvailability == .available else { return ScrollEvents(scroll: scroll, companion: nil) }
        guard let companion = makeScrollCompanion(dx, dy, phase, point) else { return nil }
        companion.flags = scroll.flags
        return ScrollEvents(scroll: scroll, companion: companion)
    }

    private func sendScrollEvents(_ events: ScrollEvents, terminal: Bool = false) {
        if terminal {
            events.scroll.flags = CGEventSource.flagsState(.combinedSessionState)
            events.companion?.flags = events.scroll.flags
        }
        let timestamp = DispatchTime.now().uptimeNanoseconds
        events.scroll.timestamp = timestamp
        events.companion?.timestamp = timestamp
        send(events.scroll)
        if let companion = events.companion { send(companion) }
    }

    func scroll(dx: Double, dy: Double, phase: ScrollPhase, at point: MappedPoint) -> Result {
        switch phase {
        case .began:
            guard scrollState == nil, dx.isFinite, dy.isFinite else { return .failed }
            let sx = Self.scrollPixels(dx)
            let sy = Self.scrollPixels(dy)
            // Native page-swipe recognition needs the actual movement on began.
            // Prepare both terminal pairs before delivering any input.
            guard let began = scrollEvents(dx: sx, dy: sy, phase: .began, at: point),
                  let ended = scrollEvents(dx: 0, dy: 0, phase: .ended, at: point),
                  let cancelled = scrollEvents(dx: 0, dy: 0, phase: .cancelled, at: point),
                  let movement = Self.movement(at: point) else { return .failed }
            scrollState = ScrollState(anchor: point, ended: ended, cancelled: cancelled,
                                      remainderX: dx - Double(sx), remainderY: dy - Double(sy))
            send(movement)
            sendScrollEvents(began)
        case .changed:
            guard var state = scrollState, dx.isFinite, dy.isFinite else { return .failed }
            state.remainderX += dx
            state.remainderY += dy
            guard state.remainderX.isFinite, state.remainderY.isFinite else { return .failed }
            let sx = Self.scrollPixels(state.remainderX)
            let sy = Self.scrollPixels(state.remainderY)
            guard sx != 0 || sy != 0 else {
                scrollState = state
                return .skipped
            }
            guard let events = scrollEvents(dx: sx, dy: sy, phase: .changed, at: state.anchor) else { return .failed }
            state.remainderX -= Double(sx)
            state.remainderY -= Double(sy)
            scrollState = state
            sendScrollEvents(events)
        case .ended, .cancelled:
            guard let state = scrollState else { return .skipped }
            scrollState = nil
            sendScrollEvents(phase == .ended ? state.ended : state.cancelled, terminal: true)
        }
        return .posted
    }

    private static func scrollPixels(_ value: Double) -> Int32 {
        Int32(min(max(value.rounded(), Double(Int32.min)), Double(Int32.max)))
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
        if let events = terminalEvents {
            terminalEvents = nil
            events.cancelled.timestamp = DispatchTime.now().uptimeNanoseconds
            send(events.cancelled)
        }
        if let state = scrollState {
            scrollState = nil
            sendScrollEvents(state.cancelled, terminal: true)
        }
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
