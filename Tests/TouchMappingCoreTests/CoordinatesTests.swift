import Testing
@testable import TouchMappingCore

struct CoordinatesTests {
    @Test
    func testLogicalMinimumCenterAndMaximumMapToScreen() throws {
        let xRange = AxisRange(minimum: 1, maximum: 4095)
        let yRange = AxisRange(minimum: -1, maximum: 4095)
        let screen = ScreenRect(x: 20, y: 30, width: 201, height: 101)

        let minimum = try #require(CoordinateMapper.map(
            x: 1, y: -1, xRange: xRange, yRange: yRange, to: screen))
        let center = try #require(CoordinateMapper.map(
            x: 2048, y: 2047, xRange: xRange, yRange: yRange, to: screen))
        let maximum = try #require(CoordinateMapper.map(
            x: 4095, y: 4095, xRange: xRange, yRange: yRange, to: screen))

        #expect(minimum == MappedPoint(x: 20, y: 30))
        #expect(center == MappedPoint(x: 120, y: 80))
        #expect(maximum == MappedPoint(x: 220, y: 130))
    }

    @Test
    func testTouchRangeStaysInsidePositiveAndNegativeScreenOrigins() throws {
        let range = AxisRange(minimum: 0, maximum: 4095)
        let targets = [
            (ScreenRect(x: 1440, y: 0, width: 1920, height: 1080),
             MappedPoint(x: 1440, y: 0), MappedPoint(x: 3359, y: 1079)),
            (ScreenRect(x: -1280, y: -720, width: 1280, height: 720),
             MappedPoint(x: -1280, y: -720), MappedPoint(x: -1, y: -1)),
        ]

        for (screen, minimum, maximum) in targets {
            let below = try #require(CoordinateMapper.map(
                x: -1, y: -1, xRange: range, yRange: range, to: screen))
            let endpoint = try #require(CoordinateMapper.map(
                x: 4095, y: 4095, xRange: range, yRange: range, to: screen))
            let above = try #require(CoordinateMapper.map(
                x: 4096, y: 4096, xRange: range, yRange: range, to: screen))

            #expect(below == minimum)
            #expect(endpoint == maximum)
            #expect(above == maximum)
        }
    }
}
