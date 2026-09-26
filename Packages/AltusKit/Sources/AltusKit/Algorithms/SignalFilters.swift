import Foundation

/// A short moving-average filter for smoothing noisy accelerometer samples.
/// Deliberately light-touch: over-smoothing blurs the sharp edges that jump
/// takeoff/landing and rep-boundary detection key off of.
public struct MovingAverageFilter {
    private let windowSize: Int
    private var window: [Double] = []

    public init(windowSize: Int = 3) {
        precondition(windowSize > 0)
        self.windowSize = windowSize
    }

    public mutating func filter(_ value: Double) -> Double {
        window.append(value)
        if window.count > windowSize {
            window.removeFirst()
        }
        return window.reduce(0, +) / Double(window.count)
    }
}
