import XCTest
@testable import AltusKit

final class RepDetectorTests: XCTestCase {
    private let dt: TimeInterval = 0.02

    /// Builds one rep as a piecewise-linear velocity profile (idle -> eccentric
    /// down -> back to pause -> bottom pause -> concentric up -> decel ->
    /// lockout pause), expressed as the constant per-segment acceleration
    /// needed to hit each velocity waypoint exactly. Segment durations are
    /// exact multiples of `dt` so samples land on segment boundaries.
    private func makeRepSamples(
        startTime: TimeInterval,
        eccentricPeak: Double,
        concentricPeak: Double
    ) -> (samples: [MotionSample], endTime: TimeInterval) {
        var samples: [MotionSample] = []
        var t = startTime

        func ramp(duration: TimeInterval, from v0: Double, to v1: Double) {
            let accelG = ((v1 - v0) / duration) / 9.81
            let steps = Int((duration / dt).rounded())
            for _ in 0..<steps {
                samples.append(syntheticSample(t: t, userAccelZ: accelG))
                t += dt
            }
        }
        func hold(duration: TimeInterval) {
            let steps = Int((duration / dt).rounded())
            for _ in 0..<steps {
                samples.append(syntheticSample(t: t, userAccelZ: 0))
                t += dt
            }
        }

        hold(duration: 0.10)                                        // idle
        ramp(duration: 0.06, from: 0, to: -eccentricPeak)            // eccentric descent
        ramp(duration: 0.06, from: -eccentricPeak, to: 0)            // eccentric -> bottom
        hold(duration: 0.08)                                        // bottom pause
        ramp(duration: 0.06, from: 0, to: concentricPeak)            // concentric drive
        ramp(duration: 0.06, from: concentricPeak, to: 0)            // concentric -> lockout
        hold(duration: 0.08)                                        // lockout pause

        return (samples, t)
    }

    func testTwoRepsSegmentedWithExpectedVelocityLossOrdering() {
        // Debounce/gating tuned to the fine synthetic sample rate rather
        // than realistic gym-motion durations — see RepDetector.Thresholds.
        let thresholds = RepDetector.Thresholds(
            pauseVelocityThreshold: 0.05,
            minPhaseDuration: 0.02,
            minConcentricDisplacement: 0.001,
            minConcentricDuration: 0.02
        )
        let detector = RepDetector(thresholds: thresholds)
        detector.startSet()

        let rep1 = makeRepSamples(startTime: 0, eccentricPeak: 0.3, concentricPeak: 0.5)
        let rep2 = makeRepSamples(startTime: rep1.endTime, eccentricPeak: 0.3, concentricPeak: 0.25)

        var completedReps: [RepResult] = []
        for sample in rep1.samples + rep2.samples {
            if case .repCompleted(let result) = detector.process(sample) {
                completedReps.append(result)
            }
        }

        XCTAssertEqual(completedReps.count, 2)
        guard completedReps.count == 2 else { return }

        let firstRep = completedReps[0]
        let secondRep = completedReps[1]

        XCTAssertEqual(firstRep.index, 1)
        XCTAssertEqual(secondRep.index, 2)

        XCTAssertGreaterThan(firstRep.meanConcentricVelocityMps, 0)
        XCTAssertGreaterThan(secondRep.meanConcentricVelocityMps, 0)
        XCTAssertGreaterThanOrEqual(firstRep.peakVelocityMps, firstRep.meanConcentricVelocityMps)
        XCTAssertGreaterThanOrEqual(secondRep.peakVelocityMps, secondRep.meanConcentricVelocityMps)
        XCTAssertGreaterThan(firstRep.concentricDuration, 0)
        XCTAssertGreaterThan(secondRep.concentricDuration, 0)

        // Rep 1 is the velocity-loss reference; the deliberately weaker rep 2
        // should show positive velocity loss relative to it.
        XCTAssertEqual(firstRep.velocityLossPercent, 0, accuracy: 0.001)
        XCTAssertGreaterThan(secondRep.velocityLossPercent, 0)

        // Rep 2's concentric drive was half of rep 1's, so its MCV should be
        // meaningfully lower (loose bound — this is a segmentation/wiring
        // test, not a numerical-precision test of the integrator).
        XCTAssertLessThan(secondRep.meanConcentricVelocityMps, firstRep.meanConcentricVelocityMps)
    }
}
