import Foundation

/// The kind of session currently streaming live metrics. Deliberately an
/// open enum of session kinds (not just "jump" fields hardcoded into the
/// payload) so a future running/sprint session can add a case without
/// reshaping this type.
public enum LiveSessionKind: String, Codable, Sendable {
    case jumpTest
    case liftSet
}

/// Coarse phase within the current session, mirroring the detector state
/// machines in `JumpDetector`/`RepDetector`. Used by the UI to drive
/// state-dependent copy/animations on both Watch and iPhone.
public enum LivePhase: String, Codable, Sendable {
    case armed
    case propulsion
    case flight
    case landed
    case eccentric
    case bottomPause
    case concentric
    case lockout
}

/// A lightweight, throttled snapshot of an in-progress session, streamed
/// from Watch to iPhone over `WCSession.sendMessage` so both screens show
/// the same live numbers. Never carries raw sensor samples — only derived,
/// already-computed values.
public struct LiveMetricsPayload: Codable, Equatable, Sendable {
    public let sessionID: UUID
    public let kind: LiveSessionKind
    public let timestamp: TimeInterval
    public let phase: LivePhase
    /// Phase-dependent headline number: elapsed flight time for a jump in
    /// progress, or current rep's live velocity for a lift set.
    public let currentValue: Double
    public let repIndex: Int?
    public let cumulativeVelocityLossPercent: Double?

    public init(
        sessionID: UUID,
        kind: LiveSessionKind,
        timestamp: TimeInterval,
        phase: LivePhase,
        currentValue: Double,
        repIndex: Int? = nil,
        cumulativeVelocityLossPercent: Double? = nil
    ) {
        self.sessionID = sessionID
        self.kind = kind
        self.timestamp = timestamp
        self.phase = phase
        self.currentValue = currentValue
        self.repIndex = repIndex
        self.cumulativeVelocityLossPercent = cumulativeVelocityLossPercent
    }
}
