import Foundation

/// Coarse classification of a lift, used both to pick RIR heuristics and to
/// flag how trustworthy wrist-based velocity is for that movement pattern.
public enum ExerciseCategory: String, Codable, Sendable, CaseIterable {
    case squat
    case deadlift
    case benchPress
    case other

    /// Wrist-worn velocity tracking correlates with actual bar speed much
    /// better for squat/deadlift than for bench press, where the pressing
    /// arm's path diverges from the bar's. Surfaced in the UI so bench
    /// results are clearly labeled experimental.
    public var isWristVelocityReliable: Bool {
        switch self {
        case .squat, .deadlift: return true
        case .benchPress, .other: return false
        }
    }
}
