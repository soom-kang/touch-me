import Testing
@testable import TouchMappingCore

struct ProofSessionTests {
    private let first = MappedPoint(x: 120, y: 80)
    private let second = MappedPoint(x: 160, y: 100)

    @Test
    func testTapAndDragReleaseOnceOnLift() {
        var session = readySession()
        let boundary = MappedPoint(x: 128, y: 80)
        let beyondBoundary = MappedPoint(x: 128.001, y: 80)
        let diagonal = MappedPoint(x: 126, y: 86)

        #expect(session.update(contacts: [contact(first)]) == [])
        #expect(session.buttonPoint == nil)
        #expect(session.update(contacts: [contact(boundary)]) == [])
        #expect(session.update(contacts: []) == [.down(boundary), .up(boundary)])
        #expect(session.update(contacts: []) == [])

        #expect(session.update(contacts: [contact(first)]) == [])
        #expect(session.update(contacts: [contact(boundary)]) == [])
        #expect(session.update(contacts: [contact(beyondBoundary)])
                == [.down(first), .drag(beyondBoundary)])
        #expect(session.update(contacts: [contact(second)]) == [.drag(second)])
        #expect(session.update(contacts: [contact(second)]) == [])
        #expect(session.update(contacts: []) == [.up(second)])
        #expect(session.update(contacts: []) == [])

