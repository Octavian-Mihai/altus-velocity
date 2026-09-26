import Foundation

public enum RepDetectorEvent: Equatable, Sendable {
    case eccentricStarted
    case concentricStarted
    case repCompleted(RepResult)
}

/// Segments a continuous VBT set into discrete reps from wrist-worn
/// `MotionSample`s, and computes mean concentric velocity (MCV), peak
/// velocity, and velocity loss per rep.
///
/// This is the highest-risk algorithm in the app: a wrist IMU is a proxy for
/// bar path, not a direct measurement. It correlates reasonably for
/// squat/deadlift and poorly for bench press (see
/// `ExerciseCategory.isWristVelocityReliable`). Treat automated segmentation
/// as a starting point users can review/correct, not ground truth.
public final class RepDetector {
    public struct Thresholds: Sendable {
        /// Velocity magnitude (m/s) below which motion counts as "paused" (top/bottom of rep).
        public var pauseVelocityThreshold: Double = 0.05
        /// How long a direction (or pause) must be sustained before it's confirmed, not noise.
        public var minPhaseDuration: TimeInterval = 0.08
        /// Minimum concentric displacement (m) for a rep to count as real, not a twitch.
        public var minConcentricDisplacement: Double = 0.05
        /// Minimum concentric duration for a rep to count as real.
        public var minConcentricDuration: TimeInterval = 0.15

        public init(
            pauseVelocityThreshold: Double = 0.05,
            minPhaseDuration: TimeInterval = 0.08,
            minConcentricDisplacement: Double = 0.05,
            minConcentricDuration: TimeInterval = 0.15
        ) {
            self.pauseVelocityThreshold = pauseVelocityThreshold
            self.minPhaseDuration = minPhaseDuration
            self.minConcentricDisplacement = minConcentricDisplacement
            self.minConcentricDuration = minConcentricDuration
        }
    }

    private enum Phase {
        case idle
        case eccentric
        /// Candidate transition being debounced; `since` is when the candidate direction/pause began.
        case pendingTransition(from: PendingFrom, since: TimeInterval)
        case bottomPause
        case concentric(startedAt: TimeInterval, displacement: Double, peakVelocity: Double)
    }

    private enum PendingFrom { case idleToEccentric, eccentricToPause, pauseToConcentric, concentricToLockout }

    private let thresholds: Thresholds
    private let integrator = VelocityIntegrator()
    private var phase: Phase = .idle
    private var repCount = 0
    private var firstRepMCV: Double?
    private var lastVelocity: Double = 0
    private var lastTimestamp: TimeInterval?

    public init(thresholds: Thresholds = Thresholds()) {
        self.thresholds = thresholds
    }

    /// The integrator's current velocity estimate (m/s, positive = upward),
    /// for driving a live "ticking" UI between discrete rep events.
    public var currentVelocity: Double {
        integrator.velocity
    }

    public func startSet() {
        phase = .idle
        repCount = 0
        firstRepMCV = nil
        lastVelocity = 0
        lastTimestamp = nil
        integrator.reset()
    }

    @discardableResult
    public func process(_ sample: MotionSample) -> RepDetectorEvent? {
        let velocity = integrator.integrate(
            verticalAccelerationG: sample.verticalUserAcceleration,
            timestamp: sample.timestamp
        )
        defer {
            lastVelocity = velocity
            lastTimestamp = sample.timestamp
        }

        switch phase {
        case .idle:
            if velocity < -thresholds.pauseVelocityThreshold {
                phase = .pendingTransition(from: .idleToEccentric, since: sample.timestamp)
            }
            return nil

        case .eccentric:
            if abs(velocity) < thresholds.pauseVelocityThreshold {
                phase = .pendingTransition(from: .eccentricToPause, since: sample.timestamp)
            }
            return nil

        case .bottomPause:
            if velocity > thresholds.pauseVelocityThreshold {
                phase = .pendingTransition(from: .pauseToConcentric, since: sample.timestamp)
            }
            return nil

        case .concentric(let startedAt, var displacement, var peakVelocity):
            if let last = lastTimestamp {
                let dt = sample.timestamp - last
                if dt > 0, dt < 1.0 {
                    displacement += (lastVelocity + velocity) / 2 * dt
                }
            }
            peakVelocity = max(peakVelocity, velocity)

            if velocity < thresholds.pauseVelocityThreshold {
                phase = .pendingTransition(from: .concentricToLockout, since: sample.timestamp)
                // Stash the accumulated values in case the pause confirms lockout.
                pendingConcentric = (startedAt, displacement, peakVelocity)
                return nil
            }
            phase = .concentric(startedAt: startedAt, displacement: displacement, peakVelocity: peakVelocity)
            return nil

        case .pendingTransition(let from, let since):
            let sustained = sample.timestamp - since

            switch from {
            case .idleToEccentric:
                guard velocity < -thresholds.pauseVelocityThreshold else {
                    phase = .idle
                    return nil
                }
                guard sustained >= thresholds.minPhaseDuration else { return nil }
                phase = .eccentric
                return .eccentricStarted

            case .eccentricToPause:
                guard abs(velocity) < thresholds.pauseVelocityThreshold else {
                    phase = .eccentric
                    return nil
                }
                guard sustained >= thresholds.minPhaseDuration else { return nil }
                phase = .bottomPause
                return nil

            case .pauseToConcentric:
                guard velocity > thresholds.pauseVelocityThreshold else {
                    phase = .bottomPause
                    return nil
                }
                guard sustained >= thresholds.minPhaseDuration else { return nil }
                phase = .concentric(startedAt: since, displacement: 0, peakVelocity: velocity)
                return .concentricStarted

            case .concentricToLockout:
                guard velocity < thresholds.pauseVelocityThreshold else {
                    // Resumed pushing — back to concentric, keep accumulated values.
                    if let stashed = pendingConcentric {
                        phase = .concentric(startedAt: stashed.startedAt, displacement: stashed.displacement, peakVelocity: stashed.peakVelocity)
                    } else {
                        phase = .idle
                    }
                    return nil
                }
                guard sustained >= thresholds.minPhaseDuration, let stashed = pendingConcentric else {
                    return nil
                }
                pendingConcentric = nil
                phase = .idle

                let duration = since - stashed.startedAt
                guard duration >= thresholds.minConcentricDuration,
                      abs(stashed.displacement) >= thresholds.minConcentricDisplacement else {
                    return nil
                }

                let mcv = stashed.displacement / duration
                repCount += 1
                if firstRepMCV == nil { firstRepMCV = mcv }
                let loss = firstRepMCV.map { ($0 - mcv) / $0 * 100 } ?? 0

                let result = RepResult(
                    index: repCount,
                    meanConcentricVelocityMps: mcv,
                    peakVelocityMps: stashed.peakVelocity,
                    concentricDuration: duration,
                    velocityLossPercent: loss
                )
                return .repCompleted(result)
            }
        }
    }

    private var pendingConcentric: (startedAt: TimeInterval, displacement: Double, peakVelocity: Double)?
}
