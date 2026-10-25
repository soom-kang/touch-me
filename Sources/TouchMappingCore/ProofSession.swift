import Foundation

public enum MagnificationPhase: Equatable {
    case began, changed, ended, cancelled
}

public enum SystemGesture: Equatable {
    case missionControl, nextSpace, previousSpace
}

public enum ProofAction: Equatable {
    case down(MappedPoint)
    case drag(MappedPoint)
    case up(MappedPoint)
    case scroll(dx: Double, dy: Double, at: MappedPoint)
    case magnify(delta: Double, phase: MagnificationPhase, at: MappedPoint)
    case systemGesture(action: SystemGesture, at: MappedPoint)
}

public struct ProofContact: Equatable {
    public let id: String
    public let point: MappedPoint

    public init(id: String, point: MappedPoint) {
        self.id = id
        self.point = point
    }
}

/// One gesture owns the contacts until lift. No multi-finger path produces clicks.
public struct ProofSession {
    private struct Group {
        let contacts: [ProofContact]
        let center: MappedPoint
        let span: Double
        var ids: Set<String> { Set(contacts.map(\.id)) }

        init?(_ contacts: [ProofContact]) {
            let count = Double(contacts.count)
            let center = MappedPoint(x: contacts.reduce(0) { $0 + $1.point.x / count },
                                     y: contacts.reduce(0) { $0 + $1.point.y / count })
            let span = contacts.count == 2
                ? hypot(contacts[0].point.x - contacts[1].point.x,
                        contacts[0].point.y - contacts[1].point.y) : 0
            guard center.x.isFinite, center.y.isFinite, span.isFinite else { return nil }
            self.contacts = contacts
            self.center = center
            self.span = span
        }
    }

    private enum Gesture {
        case idle
        case pending(id: String, origin: MappedPoint, point: MappedPoint)
        case dragging(id: String)
        case pendingTwo(Group)
        case scrolling(ids: Set<String>, point: MappedPoint)
        case pinching(ids: Set<String>, span: Double, anchor: MappedPoint)
        case pendingThree(Group)
    }

    private static let maximumTapDistance = 8.0
    public private(set) var isRunning = false
    public private(set) var buttonPoint: MappedPoint?
    public private(set) var magnificationEnabled: Bool
    private var waitingForLift = true
    private var gesture: Gesture = .idle

    public init(magnificationEnabled: Bool = true) {
        self.magnificationEnabled = magnificationEnabled
    }

    public mutating func setMagnificationEnabled(_ enabled: Bool) -> [ProofAction] {
        guard magnificationEnabled != enabled else { return [] }
        magnificationEnabled = enabled
        switch gesture {
        case .pinching, .pendingTwo: return rejectContact()
        default: return []
        }
    }

    @discardableResult
    public mutating func start() -> [ProofAction] {
        let actions = finish(phase: .cancelled)
        isRunning = true
        waitingForLift = true
        return actions
    }

    public mutating func update(contacts: [ProofContact]) -> [ProofAction] {
        guard isRunning else { return [] }
        guard contacts.count <= 3,
              Set(contacts.map(\.id)).count == contacts.count,
              contacts.allSatisfy({ $0.point.x.isFinite && $0.point.y.isFinite }) else {
            return rejectContact()
        }
        if waitingForLift {
            if contacts.isEmpty { waitingForLift = false }
            return []
        }
        if contacts.isEmpty {
            if case .pending(_, _, let point) = gesture {
                gesture = .idle
                return [.down(point), .up(point)]
            }
            return finish(phase: .ended)
        }
        // Preserve drag ownership, including rejection of a third finger.
        if case .dragging(let id) = gesture {
            guard contacts.count <= 2, let contact = contacts.first(where: { $0.id == id }) else {
                return rejectContact()
            }
            guard buttonPoint != contact.point else { return [] }
            buttonPoint = contact.point
            return [.drag(contact.point)]
        }
        let ids = Set(contacts.map(\.id))
        switch gesture {
        case .scrolling(let owners, let previous):
            guard ids == owners, let group = Group(contacts) else { return rejectContact() }
            return scroll(group, from: previous)
        case .pinching(let owners, let span, let anchor):
            if contacts.count < 2 && ids.isSubset(of: owners) {
                waitingForLift = true
                return finish(phase: .ended)
            }
            guard ids == owners, let group = Group(contacts), group.span > 0 else { return rejectContact() }
            let delta = group.span / span - 1
            guard delta.isFinite, delta > -1 else { return rejectContact() }
            gesture = .pinching(ids: ids, span: group.span, anchor: anchor)
            return delta == 0 ? [] : [.magnify(delta: delta, phase: .changed, at: anchor)]
        case .pendingTwo(let origin):
            guard origin.ids.isSubset(of: ids), let group = Group(contacts) else { return rejectContact() }
            if contacts.count == 3 {
                gesture = .pendingThree(group)
                return []
            }
            return classifyTwo(group, origin: origin)
        case .pendingThree(let origin):
            guard ids == origin.ids, let group = Group(contacts) else { return rejectContact() }
            return classifyThree(group, origin: origin)
        case .pending(let id, let origin, _):
            guard ids.contains(id) else { return rejectContact() }
            if contacts.count > 1 { return beginGroup(contacts) }
            let point = contacts[0].point
            let distance = hypot(point.x - origin.x, point.y - origin.y)
            guard distance.isFinite else { return rejectContact() }
            if distance > Self.maximumTapDistance {
                gesture = .dragging(id: id)
                buttonPoint = point
                return [.down(origin), .drag(point)]
            }
            gesture = .pending(id: id, origin: origin, point: point)
            return []
        case .idle:
            if contacts.count > 1 { return beginGroup(contacts) }
            let contact = contacts[0]
            gesture = .pending(id: contact.id, origin: contact.point, point: contact.point)
            return []
        case .dragging: return [] // handled before group recognition
        }
    }

