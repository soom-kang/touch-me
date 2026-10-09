/// A readiness deadline is fixed for one recovery window. Display settling may
/// defer another attempt, but must never turn a ten-second window into forever.
public struct RecoveryWindow {
    public var deadline: Double?
    public var nextAttempt: Double = 0

    public init() {}

    public mutating func begin(at now: Double) {
        deadline = now + 10
        nextAttempt = now + 1
    }

    public mutating func postpone(until time: Double) {
        nextAttempt = max(nextAttempt, time)
    }

    public func hasExpired(at now: Double) -> Bool {
        deadline.map { now >= $0 } ?? false
    }

    public mutating func reset() {
        deadline = nil
        nextAttempt = 0
    }
}
