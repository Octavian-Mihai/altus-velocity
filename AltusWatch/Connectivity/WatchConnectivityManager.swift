import Foundation
import WatchConnectivity
import AltusKit

/// Watch side of the live Watch <-> iPhone link. Sends throttled live
/// metrics via `sendMessage` (best-effort, dropped if unreachable) and
/// guaranteed final results via `transferUserInfo` (queued, never lost).
final class WatchConnectivityManager: NSObject, WCSessionDelegate {
    static let shared = WatchConnectivityManager()

    private let session = WCSession.default
    private var lastLiveSendTime: TimeInterval = 0
    private let minLiveSendInterval: TimeInterval = 0.08 // ~12Hz cap

    override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        session.delegate = self
        session.activate()
    }

    func sendLifecycle(_ message: SessionLifecycleMessage) {
        guard let dict = try? SessionEnvelope.encode(message, type: .lifecycle) else { return }
        session.transferUserInfo(dict)
    }

    /// Throttled to `minLiveSendInterval`, except phase transitions which
    /// always send immediately regardless of the throttle window.
    func sendLiveMetrics(_ payload: LiveMetricsPayload, forcePhaseChange: Bool) {
        let now = CFAbsoluteTimeGetCurrent()
        guard forcePhaseChange || now - lastLiveSendTime > minLiveSendInterval else { return }
        guard session.activationState == .activated, session.isReachable else { return }
        guard let dict = try? SessionEnvelope.encode(payload, type: .liveMetrics) else { return }
        session.sendMessage(dict, replyHandler: nil, errorHandler: nil)
        lastLiveSendTime = now
    }

    func sendFinalResult(_ result: SessionFinalResult) {
        guard let dict = try? SessionEnvelope.encode(result, type: .finalResult) else { return }
        session.transferUserInfo(dict)
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}
}
