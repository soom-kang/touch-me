import Foundation

public struct AxisRange: Codable, Equatable {
    public let minimum: Int
    public let maximum: Int

    public init(minimum: Int, maximum: Int) {
        self.minimum = minimum
        self.maximum = maximum
    }

    public var isValid: Bool { maximum > minimum }

    public func fraction(_ value: Int) -> Double? {
        guard isValid else { return nil }
        // Convert before subtracting to avoid overflowing malformed HID ranges.
        let result = (Double(value) - Double(minimum)) / (Double(maximum) - Double(minimum))
        guard result.isFinite else { return nil }
        return min(max(result, 0), 1)
    }
}

public struct ScreenRect: Equatable {
    public let x: Double
    public let y: Double
    public let width: Double
    public let height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    public var isValid: Bool {
        [x, y, width, height, x + width, y + height].allSatisfy(\.isFinite)
            && width >= 1 && height >= 1
    }
}

public struct MappedPoint: Equatable {
    public let x: Double
    public let y: Double
    public init(x: Double, y: Double) { self.x = x; self.y = y }
}

public enum CoordinateMapper {
    public static func map(x: Int, y: Int, xRange: AxisRange, yRange: AxisRange,
                           to screen: ScreenRect) -> MappedPoint? {
        guard screen.isValid, let fx = xRange.fraction(x), let fy = yRange.fraction(y) else { return nil }
        // Keep the maximum coordinate inside this screen, including adjacent screens.
        return MappedPoint(x: screen.x + fx * (screen.width - 1),
                           y: screen.y + fy * (screen.height - 1))
    }
}