    private mutating func beginGroup(_ contacts: [ProofContact]) -> [ProofAction] {
        guard let group = Group(contacts) else { return rejectContact() }
        gesture = contacts.count == 2 ? .pendingTwo(group) : .pendingThree(group)
        return []
    }

    private mutating func classifyTwo(_ group: Group, origin: Group) -> [ProofAction] {
        let movement = hypot(group.center.x - origin.center.x, group.center.y - origin.center.y)
        let separation = abs(group.span - origin.span)
        guard movement.isFinite, separation.isFinite else { return rejectContact() }
        if magnificationEnabled, origin.span >= 20, group.span > 0,
           separation >= max(6, origin.span * 0.05), separation >= movement * 1.5 {
            let delta = group.span / origin.span - 1
            guard delta.isFinite, delta > -1 else { return rejectContact() }
            gesture = .pinching(ids: group.ids, span: group.span, anchor: origin.center)
            return [.magnify(delta: 0, phase: .began, at: origin.center),
                    .magnify(delta: delta, phase: .changed, at: origin.center)]
        }
        if movement >= 6, !magnificationEnabled || movement >= separation * 1.5 {
            return scroll(group, from: origin.center)
        }
        return []
    }

    private mutating func scroll(_ group: Group, from previous: MappedPoint) -> [ProofAction] {
        let dx = group.center.x - previous.x
        let dy = group.center.y - previous.y
        guard dx.isFinite, dy.isFinite else { return rejectContact() }
        gesture = .scrolling(ids: group.ids, point: group.center)
        return dx == 0 && dy == 0 ? [] : [.scroll(dx: dx, dy: dy, at: group.center)]
    }

    private mutating func classifyThree(_ group: Group, origin: Group) -> [ProofAction] {
        let dx = group.center.x - origin.center.x
        let dy = group.center.y - origin.center.y
        guard dx.isFinite, dy.isFinite else { return rejectContact() }
        let horizontal = abs(dx) >= 40 && abs(dx) >= abs(dy) * 1.5
        let vertical = abs(dy) >= 40 && abs(dy) >= abs(dx) * 1.5
        guard horizontal || vertical else { return [] }
        let travel = horizontal ? dx : dy
        for contact in group.contacts {
            guard let start = origin.contacts.first(where: { $0.id == contact.id }) else { return rejectContact() }
            let delta = horizontal ? contact.point.x - start.point.x : contact.point.y - start.point.y
            guard delta.isFinite else { return rejectContact() }
            guard travel > 0 ? delta > 0 : delta < 0 else { return [] }
        }
        // Consume downward movement too, so reversing cannot trigger another action.
        waitingForLift = true
        gesture = .idle
        guard horizontal || dy < 0 else { return [] }
        let action: SystemGesture = horizontal ? (dx < 0 ? .nextSpace : .previousSpace) : .missionControl
        return [.systemGesture(action: action, at: origin.center)]
    }

    public mutating func stop() -> [ProofAction] {
        isRunning = false
        waitingForLift = true
        return finish(phase: .cancelled)
    }

    public mutating func rejectContact() -> [ProofAction] {
        waitingForLift = true
        return finish(phase: .cancelled)
    }

    private mutating func finish(phase: MagnificationPhase) -> [ProofAction] {
        var actions: [ProofAction] = []
        if case .pinching(_, _, let anchor) = gesture {
            actions.append(.magnify(delta: 0, phase: phase, at: anchor))
        }
        gesture = .idle
        if let point = buttonPoint {
            buttonPoint = nil
            actions.append(.up(point))
        }
        return actions
    }
}
