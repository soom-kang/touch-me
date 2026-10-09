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
            [contact(first), contact(second, id: "secondary"), contact(first, id: "third")],
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
