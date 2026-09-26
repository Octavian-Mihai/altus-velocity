@preconcurrency import CoreMotion
import AltusKit

/// Live `MotionSampleProviding` implementation, wrapping `CMMotionManager`.
/// Only ever sampled while a test/set is armed — see `JumpTestSessionController`
/// / `LiftSetSessionController` — not continuously, to conserve battery.
final class CoreMotionProvider: MotionSampleProviding {
    private let motionManager = CMMotionManager()
    private let queue: OperationQueue = {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        queue.qualityOfService = .userInteractive
        return queue
    }()

    func makeStream() -> AsyncStream<MotionSample> {
        AsyncStream { continuation in
            guard motionManager.isDeviceMotionAvailable else {
                continuation.finish()
                return
            }

            motionManager.deviceMotionUpdateInterval = 1.0 / 50.0
            motionManager.startDeviceMotionUpdates(using: .xArbitraryZVertical, to: queue) { motion, _ in
                guard let motion else { return }
                let q = motion.attitude.quaternion
                continuation.yield(
                    MotionSample(
                        timestamp: motion.timestamp,
                        userAcceleration: Vector3(x: motion.userAcceleration.x, y: motion.userAcceleration.y, z: motion.userAcceleration.z),
                        gravity: Vector3(x: motion.gravity.x, y: motion.gravity.y, z: motion.gravity.z),
                        rotationRate: Vector3(x: motion.rotationRate.x, y: motion.rotationRate.y, z: motion.rotationRate.z),
                        attitude: Quaternion(x: q.x, y: q.y, z: q.z, w: q.w)
                    )
                )
            }

            continuation.onTermination = { [motionManager] _ in
                motionManager.stopDeviceMotionUpdates()
            }
        }
    }
}
