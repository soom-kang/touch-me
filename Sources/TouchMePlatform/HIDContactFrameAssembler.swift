/// A callback value and a synchronous read are not necessarily from the same report.
struct HIDContactValue {
    let integer: Int
    let timestamp: UInt64
}

enum HIDContactField: Equatable {
    case x, y, tip
}

struct HIDContactFrame {
    struct Contact {
        let key: String
        let x: Int?
        let y: Int?
        let down: Bool
    }
    let contacts: [Contact]
}

/// Keeps queued report coordinates intact. IOKit is confined to the read adapter.
struct HIDContactFrameAssembler {
    private struct State {
        var x: HIDContactValue? = nil
        var y: HIDContactValue? = nil
        var down: Bool
        var needsCoordinates: Bool
    }
    private var states: [String: State] = [:]
    private(set) var pendingTimestamp: UInt64?
    var allLifted: Bool { states.values.allSatisfy { !$0.down } }

    mutating func addContact(key: String, down: Bool) {
        states[key] = State(down: down, needsCoordinates: down)
    }

    mutating func receive(key: String, field: HIDContactField, value: HIDContactValue,
                          read: (String, HIDContactField) throws -> HIDContactValue) rethrows -> HIDContactFrame? {
        guard states[key] != nil else { return nil }
        let previous: HIDContactFrame?
        if let pendingTimestamp, pendingTimestamp != value.timestamp {
            previous = try flush(read: read)
        } else {
            previous = nil
        }
        // Read the state after flushing; never restore a pre-flush value copy.
        guard var state = states[key] else { return previous }
        pendingTimestamp = value.timestamp
        switch field {
        case .x: state.x = value
        case .y: state.y = value
        case .tip:
            let down = value.integer != 0
            if down && !state.down { state.needsCoordinates = true }
            state.down = down
        }
        states[key] = state
        return previous
    }

    mutating func flush(read: (String, HIDContactField) throws -> HIDContactValue) rethrows -> HIDContactFrame? {
        guard let timestamp = pendingTimestamp else { return nil }
        for key in Array(states.keys) {
            guard var state = states[key], state.down, state.needsCoordinates else { continue }
            // Callbacks from this report win, including X -> Tip -> Y order.
            // A reused slot's unchanged axis must be checked against the driver,
            // not copied from the previous gesture. Future reads cannot fill it.
            if state.x?.timestamp != timestamp {
                let value = try read(key, .x)
                state.x = value.timestamp <= timestamp ? value : nil
            }
            if state.y?.timestamp != timestamp {
                let value = try read(key, .y)
                state.y = value.timestamp <= timestamp ? value : nil
            }
            state.needsCoordinates = false
            states[key] = state
        }
        pendingTimestamp = nil
        return HIDContactFrame(contacts: states.keys.sorted().compactMap { key in
            guard let state = states[key] else { return nil }
            return HIDContactFrame.Contact(key: key,
                x: state.x.flatMap { $0.timestamp <= timestamp ? $0.integer : nil },
                y: state.y.flatMap { $0.timestamp <= timestamp ? $0.integer : nil },
                down: state.down)
        })
    }
}
