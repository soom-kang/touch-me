import Testing
import TouchMappingCore
@testable import TouchMePlatform

struct ClickSequenceTests {
    private let origin = MappedPoint(x: 100, y: 100)

    @Test
    func completedTapsRespectTimeAndDistanceBoundaries() {
        var sequence = ClickSequence(maximumDistance: 8)
        #expect(sequence.begin(at: origin, time: 10, interval: 0.5) == 1)
        sequence.end(completedTap: true)
        #expect(sequence.begin(at: MappedPoint(x: 108, y: 100), time: 10.5, interval: 0.5) == 2)
        sequence.end(completedTap: true)
        #expect(sequence.begin(at: origin, time: 11.01, interval: 0.5) == 1)
    }

    @Test
    func draggingAndIncompleteContactsDoNotExtendSequence() {
        var sequence = ClickSequence()
        #expect(sequence.begin(at: origin, time: 1, interval: 0.5) == 1)
        sequence.move(to: MappedPoint(x: 109, y: 100))
        sequence.end(completedTap: true)
        #expect(sequence.begin(at: origin, time: 1.1, interval: 0.5) == 1)
        sequence.end(completedTap: false)
        #expect(sequence.begin(at: origin, time: 1.2, interval: 0.5) == 1)
    }

    @Test
    func cancellationPreservesMatchingUpCountButClearsNextTap() {
        var sequence = ClickSequence()
        _ = sequence.begin(at: origin, time: 1, interval: 0.5)
        sequence.end(completedTap: true)
        #expect(sequence.begin(at: origin, time: 1.1, interval: 0.5) == 2)
        sequence.cancelTap()
        #expect(sequence.count == 2)
        sequence.end(completedTap: true)
        #expect(sequence.count == 1)
        #expect(sequence.begin(at: origin, time: 1.2, interval: 0.5) == 1)
    }

    @Test
    func invalidIntervalsAndClockReversalCannotExtendSequence() {
        for interval in [0.0, -1.0, Double.infinity, Double.nan] {
            var sequence = ClickSequence()
            _ = sequence.begin(at: origin, time: 1, interval: 0.5)
            sequence.end(completedTap: true)
            #expect(sequence.begin(at: origin, time: 1.1, interval: interval) == 1)
        }
        var sequence = ClickSequence()
        _ = sequence.begin(at: origin, time: 1, interval: 0.5)
        sequence.end(completedTap: true)
        #expect(sequence.begin(at: origin, time: 0.9, interval: 0.5) == 1)
        sequence.reset()
        #expect(sequence.count == 1)
    }
}
