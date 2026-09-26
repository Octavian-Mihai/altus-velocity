import Foundation

/// Abstracts the source of `MotionSample`s so algorithms in AltusKit never
/// depend on CoreMotion directly. `CoreMotionProvider` (in the AltusWatch
/// target) is the live implementation; tests replay recorded or synthetic
/// samples through the same protocol.
public protocol MotionSampleProviding: Sendable {
    func makeStream() -> AsyncStream<MotionSample>
}
