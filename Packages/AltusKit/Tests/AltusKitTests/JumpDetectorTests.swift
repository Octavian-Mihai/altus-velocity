import XCTest
@testable import AltusKit

final class JumpDetectorTests: XCTestCase {
    private let dt: TimeInterval = 0.02

    /// rest -> propulsion -> flight (25 samples, i.e. 0.5s hang time) -> landing spike.
    private func makeCleanJumpSamples(rotation: Double = 0.0) -> [MotionSample] {
        var samples: [MotionSample] = []
        var t: TimeInterval = 0
        samples += syntheticRun(from: t, count: 5, dt: dt, userAccelZ: 0.0)          // rest, raw magnitude 1g
        t += 5 * dt
        samples += syntheticRun(from: t, count: 10, dt: dt, userAccelZ: -0.6)        // propulsion, raw magnitude 1.6g
        t += 10 * dt
        samples += syntheticRun(from: t, count: 25, dt: dt, userAccelZ: 1.0, rotation: rotation) // flight, raw magnitude 0g
        t += 25 * dt
        samples += [syntheticSample(t: t, userAccelZ: -1.5, rotation: rotation)]      // landing spike, raw magnitude 2.5g
        t += dt
        samples += syntheticRun(from: t, count: 5, dt: dt, userAccelZ: 0.0)          // rest again
        return samples
    }

    func testCleanJumpProducesExpectedHangTimeAndHeight() {
        let detector = JumpDetector(mode: .guided)
        var landedResult: JumpResult?

        for sample in makeCleanJumpSamples() {
            if case .landed(let result) = detector.process(sample) {
                landedResult = result
            }
        }

        let result = try! XCTUnwrap(landedResult)
        XCTAssertEqual(result.hangTime, 0.5, accuracy: 0.001)
        // h = g * t^2 / 8 = 9.81 * 0.25 / 8 = 0.306... m = 30.66 cm
        XCTAssertEqual(result.jumpHeightCm, 30.66, accuracy: 0.1)
        XCTAssertEqual(result.confidence, 1.0, accuracy: 0.001)
        XCTAssertEqual(result.mode, .guided)
    }

    func testHighRotationDuringFlightLowersConfidence() {
        let detector = JumpDetector(mode: .freeSwing)
        var landedResult: JumpResult?

        for sample in makeCleanJumpSamples(rotation: 3.0) {
            if case .landed(let result) = detector.process(sample) {
                landedResult = result
            }
        }

        let result = try! XCTUnwrap(landedResult)
        XCTAssertEqual(result.confidence, 0.5, accuracy: 0.001)
    }

    func testImplausiblyShortFlightIsDiscardedAsNoise() {
        let detector = JumpDetector()
        var events: [JumpDetectorEvent] = []
        var t: TimeInterval = 0

        for sample in syntheticRun(from: t, count: 5, dt: dt, userAccelZ: 0.0) {
            events.append(contentsOf: [detector.process(sample)].compactMap { $0 })
        }
        t += 5 * dt
        for sample in syntheticRun(from: t, count: 10, dt: dt, userAccelZ: -0.6) {
            events.append(contentsOf: [detector.process(sample)].compactMap { $0 })
        }
        t += 10 * dt
        // Only 4 flight-zone samples (0.08s) — below the default 0.10s minHangTime.
        for sample in syntheticRun(from: t, count: 4, dt: dt, userAccelZ: 1.0) {
            events.append(contentsOf: [detector.process(sample)].compactMap { $0 })
        }
        t += 4 * dt
        events.append(contentsOf: [detector.process(syntheticSample(t: t, userAccelZ: -1.5))].compactMap { $0 })

        XCTAssertTrue(events.contains(.discarded))
        XCTAssertFalse(events.contains { if case .landed = $0 { return true }; return false })
    }
}
