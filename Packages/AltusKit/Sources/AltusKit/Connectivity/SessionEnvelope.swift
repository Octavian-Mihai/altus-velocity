import Foundation

/// The three message shapes that flow over WatchConnectivity. Distinguished
/// by a `type` tag so a single generic dictionary shape can carry any of them.
public enum WatchConnectivityMessageType: String, Codable, Sendable {
    case lifecycle
    case liveMetrics
    case finalResult
}

public enum SessionLifecycleEvent: String, Codable, Sendable {
    case started
    case ended
}

public struct SessionLifecycleMessage: Codable, Equatable, Sendable {
    public let sessionID: UUID
    public let kind: LiveSessionKind
    public let event: SessionLifecycleEvent

    public init(sessionID: UUID, kind: LiveSessionKind, event: SessionLifecycleEvent) {
        self.sessionID = sessionID
        self.kind = kind
        self.event = event
    }
}

/// Sent once, via the guaranteed `transferUserInfo` channel, when a session
/// completes — so a result is never lost even if `sendMessage` reachability
/// dropped mid-session.
public struct SessionFinalResult: Codable, Equatable, Sendable {
    public let sessionID: UUID
    public let kind: LiveSessionKind
    public let jumpResult: JumpResult?
    public let repResults: [RepResult]?

    public init(sessionID: UUID, kind: LiveSessionKind, jumpResult: JumpResult? = nil, repResults: [RepResult]? = nil) {
        self.sessionID = sessionID
        self.kind = kind
        self.jumpResult = jumpResult
        self.repResults = repResults
    }
}

public enum SessionEnvelopeError: Error {
    case missingPayload
    case unknownType
}

/// Encodes/decodes the Codable message types above into the
/// `[String: Any]` shape `WCSession` requires, so `WatchConnectivityManager`
/// and `PhoneConnectivityManager` share one serialization path instead of
/// each hand-rolling dictionary keys.
public enum SessionEnvelope {
    public static func encode<T: Encodable>(_ value: T, type: WatchConnectivityMessageType) throws -> [String: Any] {
        let data = try JSONEncoder().encode(value)
        return ["type": type.rawValue, "payload": data]
    }

    public static func messageType(of message: [String: Any]) -> WatchConnectivityMessageType? {
        guard let raw = message["type"] as? String else { return nil }
        return WatchConnectivityMessageType(rawValue: raw)
    }

    public static func decode<T: Decodable>(_ type: T.Type, from message: [String: Any]) throws -> T {
        guard let data = message["payload"] as? Data else {
            throw SessionEnvelopeError.missingPayload
        }
        return try JSONDecoder().decode(T.self, from: data)
    }
}
