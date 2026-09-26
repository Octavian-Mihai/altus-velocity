import Foundation

/// Emitted as `JumpDetector` progresses through a jump, so callers can drive
/// live UI/WatchConnectivity updates on phase transitions rather than only
/// on the final result.
public enum JumpDetectorEvent: Equatable, Sendable {
    case propulsionStarted
    case tookOff
    case landed(JumpResult)
    /// A candidate flight/landing was detected but discarded as noise
    /// (e.g. hang time outside the plausible human-jump range).
    case discarded
}

/// Detects a single vertical jump from a stream of wrist-worn
/// `MotionSample`s using the flight-time method: `h = g * t² / 8`.
///
/// Keys off *raw* (proper) acceleration magnitude — `MotionSample.rawAcceleration`
/// — which reads ~1g at rest and ~0g in true freefall. `userAcceleration`
/// alone has gravity already subtracted and shows the opposite signature,
/// which is easy to get backwards.
///
/// State machine: `armed -> propulsion -> flight -> landed -> armed`.
public final class JumpDetector {
    public struct Thresholds: Sendable {
        /// Sustained raw-accel magnitude (in g) that signals push-off has begun.
        public var propulsionG: Double = 1.3
        /// How long the propulsion signal must be sustained before it's confirmed, not noise.
        public var minPropulsionDuration: TimeInterval = 0.15
        /// Raw-accel magnitude (in g) below which the body is considered airborne.
        public var flightG: Double = 0.25
        /// Consecutive samples under `flightG` required to confirm takeoff (debounce).
        public var flightDebounceSamples: Int = 3
        /// Raw-accel magnitude (in g) spike that signals landing.
        public var landingG: Double = 2.0
        /// Plausible human jump hang-time bounds; anything outside is discarded as noise.
        public var minHangTime: TimeInterval = 0.10
        public var maxHangTime: TimeInterval = 1.50
        /// Peak rotation rate (rad/s) during flight above which arm swing is
        /// assumed to have contaminated the signal, lowering confidence.
        public var rotationContaminationThreshold: Double = 2.0

        public init(
            propulsionG: Double = 1.3,
            minPropulsionDuration: TimeInterval = 0.15,
            flightG: Double = 0.25,
            flightDebounceSamples: Int = 3,
            landingG: Double = 2.0,
            minHangTime: TimeInterval = 0.10,
            maxHangTime: TimeInterval = 1.50,
            rotationContaminationThreshold: Double = 2.0
        ) {
            self.propulsionG = propulsionG
            self.minPropulsionDuration = minPropulsionDuration
            self.flightG = flightG
            self.flightDebounceSamples = flightDebounceSamples
            self.landingG = landingG
            self.minHangTime = minHangTime
            self.maxHangTime = maxHangTime
            self.rotationContaminationThreshold = rotationContaminationThreshold
        }
    }

    private enum Phase {
        case armed
        case propulsion(startedAt: TimeInterval)
        /// `takeoffCandidate` is the timestamp of the first under-threshold
        /// sample; confirmed once `flightDebounceSamples` are seen in a row.
        case awaitingFlightConfirmation(takeoffCandidate: TimeInterval, consecutiveCount: Int)
        case flight(takeoffAt: TimeInterval, peakRotationRate: Double)
    }

    private let thresholds: Thresholds
    private let mode: JumpMode
    private let gravity: Double = 9.81
    private var phase: Phase = .armed

    public init(mode: JumpMode = .guided, thresholds: Thresholds = Thresholds()) {
        self.mode = mode
        self.thresholds = thresholds
    }

    public func reset() {
        phase = .armed
    }

    @discardableResult
    public func process(_ sample: MotionSample) -> JumpDetectorEvent? {
        let magnitude = sample.rawAcceleration.magnitude

        switch phase {
        case .armed:
            guard magnitude > thresholds.propulsionG else { return nil }
            phase = .propulsion(startedAt: sample.timestamp)
            return nil

        case .propulsion(let startedAt):
            let sustained = sample.timestamp - startedAt
            // Check the flight transition first: magnitude falling below
            // flightG is expected to also be below propulsionG (flightG is
            // the smaller threshold), so this must be tested before the
            // "reverted to baseline" check below, not after it.
            if magnitude < thresholds.flightG {
                phase = .awaitingFlightConfirmation(takeoffCandidate: sample.timestamp, consecutiveCount: 1)
                return sustained >= thresholds.minPropulsionDuration ? .propulsionStarted : nil
            }
            guard magnitude > thresholds.propulsionG else {
                // Sagged back toward baseline without ever reaching flight — treat as noise, rearm.
                phase = .armed
                return nil
            }
            if sustained >= thresholds.minPropulsionDuration {
                return .propulsionStarted
            }
            return nil

        case .awaitingFlightConfirmation(let candidate, let count):
            if magnitude < thresholds.flightG {
                let newCount = count + 1
                if newCount >= thresholds.flightDebounceSamples {
                    phase = .flight(takeoffAt: candidate, peakRotationRate: sample.rotationRate.magnitude)
                    return .tookOff
                }
                phase = .awaitingFlightConfirmation(takeoffCandidate: candidate, consecutiveCount: newCount)
                return nil
            } else {
                // Bounced back up before confirming flight — false start, go back to propulsion watch.
                phase = .propulsion(startedAt: sample.timestamp)
                return nil
            }

        case .flight(let takeoffAt, let peakRotationRate):
            let updatedPeakRotation = max(peakRotationRate, sample.rotationRate.magnitude)
            guard magnitude > thresholds.landingG else {
                phase = .flight(takeoffAt: takeoffAt, peakRotationRate: updatedPeakRotation)
                return nil
            }

            let hangTime = sample.timestamp - takeoffAt
            phase = .armed
            guard hangTime >= thresholds.minHangTime, hangTime <= thresholds.maxHangTime else {
                return .discarded
            }

            let jumpHeightCm = gravity * hangTime * hangTime / 8 * 100
            let contaminated = updatedPeakRotation > thresholds.rotationContaminationThreshold
            let confidence = contaminated ? 0.5 : 1.0
            let result = JumpResult(
                hangTime: hangTime,
                jumpHeightCm: jumpHeightCm,
                mode: mode,
                confidence: confidence
            )
            return .landed(result)
        }
    }
}
