import Foundation
import AltusKit

@MainActor
final class JumpTestSessionController: ObservableObject {
    @Published private(set) var isActive = false
    @Published private(set) var phaseDescription = "Ready"
    @Published private(set) var lastResult: JumpResult?

    private let motionProvider = CoreMotionProvider()
    private let workoutSession = WorkoutSessionManager()
    private let detector = JumpDetector(mode: .guided)

    private var sessionID = UUID()
    private var streamTask: Task<Void, Never>?
    private var takeoffTimestamp: TimeInterval?

    func start() {
        guard !isActive else { return }
        isActive = true
        sessionID = UUID()
        takeoffTimestamp = nil
        detector.reset()
        phaseDescription = "Armed — jump!"
        lastResult = nil

        WatchConnectivityManager.shared.sendLifecycle(
            SessionLifecycleMessage(sessionID: sessionID, kind: .jumpTest, event: .started)
        )

        do {
            try workoutSession.start()
        } catch {
            phaseDescription = "Couldn't start sensors"
        }

        streamTask = Task { [weak self] in
            guard let self else { return }
            for await sample in motionProvider.makeStream() {
                self.consume(sample)
            }
        }
    }

    func stop() {
        guard isActive else { return }
        isActive = false
        streamTask?.cancel()
        streamTask = nil
        workoutSession.stop()
        WatchConnectivityManager.shared.sendLifecycle(
            SessionLifecycleMessage(sessionID: sessionID, kind: .jumpTest, event: .ended)
        )
    }

    private func consume(_ sample: MotionSample) {
        let event = detector.process(sample)
        if let event {
            handle(event, sample: sample)
        } else if let takeoffTimestamp {
            // Still airborne, no new phase event yet — stream elapsed hang time.
            sendLive(phase: .flight, value: sample.timestamp - takeoffTimestamp, sample: sample, force: false)
        }
    }

    private func handle(_ event: JumpDetectorEvent, sample: MotionSample) {
        switch event {
        case .propulsionStarted:
            phaseDescription = "Pushing off…"
            sendLive(phase: .propulsion, value: 0, sample: sample, force: true)

        case .tookOff:
            takeoffTimestamp = sample.timestamp
            phaseDescription = "Airborne"
            sendLive(phase: .flight, value: 0, sample: sample, force: true)

        case .landed(let result):
            takeoffTimestamp = nil
            lastResult = result
            phaseDescription = String(format: "%.1f cm", result.jumpHeightCm)
            sendLive(phase: .landed, value: result.jumpHeightCm, sample: sample, force: true)
            WatchConnectivityManager.shared.sendFinalResult(
                SessionFinalResult(sessionID: sessionID, kind: .jumpTest, jumpResult: result)
            )

        case .discarded:
            takeoffTimestamp = nil
            phaseDescription = "No clean jump detected — try again"
        }
    }

    private func sendLive(phase: LivePhase, value: Double, sample: MotionSample, force: Bool) {
        let payload = LiveMetricsPayload(
            sessionID: sessionID,
            kind: .jumpTest,
            timestamp: sample.timestamp,
            phase: phase,
            currentValue: value
        )
        WatchConnectivityManager.shared.sendLiveMetrics(payload, forcePhaseChange: force)
    }
}