        #expect(session.update(contacts: [contact(first)]) == [])
        #expect(session.update(contacts: [contact(diagonal)])
                == [.down(first), .drag(diagonal)])
        #expect(session.update(contacts: []) == [.up(diagonal)])
        #expect(session.buttonPoint == nil)
        #expect(session.isRunning)
    }

    @Test
    func testStopReleasesOnceAndBlocksLaterInput() {
        var session = readySession()
        #expect(session.update(contacts: [contact(first)]) == [])
        #expect(session.stop() == [])
        #expect(session.update(contacts: []) == [])
        #expect(session.start() == [])
        #expect(session.update(contacts: []) == [])
        #expect(session.update(contacts: [contact(first)]) == [])
        #expect(session.update(contacts: [contact(second)]) == [.down(first), .drag(second)])

        #expect(session.stop() == [.up(second)])
        #expect(!session.isRunning)
        #expect(session.buttonPoint == nil)
        #expect(session.stop() == [])
        #expect(session.update(contacts: [contact(first)]) == [])
        #expect(session.update(contacts: []) == [])
    }

    @Test
    func testStartAndRestartRequireLiftBeforePressing() {
        var session = ProofSession()
        #expect(session.start() == [])
        #expect(session.update(contacts: [contact(first)]) == [])
        #expect(session.update(contacts: [contact(second)]) == [])
        #expect(session.update(contacts: []) == [])
        #expect(session.update(contacts: [contact(first)]) == [])

        #expect(session.start() == [])
        #expect(session.start() == [])
        #expect(session.update(contacts: [contact(second)]) == [])
        #expect(session.update(contacts: []) == [])
        #expect(session.update(contacts: [contact(first)]) == [])
        #expect(session.update(contacts: [contact(second)]) == [.down(first), .drag(second)])

        #expect(session.start() == [.up(second)])
        #expect(session.update(contacts: [contact(first)]) == [])
        #expect(session.update(contacts: []) == [])
        #expect(session.update(contacts: [contact(first)]) == [])
        #expect(session.stop() == [])
        #expect(session.start() == [])
        #expect(session.update(contacts: [contact(first)]) == [])
        #expect(session.update(contacts: []) == [])
        #expect(session.update(contacts: [contact(first)]) == [])
        #expect(session.update(contacts: []) == [.down(first), .up(first)])
    }

    @Test
    func testUnsupportedAndRejectedContactsReleaseAndWaitForLift() {
        var session = readySession()
        let invalid = MappedPoint(x: .infinity, y: 0)
        let rejectedInputs = [
            [contact(first), contact(second, id: "secondary"), contact(first, id: "third"), contact(second, id: "fourth")],
            [contact(first), contact(invalid, id: "secondary")],
            [contact(first), contact(second)]
        ]
        for contacts in rejectedInputs {
            #expect(session.update(contacts: [contact(first)]) == [])
            #expect(session.update(contacts: contacts) == [])
            #expect(session.buttonPoint == nil)
            #expect(session.update(contacts: [contact(second)]) == [])
            #expect(session.update(contacts: []) == [])

            #expect(session.update(contacts: [contact(first)]) == [])
            #expect(session.update(contacts: [contact(second)]) == [.down(first), .drag(second)])
            #expect(session.update(contacts: contacts) == [.up(second)])
            #expect(session.update(contacts: [contact(first)]) == [])
            #expect(session.update(contacts: []) == [])
        }

        #expect(session.update(contacts: [contact(first)]) == [])
        #expect(session.rejectContact() == [])
        #expect(session.buttonPoint == nil)
        #expect(session.update(contacts: []) == [])
        #expect(session.update(contacts: [contact(first)]) == [])
        #expect(session.update(contacts: [contact(second)]) == [.down(first), .drag(second)])
        #expect(session.rejectContact() == [.up(second)])
        #expect(session.rejectContact() == [])
        #expect(session.update(contacts: [contact(first)]) == [])
        #expect(session.update(contacts: []) == [])

        #expect(session.update(contacts: [contact(first)]) == [])
        #expect(session.update(contacts: [contact(second, id: "secondary")]) == [])
        #expect(session.update(contacts: [contact(first)]) == [])
        #expect(session.update(contacts: []) == [])
        #expect(session.update(contacts: [contact(first)]) == [])
        #expect(session.update(contacts: []) == [.down(first), .up(first)])
    }

    @Test
    func testTwoFingerInputScrollsOrPreservesEstablishedDragUntilLift() {
        var session = readySession()
        let midpoint = MappedPoint(x: 140, y: 90)
        let movedFirst = MappedPoint(x: 132, y: 72)
        let movedSecond = MappedPoint(x: 172, y: 92)
        let movedMidpoint = MappedPoint(x: 152, y: 82)

        #expect(session.update(contacts: [contact(first)]) == [])
        #expect(session.update(contacts: [contact(first), contact(second, id: "secondary")]) == [])
        #expect(session.buttonPoint == nil)
        #expect(session.update(contacts: [contact(second, id: "secondary"), contact(first)]) == [])
        #expect(session.update(contacts: [contact(movedFirst), contact(movedSecond, id: "secondary")])
                == [.scroll(dx: 12, dy: -8, at: movedMidpoint)])
        #expect(session.update(contacts: [contact(first), contact(second, id: "secondary")])
                == [.scroll(dx: -12, dy: 8, at: midpoint)])

        #expect(session.update(contacts: [contact(first)]) == [])
        #expect(session.update(contacts: [contact(first), contact(second, id: "secondary")]) == [])
        #expect(session.update(contacts: []) == [])
        #expect(session.update(contacts: [contact(first)]) == [])
        #expect(session.update(contacts: [contact(movedFirst)]) == [.down(first), .drag(movedFirst)])
        #expect(session.update(contacts: [contact(movedSecond, id: "secondary"), contact(first)])
                == [.drag(first)])
        #expect(session.update(contacts: [contact(first), contact(second, id: "secondary")]) == [])
        #expect(session.update(contacts: [contact(movedSecond, id: "secondary")]) == [.up(first)])
        #expect(session.update(contacts: [contact(first), contact(second, id: "secondary")]) == [])
        #expect(session.update(contacts: []) == [])
        #expect(session.update(contacts: [contact(first)]) == [])
        #expect(session.update(contacts: []) == [.down(first), .up(first)])
    }

    @Test
    func testTwoFingerScrollClearsOnLiftRejectAndStop() {
        var session = readySession()
        let movedFirst = MappedPoint(x: 130, y: 90)
        let movedSecond = MappedPoint(x: 170, y: 110)

        #expect(session.update(contacts: [contact(first), contact(second, id: "secondary")]) == [])
        #expect(session.update(contacts: [contact(movedFirst), contact(movedSecond, id: "secondary")])
                == [.scroll(dx: 10, dy: 10, at: MappedPoint(x: 150, y: 100))])
        #expect(session.update(contacts: []) == [])
        #expect(session.update(contacts: [contact(movedFirst), contact(movedSecond, id: "secondary")]) == [])
        #expect(session.rejectContact() == [])
        #expect(session.update(contacts: [contact(first), contact(second, id: "secondary")]) == [])
        #expect(session.update(contacts: []) == [])
        #expect(session.update(contacts: [contact(first), contact(second, id: "secondary")]) == [])
        #expect(session.stop() == [])
        #expect(session.update(contacts: [contact(movedFirst), contact(movedSecond, id: "secondary")]) == [])
        #expect(session.start() == [])
        #expect(session.update(contacts: [contact(first), contact(second, id: "secondary")]) == [])
        #expect(session.update(contacts: []) == [])
        #expect(session.update(contacts: [contact(movedFirst), contact(movedSecond, id: "secondary")]) == [])
    }

    @Test
    func pinchLocksToItsAnchorAndEndsWithoutClickOnPartialLift() {
        var session = readySession()
        let pair = [contact(MappedPoint(x: -100, y: 80)), contact(MappedPoint(x: 0, y: 80), id: "B")]
        let anchor = MappedPoint(x: -50, y: 80)
        #expect(session.update(contacts: pair) == [])
        let spread = [pair[0], contact(MappedPoint(x: 20, y: 80), id: "B")]
        let actions = session.update(contacts: spread)
        #expect(actions.count == 2)
        #expect(actions.first == .magnify(delta: 0, phase: .began, at: anchor))
        if case .magnify(let delta, .changed, anchor) = actions.last {
            #expect(abs(delta - 0.2) < 0.000001)
        } else { Issue.record("Expected continuous pinch, including one stationary finger") }
        // Translation after pinch commitment cannot turn into scroll or retarget the view.
        #expect(session.update(contacts: [contact(MappedPoint(x: -80, y: 100)),
                                          contact(MappedPoint(x: 40, y: 100), id: "B")]) == [])
        #expect(session.update(contacts: [spread[0]]) == [.magnify(delta: 0, phase: .ended, at: anchor)])
        #expect(session.update(contacts: spread) == [])
        #expect(session.update(contacts: []) == [])
        #expect(session.update(contacts: [contact(first)]) == [])
        #expect(session.update(contacts: []) == [.down(first), .up(first)])
    }

    @Test
    func pinchCancellationAndStopReleaseExactlyOnce() {
        let anchor = MappedPoint(x: 50, y: 100)
        for reason in 0..<6 {
            var session = readySession()
            let pair = [contact(MappedPoint(x: 0, y: 100)), contact(MappedPoint(x: 100, y: 100), id: "B")]
            _ = session.update(contacts: pair)
            let closer = [pair[0], contact(MappedPoint(x: 80, y: 100), id: "B")]
            #expect(session.update(contacts: closer).count == 2)
            let cancelled: [ProofAction]
            switch reason {
            case 0: cancelled = session.stop()
            case 1: cancelled = session.rejectContact()
            case 2: cancelled = session.setMagnificationEnabled(false)
            case 3: cancelled = session.update(contacts: closer + [contact(first, id: "C")])
            case 4: cancelled = session.update(contacts: [closer[0], contact(closer[1].point, id: "replacement")])
            default: cancelled = session.update(contacts: [closer[0], contact(closer[0].point, id: "B")])
            }
            #expect(cancelled == [.magnify(delta: 0, phase: .cancelled, at: anchor)])
            #expect(session.rejectContact() == [])
            #expect(session.update(contacts: closer) == [])
            #expect(session.start() == [])
            #expect(session.update(contacts: pair) == [])
            #expect(session.update(contacts: []) == [])
        }
    }

    @Test
    func twoFingerThresholdsAmbiguityAndScrollOwnership() {
        var session = readySession()
        let pair = [contact(MappedPoint(x: 0, y: 0)), contact(MappedPoint(x: 100, y: 0), id: "B")]
        _ = session.update(contacts: pair)
        // Below both thresholds, then equal center/separation changes: remain undecided.
        #expect(session.update(contacts: [pair[0], contact(MappedPoint(x: 105, y: 0), id: "B")]) == [])
        #expect(session.update(contacts: [contact(MappedPoint(x: 5, y: 0)), contact(MappedPoint(x: 115, y: 0), id: "B")]) == [])
        let shifted = [contact(MappedPoint(x: 6, y: 0)), contact(MappedPoint(x: 106, y: 0), id: "B")]
        #expect(session.update(contacts: shifted) == [.scroll(dx: 6, dy: 0, at: MappedPoint(x: 56, y: 0))])
        #expect(session.update(contacts: [contact(MappedPoint(x: -4, y: 0)), contact(MappedPoint(x: 116, y: 0), id: "B")]) == [])
        #expect(session.update(contacts: shifted + [contact(first, id: "C")]) == [])
        #expect(session.update(contacts: shifted) == [])
        #expect(session.update(contacts: []) == [])
        _ = session.update(contacts: pair)
        _ = session.update(contacts: shifted)
        #expect(session.update(contacts: [shifted[0], contact(shifted[1].point, id: "new-generation")]) == [])
        #expect(session.update(contacts: []) == [])
    }

    @Test
    func disabledPinchAndDegenerateGeometryDoNotEmitMagnification() {
        var session = readySession()
        _ = session.setMagnificationEnabled(false)
        let pair = [contact(MappedPoint(x: 0, y: 0)), contact(MappedPoint(x: 100, y: 0), id: "B")]
        _ = session.update(contacts: pair)
        #expect(session.update(contacts: [pair[0], contact(MappedPoint(x: 120, y: 0), id: "B")])
                == [.scroll(dx: 10, dy: 0, at: MappedPoint(x: 60, y: 0))])
        _ = session.update(contacts: [])
        _ = session.setMagnificationEnabled(true)
        _ = session.update(contacts: [pair[0], contact(pair[0].point, id: "B")])
        #expect(session.update(contacts: pair) == [])
        _ = session.update(contacts: [])
        let extreme = Double.greatestFiniteMagnitude
        #expect(session.update(contacts: [contact(MappedPoint(x: -extreme, y: 0)),
                                          contact(MappedPoint(x: extreme, y: 0), id: "B")]) == [])
        #expect(session.update(contacts: pair) == [])
        #expect(session.update(contacts: []) == [])
    }

    @Test
    func staggeredThreeFingerSwipesAreDirectionalAndConsumedUntilLift() {
        let initial = [contact(MappedPoint(x: -200, y: 100)),
                       contact(MappedPoint(x: -100, y: 100), id: "B"),
                       contact(MappedPoint(x: 0, y: 100), id: "C")]
        let anchor = MappedPoint(x: -100, y: 100)
        let cases: [(Double, Double, SystemGesture?)] = [(0, -40, .missionControl), (-40, 0, .nextSpace), (40, 0, .previousSpace), (0, 40, nil)]
        for (dx, dy, expected) in cases {
            var session = readySession()
            _ = session.update(contacts: [initial[0]])
            _ = session.update(contacts: Array(initial.prefix(2)))
            #expect(session.update(contacts: initial) == [])
            let shifted = initial.reversed().map { contact(MappedPoint(x: $0.point.x + dx, y: $0.point.y + dy), id: $0.id) }
            #expect(session.update(contacts: shifted) == expected.map { [.systemGesture(action: $0, at: anchor)] } ?? [])
            #expect(session.update(contacts: shifted) == [])
            #expect(session.update(contacts: initial) == [])
            #expect(session.update(contacts: Array(initial.prefix(2))) == [])
            #expect(session.update(contacts: []) == [])
            #expect(session.update(contacts: initial) == [])
        }
    }

    @Test
    func threeFingerNoiseReplacementAndDragCannotSwitchSpaces() {
        let initial = [contact(MappedPoint(x: 0, y: 0)), contact(MappedPoint(x: 100, y: 0), id: "B"), contact(MappedPoint(x: 200, y: 0), id: "C")]
        var session = readySession()
        _ = session.update(contacts: initial)
        // One moving finger and diagonal motion do not qualify.
        #expect(session.update(contacts: [contact(MappedPoint(x: 150, y: 0)), initial[1], initial[2]]) == [])
        #expect(session.update(contacts: initial.map { contact(MappedPoint(x: $0.point.x + 40, y: 40), id: $0.id) }) == [])
        #expect(session.update(contacts: [initial[0], initial[1], contact(initial[2].point, id: "new-C")]) == [])
        #expect(session.update(contacts: initial.map { contact(MappedPoint(x: $0.point.x, y: -60), id: $0.id) }) == [])
        _ = session.update(contacts: [])
        _ = session.update(contacts: [initial[0]])
        let moved = MappedPoint(x: 10, y: 0)
        #expect(session.update(contacts: [contact(moved)]) == [.down(initial[0].point), .drag(moved)])
        #expect(session.update(contacts: initial) == [.up(moved)])
        #expect(session.update(contacts: []) == [])
    }

    private func readySession() -> ProofSession {
        var session = ProofSession()
        session.start()
        #expect(session.update(contacts: []) == [])
        return session
    }

    private func contact(_ point: MappedPoint, id: String = "primary") -> ProofContact {
        ProofContact(id: id, point: point)
    }
}
