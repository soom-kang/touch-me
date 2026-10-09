import Foundation

public enum ProofAction: Equatable {
    case down(MappedPoint)
    case drag(MappedPoint)
    case up(MappedPoint)
    case scroll(dx: Double, dy: Double, at: MappedPoint)
}

public struct ProofContact: Equatable {
    public let id: String
    public let point: MappedPoint

    public init(id: String, point: MappedPoint) {
        self.id = id
        self.point = point
    }
}

/// Taps click on lift; movement commits a drag; two uncommitted contacts scroll.
public struct ProofSession {
    private enum Gesture {
        case idle
        case pending(id: String, origin: MappedPoint, point: MappedPoint)
        case dragging(id: String)
        case scrolling(MappedPoint)
    }

    private static let maximumTapDistance = 8.0
    public private(set) var isRunning = false
    public private(set) var buttonPoint: MappedPoint?
    private var waitingForLift = true
    private var gesture: Gesture = .idle

    public init() {}

    @discardableResult
    public mutating func start() -> [ProofAction] {
        let actions = release()
        gesture = .idle
        isRunning = true
        // A finger held on the panel while starting must be lifted before use.
        waitingForLift = true
        return actions
    }

    public mutating func update(contacts: [ProofContact]) -> [ProofAction] {
        guard isRunning else { return [] }
        guard contacts.count <= 2,
              Set(contacts.map(\.id)).count == contacts.count,
              contacts.allSatisfy({ $0.point.x.isFinite && $0.point.y.isFinite }) else {
            return rejectContact()
        }
        if waitingForLift {
            if contacts.isEmpty { waitingForLift = false }
            return []
        }
        if contacts.isEmpty {
            let actions: [ProofAction]
            if case .pending(_, _, let point) = gesture {
                actions = [.down(point), .up(point)]
            } else {
                actions = release()
            }
            gesture = .idle
            return actions
        }
        // A committed drag belongs to its original contact, never the array order.
        if case .dragging(let id) = gesture {
            guard let contact = contacts.first(where: { $0.id == id }) else {
                return rejectContact()
            }
            guard buttonPoint != contact.point else { return [] }
            buttonPoint = contact.point
            return [.drag(contact.point)]
        }
        if contacts.count == 2 {
            // Divide before adding so even finite extreme coordinates stay finite.
            let midpoint = MappedPoint(x: contacts[0].point.x / 2 + contacts[1].point.x / 2,
                                       y: contacts[0].point.y / 2 + contacts[1].point.y / 2)
            guard case .scrolling(let previous) = gesture else {
                gesture = .scrolling(midpoint)
                return []
            }
            let dx = midpoint.x - previous.x
            let dy = midpoint.y - previous.y
            guard dx.isFinite, dy.isFinite else { return rejectContact() }
            gesture = .scrolling(midpoint)
            return dx == 0 && dy == 0 ? [] : [.scroll(dx: dx, dy: dy, at: midpoint)]
        }
        let contact = contacts[0]
        switch gesture {
        case .idle:
            gesture = .pending(id: contact.id, origin: contact.point, point: contact.point)
            return []
        case .pending(let id, let origin, _):
            guard contact.id == id else { return rejectContact() }
            let distance = hypot(contact.point.x - origin.x, contact.point.y - origin.y)
            guard distance.isFinite else { return rejectContact() }
            if distance > Self.maximumTapDistance {
                gesture = .dragging(id: id)
                buttonPoint = contact.point
                return [.down(origin), .drag(contact.point)]
            }
            gesture = .pending(id: id, origin: origin, point: contact.point)
            return []
        case .scrolling, .dragging:
            // A remaining scroll contact cannot become a tap or take over a drag.
            return rejectContact()
        }
    }

    public mutating func stop() -> [ProofAction] {
        isRunning = false
        waitingForLift = true
        gesture = .idle
        return release()
    }

    public mutating func rejectContact() -> [ProofAction] {
        waitingForLift = true
        gesture = .idle
        return release()
    }

    private mutating func release() -> [ProofAction] {
        guard let point = buttonPoint else { return [] }
        buttonPoint = nil
        return [.up(point)]
    }
}
