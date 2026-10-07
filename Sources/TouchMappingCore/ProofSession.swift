import Foundation

public enum ProofAction: Equatable {
    case down(MappedPoint)
    case drag(MappedPoint)
    case up(MappedPoint)
    case scroll(dx: Double, dy: Double, at: MappedPoint)
}

/// One contact clicks/drags; two contacts scroll using their midpoint's movement.
public struct ProofSession {
    public private(set) var isRunning = false
    public private(set) var buttonPoint: MappedPoint?
    private var waitingForLift = true
    private var scrollPoint: MappedPoint?

    public init() {}

    @discardableResult
    public mutating func start() -> [ProofAction] {
        let actions = release()
        scrollPoint = nil
        isRunning = true
        // A finger held on the panel while starting must be lifted before use.
        waitingForLift = true
        return actions
    }

    public mutating func update(points: [MappedPoint]) -> [ProofAction] {
        guard isRunning else { return [] }
        guard points.count <= 2,
              points.allSatisfy({ $0.x.isFinite && $0.y.isFinite }) else {
            return rejectContact()
        }
        if waitingForLift {
            if points.isEmpty { waitingForLift = false }
            return []
        }
        if points.count == 2 {
            // Divide before adding so even finite extreme coordinates stay finite.
            let midpoint = MappedPoint(x: points[0].x / 2 + points[1].x / 2,
                                       y: points[0].y / 2 + points[1].y / 2)
            guard let previous = scrollPoint else {
                let actions = release()
                scrollPoint = midpoint
                return actions
            }
            let dx = midpoint.x - previous.x
            let dy = midpoint.y - previous.y
            guard dx.isFinite, dy.isFinite else { return rejectContact() }
            scrollPoint = midpoint
            return dx == 0 && dy == 0 ? [] : [.scroll(dx: dx, dy: dy, at: midpoint)]
        }
        guard let point = points.first else {
            scrollPoint = nil
            return release()
        }
        // A remaining finger must not turn the end of a scroll into a new click.
        guard scrollPoint == nil else { return rejectContact() }
        if buttonPoint == nil {
            buttonPoint = point
            return [.down(point)]
        }
        guard buttonPoint != point else { return [] }
        buttonPoint = point
        return [.drag(point)]
    }

    public mutating func stop() -> [ProofAction] {
        isRunning = false
        waitingForLift = true
        scrollPoint = nil
        return release()
    }

    public mutating func rejectContact() -> [ProofAction] {
        waitingForLift = true
        scrollPoint = nil
        return release()
    }

    private mutating func release() -> [ProofAction] {
        guard let point = buttonPoint else { return [] }
        buttonPoint = nil
        return [.up(point)]
    }
}
