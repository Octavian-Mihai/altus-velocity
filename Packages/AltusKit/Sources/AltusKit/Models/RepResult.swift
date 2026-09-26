import Foundation

/// The outcome of a single completed rep within a VBT lift set.
public struct RepResult: Codable, Equatable, Sendable {
    public let index: Int
    public let meanConcentricVelocityMps: Double
    public let peakVelocityMps: Double
    public let concentricDuration: TimeInterval
    /// Relative to rep 1's mean concentric velocity, per standard VBT convention.
    public let velocityLossPercent: Double

    public init(
        index: Int,
        meanConcentricVelocityMps: Double,
        peakVelocityMps: Double,
        concentricDuration: TimeInterval,
        velocityLossPercent: Double
    ) {
        self.index = index
        self.meanConcentricVelocityMps = meanConcentricVelocityMps
        self.peakVelocityMps = peakVelocityMps
        self.concentricDuration = concentricDuration
        self.velocityLossPercent = velocityLossPercent
    }
}
