import Testing
import TouchMappingCore
@testable import TouchMePlatform

struct HIDContactFrameAssemblerTests {
    @Test
    func dormantMouseCannotBlockDigitizerTapScrollOrLift() {
        var (assembler, session) = selectedSession([
            ("mouse", false, true), ("A", true, false), ("B", true, false)
        ])
        #expect(assembler.allLifted)
        #expect(deliver([("mouse", .x, 900), ("mouse", .y, 900), ("mouse", .tip, 1)],
                        at: 1, assembler: &assembler, session: &session).isEmpty)
        #expect(deliver([("A", .x, 100), ("A", .y, 100), ("A", .tip, 1)],
                        at: 2, assembler: &assembler, session: &session).isEmpty)
        #expect(deliver([("A", .tip, 0)], at: 3, assembler: &assembler, session: &session)
                == [.down(MappedPoint(x: 100, y: 100)), .up(MappedPoint(x: 100, y: 100))])

        #expect(deliver([("A", .x, 100), ("A", .y, 100), ("A", .tip, 1),
                        ("B", .x, 200), ("B", .y, 100), ("B", .tip, 1)],
                        at: 4, assembler: &assembler, session: &session).isEmpty)
        let anchor = MappedPoint(x: 150, y: 100)
        #expect(deliver([("A", .y, 112), ("B", .y, 112), ("mouse", .tip, 1)],
                        at: 5, assembler: &assembler, session: &session)
                == [.scroll(dx: 0, dy: 12, phase: .began, at: anchor)])
        #expect(deliver([("A", .tip, 0)], at: 6, assembler: &assembler, session: &session)
                == [.scroll(dx: 0, dy: 0, phase: .ended, at: anchor)])
        #expect(deliver([("B", .y, 130)], at: 7, assembler: &assembler, session: &session).isEmpty)
        #expect(deliver([("B", .tip, 0)], at: 8, assembler: &assembler, session: &session).isEmpty)
        #expect(assembler.allLifted)
        #expect(deliver([("A", .x, 150), ("A", .y, 140), ("A", .tip, 1)],
                        at: 9, assembler: &assembler, session: &session).isEmpty)
        #expect(deliver([("A", .tip, 0)], at: 10, assembler: &assembler, session: &session)
                == [.down(MappedPoint(x: 150, y: 140)), .up(MappedPoint(x: 150, y: 140))])
    }

    @Test
    func selectedDigitizerInitiallyDownStillRequiresItsOwnLift() {
        var (assembler, session) = selectedSession([("mouse", false, true), ("A", true, true)])
        #expect(!assembler.allLifted)
        #expect(deliver([("A", .x, 100), ("A", .y, 100), ("A", .tip, 1)],
                        at: 1, assembler: &assembler, session: &session).isEmpty)
        #expect(deliver([("A", .x, 120)], at: 2, assembler: &assembler, session: &session).isEmpty)
        #expect(deliver([("mouse", .tip, 0)], at: 3, assembler: &assembler, session: &session).isEmpty)
        #expect(!assembler.allLifted)
        #expect(deliver([("A", .tip, 0)], at: 4, assembler: &assembler, session: &session).isEmpty)
        #expect(assembler.allLifted)
        #expect(deliver([("A", .x, 200), ("A", .y, 200), ("A", .tip, 1)],
                        at: 5, assembler: &assembler, session: &session).isEmpty)
        #expect(deliver([("A", .x, 220)], at: 6, assembler: &assembler, session: &session)
                == [.down(MappedPoint(x: 200, y: 200)), .drag(MappedPoint(x: 220, y: 200))])
        #expect(deliver([("A", .tip, 0)], at: 7, assembler: &assembler, session: &session)
                == [.up(MappedPoint(x: 220, y: 200))])
    }

    @Test
    func missingSelectedCoordinatesCancelWithoutFallingBackToMouse() {
        var (assembler, session) = selectedSession([
            ("mouse", false, true), ("A", true, false), ("B", true, false)
        ])
        #expect(deliver([("A", .x, 100), ("A", .y, 100), ("A", .tip, 1)],
                        at: 1, assembler: &assembler, session: &session).isEmpty)
        #expect(deliver([("A", .x, 120)], at: 2, assembler: &assembler, session: &session)
                == [.down(MappedPoint(x: 100, y: 100)), .drag(MappedPoint(x: 120, y: 100))])
        var reads = 0
        // The second digitizer has not delivered Y, and a later report cannot fill it.
        let cancelled = deliver([("B", .x, 200), ("B", .tip, 1)],
                        at: 3, assembler: &assembler, session: &session, read: { key, field in
            reads += 1
            #expect(key == "B" && field == .y)
            return HIDContactValue(integer: 100, timestamp: 4)
        })
        #expect(cancelled == [.up(MappedPoint(x: 120, y: 100))])
        #expect(reads == 1)
        #expect(deliver([("B", .y, 100), ("mouse", .x, 900), ("mouse", .y, 900), ("mouse", .tip, 1)],
                        at: 4, assembler: &assembler, session: &session).isEmpty)
        #expect(deliver([("A", .tip, 0)], at: 5, assembler: &assembler, session: &session).isEmpty)
        #expect(deliver([("mouse", .tip, 0)], at: 6, assembler: &assembler, session: &session).isEmpty)
        #expect(!assembler.allLifted)
        #expect(deliver([("B", .tip, 0)], at: 7, assembler: &assembler, session: &session).isEmpty)
        #expect(assembler.allLifted)
        #expect(deliver([("A", .x, 150), ("A", .y, 140), ("A", .tip, 1)],
                        at: 8, assembler: &assembler, session: &session).isEmpty)
        #expect(deliver([("A", .tip, 0)], at: 9, assembler: &assembler, session: &session)
                == [.down(MappedPoint(x: 150, y: 140)), .up(MappedPoint(x: 150, y: 140))])
    }

    @Test
    func pointerOnlyDescriptorRetainsTapAndDragInput() {
        var (assembler, session) = selectedSession([("mouse", false, false)])
        #expect(deliver([("mouse", .x, 50), ("mouse", .y, 60), ("mouse", .tip, 1)],
                        at: 1, assembler: &assembler, session: &session).isEmpty)
        #expect(deliver([("mouse", .tip, 0)], at: 2, assembler: &assembler, session: &session)
                == [.down(MappedPoint(x: 50, y: 60)), .up(MappedPoint(x: 50, y: 60))])
        #expect(deliver([("mouse", .x, 50), ("mouse", .y, 60), ("mouse", .tip, 1)],
                        at: 3, assembler: &assembler, session: &session).isEmpty)
        #expect(deliver([("mouse", .x, 80)], at: 4, assembler: &assembler, session: &session)
                == [.down(MappedPoint(x: 50, y: 60)), .drag(MappedPoint(x: 80, y: 60))])
        #expect(deliver([("mouse", .tip, 0)], at: 5, assembler: &assembler, session: &session)
                == [.up(MappedPoint(x: 80, y: 60))])
    }

    private func selectedSession(_ contacts: [(key: String, isDigitizer: Bool, down: Bool)])
        -> (HIDContactFrameAssembler, ProofSession) {
        let keys = HIDContactLayout.mappingKeys(contacts.map { ($0.key, $0.isDigitizer) })
        var assembler = HIDContactFrameAssembler()
        for contact in contacts where keys.contains(contact.key) {
            assembler.addContact(key: contact.key, down: contact.down)
        }
        var session = ProofSession()
        session.start()
        if assembler.allLifted { _ = session.update(contacts: []) }
        return (assembler, session)
    }

    private func deliver(_ values: [(String, HIDContactField, Int)], at timestamp: UInt64,
                         assembler: inout HIDContactFrameAssembler, session: inout ProofSession,
                         read: (String, HIDContactField) -> HIDContactValue = { _, _ in
                             Issue.record("Complete report coordinates must not be reread")
                             return HIDContactValue(integer: 0, timestamp: 0)
                         }) -> [ProofAction] {
        var actions: [ProofAction] = []
        for (key, field, integer) in values {
            actions += update(assembler.receive(key: key, field: field,
                value: HIDContactValue(integer: integer, timestamp: timestamp), read: read), session: &session)
        }
        actions += update(assembler.flush(read: read), session: &session)
        return actions
    }

    @Test
    func sameReportSlotReplacementCancelsThePreviousDrag() {
        var assembler = HIDContactFrameAssembler()
        assembler.addContact(key: "A", down: false)
        var session = ProofSession()
        session.start()
        _ = session.update(contacts: [])
        let read: (String, HIDContactField) -> HIDContactValue = { _, _ in
            Issue.record("Coordinates in the report must not be reread")
            return HIDContactValue(integer: 0, timestamp: 0)
        }
        for (timestamp, x) in [(UInt64(1), 100), (UInt64(2), 120)] {
            let fields: [(HIDContactField, Int)] = [(.x, x), (.y, 100), (.tip, 1)]
            for (field, value) in fields {
                _ = assembler.receive(key: "A", field: field, value: HIDContactValue(integer: value, timestamp: timestamp), read: read)
            }
            _ = update(assembler.flush(read: read), session: &session)
        }
        #expect(session.buttonPoint == MappedPoint(x: 120, y: 100))
        let replacement: [(HIDContactField, Int)] = [(.tip, 0), (.x, 200), (.tip, 1), (.y, 100)]
        for (field, value) in replacement {
            _ = assembler.receive(key: "A", field: field, value: HIDContactValue(integer: value, timestamp: 3), read: read)
        }
        let frame = assembler.flush(read: read)
        #expect(frame?.contacts.first?.generation == 2)
        #expect(update(frame, session: &session) == [.up(MappedPoint(x: 120, y: 100))])
        #expect(session.buttonPoint == nil)
    }

    private func update(_ frame: HIDContactFrame?, session: inout ProofSession) -> [ProofAction] {
        guard let frame else { return [] }
        let down = frame.contacts.filter(\.down)
        let contacts = down.compactMap { contact -> ProofContact? in
            guard let x = contact.x, let y = contact.y else { return nil }
            return ProofContact(id: contact.identity, point: MappedPoint(x: Double(x), y: Double(y)))
        }
        return contacts.count == down.count ? session.update(contacts: contacts) : session.rejectContact()
    }

    @Test
    func queuedAndMixedDeliveryPreserveDragWithoutReadingOverReportCoordinates() {
        let orders: [[(HIDContactField, Int)]] = [
            [(.x, 100), (.y, 100), (.tip, 1)],
            [(.x, 100), (.tip, 1), (.y, 100)],
            [(.tip, 1), (.y, 100), (.x, 100)],
        ]
        let schedules: [Set<UInt64>] = [[], [1, 2, 3, 4], [1, 3]]
        for order in orders {
            for flushAfter in schedules {
                var assembler = HIDContactFrameAssembler()
                assembler.addContact(key: "A", down: false)
                var session = ProofSession()
                session.start()
                _ = session.update(contacts: [])
                var reads = 0
                let read: (String, HIDContactField) -> HIDContactValue = { _, field in
                    reads += 1
                    // The device is already at the end of the queued gesture.
                    return HIDContactValue(integer: field == .x ? 300 : 100, timestamp: 3)
                }
                let reports = [order, [(.x, 200)], [(.x, 300)], [(.tip, 0)]]
                var actions: [ProofAction] = []
                for (index, report) in reports.enumerated() {
                    let timestamp = UInt64(index + 1)
                    for (field, integer) in report {
                        actions += update(assembler.receive(key: "A", field: field,
                            value: HIDContactValue(integer: integer, timestamp: timestamp), read: read), session: &session)
                    }
                    if flushAfter.contains(timestamp) {
                        actions += update(assembler.flush(read: read), session: &session)
                    }
                }
                actions += update(assembler.flush(read: read), session: &session)
                #expect(actions == [.down(MappedPoint(x: 100, y: 100)),
                                    .drag(MappedPoint(x: 200, y: 100)),
                                    .drag(MappedPoint(x: 300, y: 100)),
                                    .up(MappedPoint(x: 300, y: 100))])
                #expect(reads == 0)
            }
        }
    }

    @Test
    func reusedSlotChecksUnchangedAxisAndRejectsFutureSnapshotUntilLift() {
        for future in [false, true] {
            var assembler = HIDContactFrameAssembler()
            assembler.addContact(key: "A", down: false)
            var session = ProofSession()
            session.start()
            _ = session.update(contacts: [])
            var reads = 0
            let read: (String, HIDContactField) -> HIDContactValue = { _, field in
                reads += 1
                #expect(field == .y)
                return HIDContactValue(integer: 70, timestamp: future ? 4 : 2)
            }
            let initial: [(HIDContactField, Int)] = [(.x, 10), (.y, 20), (.tip, 1)]
            for (field, integer) in initial {
                _ = assembler.receive(key: "A", field: field,
                    value: HIDContactValue(integer: integer, timestamp: 1), read: read)
            }
            _ = update(assembler.flush(read: read), session: &session)
            _ = assembler.receive(key: "A", field: .tip, value: HIDContactValue(integer: 0, timestamp: 2), read: read)
            _ = update(assembler.flush(read: read), session: &session)
            // The new contact reports X before Tip; Y has not changed since lift.
            _ = assembler.receive(key: "A", field: .x, value: HIDContactValue(integer: 300, timestamp: 3), read: read)
            _ = assembler.receive(key: "A", field: .tip, value: HIDContactValue(integer: 1, timestamp: 3), read: read)
            let start = assembler.receive(key: "A", field: .x,
                value: HIDContactValue(integer: 400, timestamp: 4), read: read)
            #expect(start?.contacts.first?.x == 300)
            #expect(start?.contacts.first?.y == (future ? nil : 70))
            var actions = update(start, session: &session)
            actions += update(assembler.receive(key: "A", field: .tip,
                value: HIDContactValue(integer: 0, timestamp: 5), read: read), session: &session)
            actions += update(assembler.flush(read: read), session: &session)
            #expect(reads == 1)
            #expect(actions == (future ? [] : [.down(MappedPoint(x: 300, y: 70)),
                                              .drag(MappedPoint(x: 400, y: 70)),
                                              .up(MappedPoint(x: 400, y: 70))]))
        }
    }
}
