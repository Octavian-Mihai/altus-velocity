import Foundation
import AltusKit

@MainActor
final class LiftSetSessionController: ObservableObject {
    @Published private(set) var isActive = false
    @Published private(set) var repCount = 0
    @Published private(set) var lastRepDescription = "Ready"

    private let motionProvider = CoreMotionProvider()
    private let workoutSession = WorkoutSessionManager()
    private let detector = RepDetector()

    private var sessionID = UUID()
    private var streamTask: Task<Void, Never>?
    private var completedReps: [RepResult] = []
    private var currentPhase: LivePhase = .eccentric

    func start() {
        guard !isActive else { return }
        isActive = true
        sessionID = UUID()
        repCount = 0
        completedReps = []
        currentPhase = .eccentric
        detector.startSet()
        lastRepDescription = "Set started"

        WatchConnectivityManager.shared.sendLifecycle(
            SessionLifecycleMessage(sessionID: sessionID, kind: .liftSet, event: .started)
        )

        do {
            try workoutSession.start()
        } catch {
            lastRepDescription = "Couldn't start sensors"
        }

        streamTask = Task { [weak self] in
            guard let self else { return }
            for await sample in motionProvider.makeStream() {
                await self.consume(sample)
            }
        }
    }

    func stop() {
        guard isActive else { return }
        isActive = false
        streamTask?.cancel()
        streamTask = nil
        workoutSession.stop()
        WatchConnectivityManager.shared.sendFinalResult(
            SessionFinalResult(sessionID: sessionID, kind: .liftSet, repResults: completedReps)
        )
        WatchConnectivityManager.shared.sendLifecycle(
            SessionLifecycleMessage(sessionID: sessionID, kind: .liftSet, event: .ended)
        )
    }

    private func consume(_ sample: MotionSample) {
        let event = detector.process(sample)
        if let event {
            handle(event, sample: sample)
        } else if currentPhase == .concentric {
            // Mid-rep, no new event yet — stream the live velocity reading.
            sendLive(phase: .concentric, value: detector.currentVelocity, repIndex: repCount + 1, loss: nil, sample: sample, force: false)
        }
    }

    private func handle(_ event: RepDetectorEvent, sample: MotionSample) {
        switch event {
        case .eccentricStarted:
            currentPhase = .eccentric
            sendLive(phase: .eccentric, value: 0, repIndex: repCount + 1, loss: nil, sample: sample, force: true)

        case .concentricStarted:
            currentPhase = .concentric
            sendLive(phase: .concentric, value: 0, repIndex: repCount + 1, loss: nil, sample: sample, force: true)

        case .repCompleted(let result):
            currentPhase = .lockout
            completedReps.append(result)
            repCount = completedReps.count
            lastRepDescription = String(format: "Rep %d — %.2f m/s", result.index, result.meanConcentricVelocityMps)
            sendLive(
                phase: .lockout,
                value: result.meanConcentricVelocityMps,
                repIndex: result.index,
                loss: result.velocityLossPercent,
                sample: sample,
                force: true
            )
        }
    }

    private func sendLive(phase: LivePhase, value: Double, repIndex: Int?, loss: Double?, sample: MotionSample, force: Bool) {
        let payload = LiveMetricsPayload(
            sessionID: sessionID,
            kind: .liftSet,
            timestamp: sample.timestamp,
            phase: phase,
            currentValue: value,
            repIndex: repIndex,
            cumulativeVelocityLossPercent: loss
        )
        WatchConnectivityManager.shared.sendLiveMetrics(payload, forcePhaseChange: force)
    }
}
