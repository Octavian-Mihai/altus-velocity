import Foundation

/// Estimates reps-in-reserve (RIR) from velocity loss across a set.
///
/// This is a heuristic, not a measurement — velocity-loss/RIR relationships
/// in VBT literature vary by exercise, load, and individual, and this
/// estimate should always be surfaced to the user as approximate. Callers
/// should let users tune thresholds per exercise rather than trusting the
/// default table blindly.
public protocol RIREstimating: Sendable {
    func estimateRIR(velocityLossPercent: Double, exercise: ExerciseCategory) -> Int
}

/// Buckets velocity loss into an RIR estimate. Defaults are illustrative,
/// loosely modeled on published squat/deadlift velocity-loss studies
/// (e.g. Gonzalez-Badillo & Sanchez-Medina-style thresholds), and are the
/// same across exercises by default — per-exercise tuning is expected to
/// live in app settings, not here.
public struct TableBasedRIREstimator: RIREstimating {
    public struct Bucket: Sendable {
        public let maxLossPercent: Double
        public let rir: Int
        public init(maxLossPercent: Double, rir: Int) {
            self.maxLossPercent = maxLossPercent
            self.rir = rir
        }
    }

    public static let defaultBuckets: [Bucket] = [
        Bucket(maxLossPercent: 10, rir: 4),
        Bucket(maxLossPercent: 20, rir: 3),
        Bucket(maxLossPercent: 30, rir: 2),
        Bucket(maxLossPercent: 40, rir: 1),
        Bucket(maxLossPercent: .infinity, rir: 0)
    ]

    private let buckets: [Bucket]

    public init(buckets: [Bucket] = TableBasedRIREstimator.defaultBuckets) {
        self.buckets = buckets.sorted { $0.maxLossPercent < $1.maxLossPercent }
    }

    public func estimateRIR(velocityLossPercent: Double, exercise: ExerciseCategory) -> Int {
        for bucket in buckets where velocityLossPercent <= bucket.maxLossPercent {
            return bucket.rir
        }
        return buckets.last?.rir ?? 0
    }
}
