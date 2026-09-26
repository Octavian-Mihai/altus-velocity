import Foundation

/// How a jump test was performed, which affects how much we trust the
/// wrist-worn accelerometer as a proxy for center-of-mass motion.
public enum JumpMode: String, Codable, Sendable, CaseIterable {
    /// Hand held still against the hip during the jump. Wrist acceleration
    /// closely tracks torso motion — the primary, recommended mode.
    case guided

    /// Arm swings freely during the jump. A single wrist IMU can't fully
    /// separate arm-swing rotation from center-of-mass motion, so results
    /// in this mode are reported with reduced confidence.
    case freeSwing
}
