import Foundation
import HealthKit

/// Wraps `HKWorkoutSession` + `HKLiveWorkoutBuilder` purely to keep the watch
/// app alive and `CMMotionManager` sampling in the background during a jump
/// test or lift set — not to record a "workout" the user thinks of as such.
/// There's no vertical-jump or VBT HKWorkoutActivityType, so
/// `.functionalStrengthTraining` is used as the closest fit.
final class WorkoutSessionManager: NSObject {
    private let healthStore = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?

    var isAuthorizationAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    func requestAuthorization() async throws {
        guard isAuthorizationAvailable else { return }
        try await healthStore.requestAuthorization(toShare: [HKObjectType.workoutType()], read: [])
    }

    func start() throws {
        guard isAuthorizationAvailable else { return }

        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .functionalStrengthTraining
        configuration.locationType = .indoor

        let session = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
        let builder = session.associatedWorkoutBuilder()
        builder.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: configuration)

        self.session = session
        self.builder = builder

        session.startActivity(with: Date())
        builder.beginCollection(withStart: Date()) { _, _ in }
    }

    func stop() {
        guard let session, let builder else { return }
        session.end()
        builder.endCollection(withEnd: Date()) { [weak self] _, _ in
            builder.finishWorkout { _, _ in }
            self?.session = nil
            self?.builder = nil
        }
    }
}
