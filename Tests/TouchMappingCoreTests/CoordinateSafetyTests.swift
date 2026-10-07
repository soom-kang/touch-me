import Testing
@testable import TouchMappingCore

struct CoordinateSafetyTests {
    @Test
    func malformedRangesAndNonfiniteScreensAreRejected() {
        let range = AxisRange(minimum: 0, maximum: 4095)
        let screen = ScreenRect(x: 0, y: 0, width: 1920, height: 1080)
        #expect(AxisRange(minimum: 1, maximum: 1).fraction(1) == nil)
        #expect(AxisRange(minimum: 2, maximum: 1).fraction(1) == nil)
        #expect(CoordinateMapper.map(x: 0, y: 0,
                                     xRange: AxisRange(minimum: 1, maximum: 1),
                                     yRange: range, to: screen) == nil)
        for invalid in [ScreenRect(x: .infinity, y: 0, width: 100, height: 100),
                        ScreenRect(x: 0, y: .nan, width: 100, height: 100),
                        ScreenRect(x: 0, y: 0, width: 0, height: 100),
                        ScreenRect(x: 0, y: 0, width: 100, height: 0.5)] {
            #expect(CoordinateMapper.map(x: 0, y: 0, xRange: range,
                                         yRange: range, to: invalid) == nil)
        }
    }

    @Test
    func integerExtremesDoNotOverflowAndSinglePixelScreenIsStable() {
        let range = AxisRange(minimum: Int.min, maximum: Int.max)
        #expect(range.fraction(Int.min) == 0)
        #expect(range.fraction(Int.max) == 1)
        let pixel = ScreenRect(x: -100, y: 20, width: 1, height: 1)
        #expect(CoordinateMapper.map(x: Int.max, y: Int.min, xRange: range,
                                     yRange: range, to: pixel) == MappedPoint(x: -100, y: 20))
    }
}
