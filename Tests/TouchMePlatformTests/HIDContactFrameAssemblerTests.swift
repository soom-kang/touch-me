import Testing
import TouchMappingCore
@testable import TouchMePlatform

struct HIDContactFrameAssemblerTests {
    private func update(_ frame: HIDContactFrame?, session: inout ProofSession) -> [ProofAction] {
        guard let frame else { return [] }
        let down = frame.contacts.filter(\.down)
        let contacts = down.compactMap { contact -> ProofContact? in
            guard let x = contact.x, let y = contact.y else { return nil }
            return ProofContact(id: contact.key, point: MappedPoint(x: Double(x), y: Double(y)))
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
