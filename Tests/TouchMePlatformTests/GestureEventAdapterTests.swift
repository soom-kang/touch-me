import AppKit
import Testing
import TouchMappingCore
@testable import TouchMePlatform

struct GestureEventAdapterTests {
    private let anchor = MappedPoint(x: -300, y: 200)

    @Test
    func scrollFieldsRoundTripWithoutPosting() throws {
        let cases: [(ScrollPhase, CGScrollPhase, NSEvent.Phase, Int32, Int32)] = [
            (.began, .began, .began, 12, -8),
            (.changed, .changed, .changed, -3, 4),
            (.ended, .ended, .ended, 0, 0),
            (.cancelled, .cancelled, .cancelled, 0, 0)
        ]
        for (phase, cgPhase, nativePhase, dx, dy) in cases {
            let event = try #require(GestureEventAdapter.scrollEvent(dx: dx, dy: dy, phase: phase, at: anchor))
            let native = try #require(NSEvent(cgEvent: event))
            #expect(native.type == .scrollWheel)
            #expect(native.hasPreciseScrollingDeltas)
            #expect(native.phase == nativePhase)
            #expect(native.momentumPhase == [])
            #expect(Double(native.scrollingDeltaX) == Double(dx))
            #expect(Double(native.scrollingDeltaY) == Double(dy))
            #expect(event.getIntegerValueField(.scrollWheelEventScrollPhase) == Int64(cgPhase.rawValue))
            #expect(event.getIntegerValueField(.scrollWheelEventMomentumPhase) == 0)
            #expect(event.location == CGPoint(x: anchor.x, y: anchor.y))
        }
        #expect(GestureEventAdapter.scrollEvent(dx: 0, dy: 0, phase: .began, at: anchor) == nil)
        #expect(GestureEventAdapter.scrollEvent(dx: 1, dy: 0, phase: .ended, at: anchor) == nil)
        #expect(GestureEventAdapter.scrollEvent(dx: 1, dy: 0, phase: .began,
                                               at: MappedPoint(x: .nan, y: 0)) == nil)
    }

    @Test
    func scrollCompanionFormatAndAvailabilityWithoutPosting() throws {
        let cases: [(ScrollPhase, CGGesturePhase, NSEvent.Phase, Int32, Int32)] = [
            (.began, .began, .began, 12, -8),
            (.changed, .changed, .changed, -3, 4),
            (.ended, .ended, .ended, 0, 0),
            (.cancelled, .cancelled, .cancelled, 0, 0)
        ]
        let subtype = try #require(CGEventField(rawValue: 110))
        let deltaX = try #require(CGEventField(rawValue: 116))
        let deltaY = try #require(CGEventField(rawValue: 119))
        let phaseField = try #require(CGEventField(rawValue: 132))
        for (phase, cgPhase, nativePhase, dx, dy) in cases {
            let event = try #require(GestureEventAdapter.scrollCompanionEvent(dx: dx, dy: dy, phase: phase, at: anchor))
            let native = try #require(NSEvent(cgEvent: event))
            #expect(event.type.rawValue == 29)
            #expect(native.type == .gesture)
            #expect(native.phase == nativePhase)
            #expect(event.getIntegerValueField(subtype) == 6)
            #expect(event.getIntegerValueField(phaseField) == Int64(cgPhase.rawValue))
            #expect(event.getDoubleValueField(deltaX) == Double(dx))
            #expect(event.getDoubleValueField(deltaY) == Double(dy))
            #expect(event.location == CGPoint(x: anchor.x, y: anchor.y))
        }
        #expect(GestureEventAdapter.scrollCompanionEvent(dx: 0, dy: 0, phase: .began, at: anchor) == nil)
        #expect(GestureEventAdapter.scrollCompanionEvent(dx: 1, dy: 0, phase: .cancelled, at: anchor) == nil)
        #expect(GestureEventAdapter.scrollCompanionEvent(dx: 1, dy: 0, phase: .began,
                                                        at: MappedPoint(x: .infinity, y: 0)) == nil)
        #expect(GestureEventAdapter.pageSwipeAvailability(majorVersion: 26) == .available)
        var factoryCalled = false
        for majorVersion in [25, 27] {
            #expect(GestureEventAdapter.pageSwipeAvailability(majorVersion: majorVersion, makeCompanion: { _, _, _, _ in
                factoryCalled = true
                return nil
            }) == .unsupportedOS)
        }
        #expect(!factoryCalled)
        #expect(GestureEventAdapter.pageSwipeAvailability(majorVersion: 26, makeCompanion: { _, _, _, _ in nil }) == .eventFormatUnavailable)
        #expect(GestureEventAdapter.pageSwipeAvailability(majorVersion: 26, makeCompanion: GestureEventAdapter.scrollEvent) == .eventFormatUnavailable)

        // An unavailable companion leaves regular scrolling and pinch intact.
        for availability in [PageSwipeAvailability.unsupportedOS, .eventFormatUnavailable] {
            var events: [CGEvent] = []
            let adapter = GestureEventAdapter(send: { events.append($0) }, makeScrollCompanion: { _, _, _, _ in
                factoryCalled = true
                return nil
            }, pageSwipeAvailability: availability)
            #expect(adapter.scroll(dx: 6, dy: 0, phase: .began, at: anchor) == .posted)
            #expect(adapter.scroll(dx: 2, dy: 0, phase: .changed, at: anchor) == .posted)
            #expect(adapter.scroll(dx: 0, dy: 0, phase: .ended, at: anchor) == .posted)
            #expect(events.map(\.type) == [.mouseMoved, .scrollWheel, .scrollWheel, .scrollWheel])
            #expect(!factoryCalled)
            #expect(adapter.magnify(delta: 0, phase: .began, at: anchor) == .posted)
            adapter.cancel()
            #expect(events.last.flatMap { NSEvent(cgEvent: $0) }?.phase == .cancelled)
        }
    }

    @Test
    func scrollKeepsItsAnchorAndSignedRemaindersUntilTermination() throws {
        var events: [CGEvent] = []
        let adapter = GestureEventAdapter(send: { events.append($0) }, makeScroll: { dx, dy, phase, point in
            let event = GestureEventAdapter.scrollEvent(dx: dx, dy: dy, phase: phase, at: point)
            event?.timestamp = 1
            return event
        }, pageSwipeAvailability: .available)
        let moved = MappedPoint(x: 500, y: 600)
        #expect(adapter.scroll(dx: 6.2, dy: -6.2, phase: .began, at: anchor) == .posted)
        #expect(adapter.scroll(dx: 0.2, dy: -0.2, phase: .changed, at: moved) == .skipped)
        #expect(adapter.scroll(dx: -0.7, dy: 0.7, phase: .changed, at: moved) == .skipped)
        #expect(adapter.scroll(dx: -0.3, dy: 0.3, phase: .changed, at: moved) == .posted)
        #expect(adapter.scroll(dx: 0, dy: 0, phase: .ended, at: moved) == .posted)
        adapter.cancel()
        #expect(adapter.scroll(dx: 0, dy: 0, phase: .cancelled, at: moved) == .skipped)
        #expect(events.map { $0.type.rawValue } == [5, 22, 29, 22, 29, 22, 29])
        #expect(events.allSatisfy { $0.location == CGPoint(x: anchor.x, y: anchor.y) })
        let publicEvents = events.filter { $0.type == .scrollWheel }
        let companions = events.filter { $0.type.rawValue == 29 }
        let scrolls = try publicEvents.map { try #require(NSEvent(cgEvent: $0)) }
        #expect(scrolls.map(\.phase) == [.began, .changed, .ended])
        #expect(scrolls.map(\.scrollingDeltaX) == [6, -1, 0])
        #expect(scrolls.map(\.scrollingDeltaY) == [-6, 1, 0])
        let deltaX = try #require(CGEventField(rawValue: 116))
        let deltaY = try #require(CGEventField(rawValue: 119))
        for (scroll, companion) in zip(publicEvents, companions) {
            let native = try #require(NSEvent(cgEvent: scroll))
            #expect(companion.getDoubleValueField(deltaX) == Double(native.scrollingDeltaX))
            #expect(companion.getDoubleValueField(deltaY) == Double(native.scrollingDeltaY))
            #expect(NSEvent(cgEvent: companion)?.phase == native.phase)
            #expect(companion.timestamp == scroll.timestamp)
            #expect(companion.flags == scroll.flags)
        }
        // All phases receive dispatch time, including the preallocated terminal.
        let timestamps = events.dropFirst().map(\.timestamp)
        #expect(timestamps.allSatisfy { $0 > 1 })
        #expect(zip(timestamps, timestamps.dropFirst()).allSatisfy { $0 <= $1 })

        events.removeAll()
        // The previous signed remainder must not leak into the next gesture.
        #expect(adapter.scroll(dx: 6.2, dy: -6.2, phase: .began, at: moved) == .posted)
        let next = try #require(events.first(where: { $0.type == .scrollWheel }).flatMap { NSEvent(cgEvent: $0) })
        #expect(next.scrollingDeltaX == 6)
        #expect(next.scrollingDeltaY == -6)
        adapter.cancel()
    }

    @Test
    func scrollPreparesTerminalsAndCancelsOnceAfterAllocationFailure() {
        var events: [CGEvent] = []
        var failChanged = false
        let adapter = GestureEventAdapter(send: { events.append($0) }, makeScroll: { dx, dy, phase, point in
            if failChanged && phase == .changed { return nil }
            let event = GestureEventAdapter.scrollEvent(dx: dx, dy: dy, phase: phase, at: point)
            event?.timestamp = 1
            return event
        }, pageSwipeAvailability: .available)
        #expect(adapter.scroll(dx: 6, dy: 0, phase: .began, at: anchor) == .posted)
        failChanged = true
        #expect(adapter.scroll(dx: 3, dy: 0, phase: .changed, at: anchor) == .failed)
        adapter.cancel()
        adapter.cancel()
        #expect(events.count == 5)
        #expect(events.dropFirst().compactMap { NSEvent(cgEvent: $0)?.phase } == [.began, .began, .cancelled, .cancelled])
        #expect((events.last?.timestamp ?? 0) > 1)

        events.removeAll()
        let cannotPrepare = GestureEventAdapter(send: { events.append($0) }, makeScroll: { dx, dy, phase, point in
            phase == .cancelled ? nil : GestureEventAdapter.scrollEvent(dx: dx, dy: dy, phase: phase, at: point)
        }, pageSwipeAvailability: .available)
        #expect(cannotPrepare.scroll(dx: 6, dy: 0, phase: .began, at: anchor) == .failed)
        cannotPrepare.cancel()
        #expect(events.isEmpty)
        #expect(adapter.scroll(dx: .infinity, dy: 0, phase: .began, at: anchor) == .failed)
        #expect(adapter.scroll(dx: .nan, dy: 0, phase: .began, at: anchor) == .failed)
        #expect(events.isEmpty)
    }

    @Test
    func companionAllocationFailureNeverPostsHalfAPairAndCancelsOnce() {
        var events: [CGEvent] = []
        for failingPhase in [ScrollPhase.began, .ended, .cancelled] {
            let adapter = GestureEventAdapter(send: { events.append($0) }, makeScrollCompanion: { dx, dy, phase, point in
                phase == failingPhase ? nil : GestureEventAdapter.scrollCompanionEvent(dx: dx, dy: dy, phase: phase, at: point)
            }, pageSwipeAvailability: .available)
            #expect(adapter.scroll(dx: 6, dy: 0, phase: .began, at: anchor) == .failed)
            adapter.cancel()
            #expect(events.isEmpty)
        }

        var failChanged = false
        let adapter = GestureEventAdapter(send: { events.append($0) }, makeScrollCompanion: { dx, dy, phase, point in
            if failChanged && phase == .changed { return nil }
            let event = GestureEventAdapter.scrollCompanionEvent(dx: dx, dy: dy, phase: phase, at: point)
            event?.timestamp = 1
            return event
        }, pageSwipeAvailability: .available)
        #expect(adapter.scroll(dx: 6, dy: 0, phase: .began, at: anchor) == .posted)
        #expect(events.count == 3)
        failChanged = true
        #expect(adapter.scroll(dx: 2, dy: 0, phase: .changed, at: anchor) == .failed)
        #expect(events.count == 3)
        adapter.cancel()
        adapter.cancel()
        #expect(events.count == 5)
        #expect(events.suffix(2).compactMap { NSEvent(cgEvent: $0)?.phase } == [.cancelled, .cancelled])
        #expect(events[3].timestamp == events[4].timestamp)
        #expect(events[4].timestamp > 1)

        // Cleanup must also release a pinch if both lifecycles are present.
        events.removeAll()
        failChanged = false
        #expect(adapter.magnify(delta: 0, phase: .began, at: anchor) == .posted)
        #expect(adapter.scroll(dx: -6, dy: 0, phase: .began, at: anchor) == .posted)
        events.removeAll()
        adapter.cancel()
        adapter.cancel()
        #expect(events.count == 3)
        #expect(events.compactMap { NSEvent(cgEvent: $0)?.phase } == [.cancelled, .cancelled, .cancelled])
    }

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
