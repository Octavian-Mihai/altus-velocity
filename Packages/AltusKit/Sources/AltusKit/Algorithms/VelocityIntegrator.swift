import Foundation

public extension MotionSample {
    /// The component of `userAcceleration` along the world-vertical axis, in g's.
    ///
    /// `gravity` is CoreMotion's continuously-updated estimate of "down" in
    /// the device's own frame, so projecting onto `-gravity` (normalized)
    /// gives the vertical component directly — equivalent to rotating
    /// `userAcceleration` into a world frame via `attitude` and reading its
    /// up component, but without needing quaternion rotation math, and
    /// robust to the device rolling around its own vertical axis.
    var verticalUserAcceleration: Double {
        let g = gravity
        let gMagnitude = g.magnitude
        guard gMagnitude > 0.01 else { return 0 }
        let up = Vector3(x: -g.x / gMagnitude, y: -g.y / gMagnitude, z: -g.z / gMagnitude)
        return userAcceleration.x * up.x + userAcceleration.y * up.y + userAcceleration.z * up.z
    }
}

/// Integrates world-vertical acceleration into velocity, with zero-velocity
/// updates (ZUPT) to bound drift: whenever the signal has been near-still
/// for long enough, accumulated velocity is snapped back to zero. This is
/// what keeps double integration usable across a multi-second rep — without
/// it, drift would dominate within a second or two.
public final class VelocityIntegrator {
    public struct Config: Sendable {
        /// Below this (in g), acceleration is considered "at rest" for ZUPT purposes.
        public var stillAccelThreshold: Double = 0.05
        /// Below this (in m/s), velocity is considered "at rest" for ZUPT purposes.
        public var stillVelocityThreshold: Double = 0.05
        /// How long both must hold before velocity is zeroed.
        public var stillDuration: TimeInterval = 0.2

        public init() {}
    }

    private let config: Config
    private let gravity = 9.81
    private(set) public var velocity: Double = 0
    private var lastTimestamp: TimeInterval?
    private var lastAccelG: Double?
    private var stillSince: TimeInterval?

    public init(config: Config = Config()) {
        self.config = config
    }

    public func reset() {
        velocity = 0
        lastTimestamp = nil
        lastAccelG = nil
        stillSince = nil
    }

    /// Feed one sample's worth of vertical acceleration (in g's) and get back
    /// the updated velocity estimate (in m/s, positive = upward).
    @discardableResult
    public func integrate(verticalAccelerationG accelG: Double, timestamp: TimeInterval) -> Double {
        defer {
            lastTimestamp = timestamp
            lastAccelG = accelG
        }

        if let last = lastTimestamp, let lastAccel = lastAccelG {
            let dt = timestamp - last
            if dt > 0, dt < 1.0 {
                // Trapezoidal integration for better accuracy than a rectangular sum.
                let meanAccelMps2 = (lastAccel + accelG) / 2 * gravity
                velocity += meanAccelMps2 * dt
            }
        }

        if abs(accelG) < config.stillAccelThreshold, abs(velocity) < config.stillVelocityThreshold {
            if stillSince == nil {
                stillSince = timestamp
            } else if timestamp - stillSince! >= config.stillDuration {
                velocity = 0
            }
        } else {
            stillSince = nil
        }

        return velocity
    }
}
