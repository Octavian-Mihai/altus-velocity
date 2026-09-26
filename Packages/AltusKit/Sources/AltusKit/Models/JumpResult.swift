import Foundation

/// The outcome of a single completed vertical jump.
public struct JumpResult: Codable, Equatable, Sendable {
    public let hangTime: TimeInterval
    public let jumpHeightCm: Double
    public let mode: JumpMode
    /// 0...1. Reduced when rotation during flight suggests arm swing
    /// contaminated the vertical-acceleration signal.
    public let confidence: Double

    public init(hangTime: TimeInterval, jumpHeightCm: Double, mode: JumpMode, confidence: Double) {
        self.hangTime = hangTime
        self.jumpHeightCm = jumpHeightCm
        self.mode = mode
        self.confidence = confidence
    }
}
