import Foundation
import WatchConnectivity
import AltusKit

/// iPhone side of the live Watch <-> iPhone link. Mirrors whatever the Watch
/// is streaming (`latestLiveMetrics`) so both screens show the same numbers
/// at the same time, and surfaces completed sessions (`latestFinalResult`)
/// for views to persist into SwiftData.
@MainActor
final class PhoneConnectivityManager: NSObject, ObservableObject {
    static let shared = PhoneConnectivityManager()

    @Published private(set) var isWatchReachable = false
    @Published private(set) var latestLiveMetrics: LiveMetricsPayload?
    @Published private(set) var latestFinalResult: SessionFinalResult?

    private let session = WCSession.default

    override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        session.delegate = self
        session.activate()
    }

    private func handle(_ message: [String: Any]) {
        guard let type = SessionEnvelope.messageType(of: message) else { return }
        switch type {
        case .liveMetrics:
            guard let payload = try? SessionEnvelope.decode(LiveMetricsPayload.self, from: message) else { return }
            Task { @MainActor in self.latestLiveMetrics = payload }
        case .finalResult:
            guard let result = try? SessionEnvelope.decode(SessionFinalResult.self, from: message) else { return }
            Task { @MainActor in self.latestFinalResult = result }
        case .lifecycle:
            guard let lifecycle = try? SessionEnvelope.decode(SessionLifecycleMessage.self, from: message) else { return }
            Task { @MainActor in
                if lifecycle.event == .started {
                    self.latestLiveMetrics = nil
                }
            }
        }
    }
}

extension PhoneConnectivityManager: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in self.isWatchReachable = session.isReachable }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in self.isWatchReachable = session.isReachable }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        Task { @MainActor in self.handle(message) }
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        Task { @MainActor in self.handle(userInfo) }
    }
}
