import AppKit
import Testing
import TouchMappingCore
@testable import TouchMePlatform

struct GestureEventAdapterTests {
    private let anchor = MappedPoint(x: -300, y: 200)

    @Test
    func magnificationFieldsRoundTripWithoutPosting() throws {
        let cases: [(MagnificationPhase, NSEvent.Phase, Double)] = [
            (.began, .began, 0), (.changed, .changed, 0.2), (.changed, .changed, -0.2),
            (.ended, .ended, 0), (.cancelled, .cancelled, 0)
        ]
        for (phase, nativePhase, delta) in cases {
            let event = try #require(GestureEventAdapter.magnificationEvent(delta: delta, phase: phase, at: anchor))
            let converted = try #require(NSEvent(cgEvent: event))
            #expect(converted.type == .magnify)
            #expect(converted.phase == nativePhase)
            #expect(abs(converted.magnification - delta) < 0.000001)
            #expect(event.location == CGPoint(x: anchor.x, y: anchor.y))
            #expect(event.flags.isEmpty)
        }
        #expect(GestureEventAdapter.availability(majorVersion: 27) == .unsupportedOS)
        #expect(GestureEventAdapter.availability(majorVersion: 25) == .unsupportedOS)
        #expect(GestureEventAdapter.magnificationEvent(delta: .infinity, phase: .changed, at: anchor) == nil)
        #expect(GestureEventAdapter.magnificationEvent(delta: Double.greatestFiniteMagnitude, phase: .changed, at: anchor) == nil)
        #expect(GestureEventAdapter.magnificationEvent(delta: -1, phase: .changed, at: anchor) == nil)
        #expect(GestureEventAdapter.magnificationEvent(delta: 0.1, phase: .began, at: anchor) == nil)
    }

    @Test
    func pinchPreparesTerminalEventsAndCancelsOnceAfterAllocationFailure() {
        var events: [CGEvent] = []
        var failChanged = false
        let adapter = GestureEventAdapter(send: { events.append($0) }, makeMagnification: { delta, phase, point in
            if failChanged && phase == .changed { return nil }
            return GestureEventAdapter.magnificationEvent(delta: delta, phase: phase, at: point)
        })
        #expect(adapter.magnify(delta: 0, phase: .began, at: anchor) == .posted)
        failChanged = true
        #expect(adapter.magnify(delta: 0.1, phase: .changed, at: anchor) == .failed)
        adapter.cancel()
        adapter.cancel()
        #expect(events.count == 3)
        #expect(events.first?.type == .mouseMoved)
        #expect(events.dropFirst().compactMap { NSEvent(cgEvent: $0)?.phase } == [.began, .cancelled])

        events.removeAll()
        let cannotPrepare = GestureEventAdapter(send: { events.append($0) }, makeMagnification: { delta, phase, point in
            phase == .cancelled ? nil : GestureEventAdapter.magnificationEvent(delta: delta, phase: phase, at: point)
        })
        #expect(cannotPrepare.magnify(delta: 0, phase: .began, at: anchor) == .failed)
        cannotPrepare.cancel()
        #expect(events.isEmpty)
    }

    @Test
    func normalPinchTerminationDoesNotSendAnAdditionalCancellation() {
        var phases: [NSEvent.Phase] = []
        let adapter = GestureEventAdapter(send: { event in
            if let native = NSEvent(cgEvent: event), native.type == .magnify { phases.append(native.phase) }
        })
        #expect(adapter.magnify(delta: 0, phase: .began, at: anchor) == .posted)
        #expect(adapter.magnify(delta: -0.1, phase: .changed, at: anchor) == .posted)
        #expect(adapter.magnify(delta: 0, phase: .ended, at: anchor) == .posted)
        adapter.cancel()
        #expect(adapter.magnify(delta: 0, phase: .cancelled, at: anchor) == .skipped)
        #expect(phases == [.began, .changed, .ended])
    }

    @Test
    func systemCommandsHaveMatchedKeysAndRespectPhysicalInput() throws {
        for (action, key) in [(SystemGesture.missionControl, 126), (.nextSpace, 124), (.previousSpace, 123)] {
            let events = try #require(GestureEventAdapter.systemEvents(action, at: anchor))
            #expect(events.map(\.type) == [.mouseMoved, .flagsChanged, .keyDown, .keyUp, .flagsChanged])
            #expect(events[0].location == CGPoint(x: anchor.x, y: anchor.y))
            #expect(events[1].getIntegerValueField(.keyboardEventKeycode) == 59)
            #expect(events[1].flags.contains(.maskControl))
            #expect(events[4].getIntegerValueField(.keyboardEventKeycode) == 59)
            #expect(events[4].flags.isEmpty)
            for event in events[2...3] {
                #expect(event.getIntegerValueField(.keyboardEventKeycode) == Int64(key))
                #expect(event.flags.contains([.maskControl, .maskNumericPad, .maskSecondaryFn]))
                #expect(event.flags.intersection([.maskShift, .maskAlternate, .maskCommand]).isEmpty)
                #expect(event.getIntegerValueField(.keyboardEventAutorepeat) == 0)
            }
        }
        var sent = 0
        let adapter = GestureEventAdapter(send: { _ in sent += 1 }, physicalInputHeld: { true })
        #expect(adapter.perform(.missionControl, at: anchor) == .skipped)
        #expect(sent == 0)
        #expect(GestureEventAdapter.systemEvents(.nextSpace, at: MappedPoint(x: .nan, y: 0)) == nil)

        // Model the synthesized modifier state left by each posted event. A
        // missing final release must block the second command in this regression.
        var held = false
        var delivered: [CGEventType] = []
        let repeated = GestureEventAdapter(send: { event in
            held = event.flags.contains(.maskControl)
            delivered.append(event.type)
        }, physicalInputHeld: { held })
        #expect(repeated.perform(.nextSpace, at: anchor) == .posted)
        #expect(!held)
        #expect(repeated.perform(.previousSpace, at: anchor) == .posted)
        #expect(!held)
        #expect(delivered.filter { $0 == .keyDown }.count == 2)
    }
}
