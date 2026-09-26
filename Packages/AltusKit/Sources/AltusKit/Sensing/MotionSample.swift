import Foundation

/// A platform-neutral snapshot of device motion, mirroring the fields of
/// `CMDeviceMotion` without depending on CoreMotion. Produced live by
/// `CoreMotionProvider` on watchOS, or replayed from recorded/synthetic
/// fixtures in tests.
public struct MotionSample: Codable, Equatable, Sendable {
    /// Seconds since an arbitrary reference point. Only deltas between
    /// samples are meaningful (matches `CMDeviceMotion.timestamp`).
    public let timestamp: TimeInterval

    /// Acceleration with gravity's contribution removed, in g's.
    public let userAcceleration: Vector3

    /// The gravity vector in the device's reference frame, in g's.
    public let gravity: Vector3

    /// Rotation rate around each axis, in radians/second.
    public let rotationRate: Vector3

    /// Device orientation as a unit quaternion (x, y, z, w).
    public let attitude: Quaternion

    public init(
        timestamp: TimeInterval,
        userAcceleration: Vector3,
        gravity: Vector3,
        rotationRate: Vector3,
        attitude: Quaternion
    ) {
        self.timestamp = timestamp
        self.userAcceleration = userAcceleration
        self.gravity = gravity
        self.rotationRate = rotationRate
        self.attitude = attitude
    }

    /// Raw (proper) acceleration as measured by the accelerometer, i.e. with
    /// gravity added back in. At rest this reads ~1g; in true freefall it
    /// reads ~0g. This is the signal jump detection keys off, since
    /// `userAcceleration` alone has the opposite (and less intuitive)
    /// freefall signature.
    public var rawAcceleration: Vector3 {
        Vector3(
            x: userAcceleration.x + gravity.x,
            y: userAcceleration.y + gravity.y,
            z: userAcceleration.z + gravity.z
        )
    }
}

public struct Vector3: Codable, Equatable, Sendable {
    public var x: Double
    public var y: Double
    public var z: Double

    public init(x: Double, y: Double, z: Double) {
        self.x = x
        self.y = y
        self.z = z
    }

    public var magnitude: Double {
        (x * x + y * y + z * z).squareRoot()
    }

    public static let zero = Vector3(x: 0, y: 0, z: 0)
}

public struct Quaternion: Codable, Equatable, Sendable {
    public var x: Double
    public var y: Double
    public var z: Double
    public var w: Double

    public init(x: Double, y: Double, z: Double, w: Double) {
        self.x = x
        self.y = y
        self.z = z
        self.w = w
    }

    public static let identity = Quaternion(x: 0, y: 0, z: 0, w: 1)
}
