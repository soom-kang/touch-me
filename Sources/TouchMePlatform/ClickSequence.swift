import Foundation
import TouchMappingCore

/// Only completed one-finger taps within movement tolerance extend a click sequence.
struct ClickSequence {
    private struct Tap {
        let point: MappedPoint
        let time: TimeInterval
        let count: Int64
    }
    private var previous: Tap?
    private var current: Tap?
    private(set) var count: Int64 = 1
    private let maximumDistance: Double

    init(maximumDistance: Double = 8) {
        self.maximumDistance = maximumDistance
    }

    mutating func begin(at point: MappedPoint, time: TimeInterval, interval: TimeInterval) -> Int64 {
        count = 1
        if let previous {
            let elapsed = time - previous.time
            let distance = hypot(point.x - previous.point.x, point.y - previous.point.y)
            if elapsed.isFinite, elapsed >= 0, interval.isFinite, interval > 0, elapsed <= interval,
               distance.isFinite, distance <= maximumDistance, previous.count < Int64.max {
                count = previous.count + 1
            }
        }
        current = Tap(point: point, time: time, count: count)
        return count
    }

    mutating func cancelTap() {
        previous = nil
        current = nil
        // Preserve the count already sent on Down until its corresponding Up.
    }

    mutating func move(to point: MappedPoint) {
        guard let current else { return }
        let distance = hypot(point.x - current.point.x, point.y - current.point.y)
        if !distance.isFinite || distance > maximumDistance { cancelTap() }
    }

    mutating func end(completedTap: Bool) {
        previous = completedTap ? current : nil
        current = nil
        count = 1
    }

    mutating func reset() {
        previous = nil
        current = nil
        count = 1
    }
}
