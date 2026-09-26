import Foundation
@testable import AltusKit

/// Builds a synthetic `MotionSample` for a device held with a fixed
/// gravity direction (default: flat, z-up, gravity pointing in -z), varying
/// only vertical `userAcceleration` — the axis both `JumpDetector` and
/// `RepDetector` key off of. Keeping gravity fixed and z the only non-zero
/// axis makes the arithmetic self-consistent and easy to reason about
/// without needing to replicate real device sign conventions exactly.
func syntheticSample(
    t: TimeInterval,
    userAccelZ: Double,
    rotation: Double = 0.0
) -> MotionSample {
    MotionSample(
        timestamp: t,
        userAcceleration: Vector3(x: 0, y: 0, z: userAccelZ),
        gravity: Vector3(x: 0, y: 0, z: -1.0),
        rotationRate: Vector3(x: 0, y: 0, z: rotation),
        attitude: .identity
    )
}

/// A run of samples at a fixed sample rate, holding `userAccelZ` constant.
func syntheticRun(
    from startTime: TimeInterval,
    count: Int,
    dt: TimeInterval,
    userAccelZ: Double,
    rotation: Double = 0.0
) -> [MotionSample] {
    (0..<count).map { i in
        syntheticSample(t: startTime + Double(i) * dt, userAccelZ: userAccelZ, rotation: rotation)
    }
}
