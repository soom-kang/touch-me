import Testing
@testable import TouchMappingCore

struct ProofSessionTests {
    private let first = MappedPoint(x: 120, y: 80)
    private let second = MappedPoint(x: 160, y: 100)

    @Test
    func testTapAndDragReleaseOnceOnLift() {
        var session = readySession()

        #expect(session.update(points: [first]) == [.down(first)])
        #expect(session.update(points: [first]) == [])
        #expect(session.update(points: []) == [.up(first)])
        #expect(session.update(points: []) == [])

        #expect(session.update(points: [first]) == [.down(first)])
        #expect(session.update(points: [second]) == [.drag(second)])
        #expect(session.update(points: [second]) == [])
        #expect(session.update(points: []) == [.up(second)])
        #expect(session.buttonPoint == nil)
        #expect(session.isRunning)
    }

    @Test
    func testStopReleasesOnceAndBlocksLaterInput() {
        var session = readySession()
        #expect(session.update(points: [first]) == [.down(first)])
        #expect(session.update(points: [second]) == [.drag(second)])

        #expect(session.stop() == [.up(second)])
        #expect(!session.isRunning)
        #expect(session.buttonPoint == nil)
        #expect(session.stop() == [])
        #expect(session.update(points: [first]) == [])
        #expect(session.update(points: []) == [])
    }

    @Test
    func testStartAndRestartRequireLiftBeforePressing() {
        var session = ProofSession()
        #expect(session.start() == [])
        #expect(session.update(points: [first]) == [])
        #expect(session.update(points: [second]) == [])
        #expect(session.update(points: []) == [])
        #expect(session.update(points: [first]) == [.down(first)])

        #expect(session.start() == [.up(first)])
        #expect(session.start() == [])
        #expect(session.update(points: [second]) == [])
        #expect(session.update(points: []) == [])
        #expect(session.update(points: [second]) == [.down(second)])

        #expect(session.stop() == [.up(second)])
        #expect(session.start() == [])
        #expect(session.update(points: [first]) == [])
        #expect(session.update(points: []) == [])
        #expect(session.update(points: [first]) == [.down(first)])
    }

    @Test
    func testUnsupportedAndRejectedContactsReleaseAndWaitForLift() {
        var session = readySession()
        #expect(session.update(points: [first]) == [.down(first)])
        #expect(session.update(points: [first, second, first]) == [.up(first)])
        #expect(session.buttonPoint == nil)
        #expect(session.update(points: [second]) == [])
        #expect(session.update(points: []) == [])
        #expect(session.update(points: [second]) == [.down(second)])

        #expect(session.rejectContact() == [.up(second)])
        #expect(session.rejectContact() == [])
        #expect(session.buttonPoint == nil)
        #expect(session.update(points: [first]) == [])
        #expect(session.update(points: []) == [])
        #expect(session.update(points: [first]) == [.down(first)])

        let invalid = MappedPoint(x: .infinity, y: 0)
        #expect(session.update(points: [first, invalid]) == [.up(first)])
        #expect(session.update(points: [first]) == [])
        #expect(session.update(points: []) == [])
        #expect(session.update(points: [invalid]) == [])
        #expect(session.update(points: [first]) == [])
        #expect(session.update(points: []) == [])
        #expect(session.update(points: [first]) == [.down(first)])
    }

    @Test
    func testTwoFingerScrollReleasesDragAndWaitsForAllFingersToLift() {
        var session = readySession()
        let midpoint = MappedPoint(x: 140, y: 90)
        let movedFirst = MappedPoint(x: 132, y: 72)
        let movedSecond = MappedPoint(x: 172, y: 92)
        let movedMidpoint = MappedPoint(x: 152, y: 82)

        #expect(session.update(points: [first]) == [.down(first)])
        #expect(session.update(points: [first, second]) == [.up(first)])
        #expect(session.buttonPoint == nil)
        #expect(session.update(points: [second, first]) == [])
        #expect(session.update(points: [movedFirst, movedSecond])
                == [.scroll(dx: 12, dy: -8, at: movedMidpoint)])
        #expect(session.update(points: [first, second])
                == [.scroll(dx: -12, dy: 8, at: midpoint)])

        #expect(session.update(points: [first]) == [])
        #expect(session.update(points: [first, second]) == [])
        #expect(session.update(points: []) == [])
        #expect(session.update(points: [first]) == [.down(first)])
    }

    @Test
    func testTwoFingerScrollClearsOnLiftRejectAndStop() {
        var session = readySession()
        let movedFirst = MappedPoint(x: 130, y: 90)
        let movedSecond = MappedPoint(x: 170, y: 110)

        #expect(session.update(points: [first, second]) == [])
        #expect(session.update(points: [movedFirst, movedSecond])
                == [.scroll(dx: 10, dy: 10, at: MappedPoint(x: 150, y: 100))])
        #expect(session.update(points: []) == [])
        #expect(session.update(points: [movedFirst, movedSecond]) == [])
        #expect(session.rejectContact() == [])
        #expect(session.update(points: [first, second]) == [])
        #expect(session.update(points: []) == [])
        #expect(session.update(points: [first, second]) == [])
        #expect(session.stop() == [])
        #expect(session.update(points: [movedFirst, movedSecond]) == [])
        #expect(session.start() == [])
        #expect(session.update(points: [first, second]) == [])
        #expect(session.update(points: []) == [])
        #expect(session.update(points: [movedFirst, movedSecond]) == [])
    }

    private func readySession() -> ProofSession {
        var session = ProofSession()
        session.start()
        #expect(session.update(points: []) == [])
        return session
    }
}
