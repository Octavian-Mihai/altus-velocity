import XCTest
@testable import AltusKit

final class VelocityIntegratorTests: XCTestCase {
    func testConstantAccelerationProducesLinearVelocity() {
        let integrator = VelocityIntegrator()
        let dt: TimeInterval = 0.02
        let accelG = 0.3 // well above stillAccelThreshold, so ZUPT never engages
        var t: TimeInterval = 0
        var lastVelocity: Double = 0

        // Prime with a sample at t=0 so the first real integration step
        // (t=0 -> t=dt) has a previous-acceleration value to average against —
        // otherwise the trapezoidal integrator has no prior sample to pair
        // with and silently skips that first interval.
        _ = integrator.integrate(verticalAccelerationG: accelG, timestamp: t)

        // v(t) = a * t for constant acceleration from rest.
        for i in 1...20 {
            t = Double(i) * dt
            lastVelocity = integrator.integrate(verticalAccelerationG: accelG, timestamp: t)
        }

        let expected = accelG * 9.81 * t
        XCTAssertEqual(lastVelocity, expected, accuracy: 0.01)
    }

    func testZUPTSuppressesNearZeroNoiseDrift() {
        let integrator = VelocityIntegrator()
        let dt: TimeInterval = 0.05
        var t: TimeInterval = 0
        var velocity: Double = 0

        // Alternating small noise, well under stillAccelThreshold — should
        // never accumulate into meaningful drift, and should get pinned to
        // exactly zero once ZUPT's still-duration window is confirmed.
        for i in 1...40 {
            t = Double(i) * dt
            let noise = (i % 2 == 0) ? 0.02 : -0.02
            velocity = integrator.integrate(verticalAccelerationG: noise, timestamp: t)
        }

        XCTAssertEqual(velocity, 0, accuracy: 0.05)
    }

    func testResetClearsAccumulatedVelocity() {
        let integrator = VelocityIntegrator()
        _ = integrator.integrate(verticalAccelerationG: 0.5, timestamp: 0.02)
        _ = integrator.integrate(verticalAccelerationG: 0.5, timestamp: 0.04)
        XCTAssertNotEqual(integrator.velocity, 0)

        integrator.reset()
        XCTAssertEqual(integrator.velocity, 0)
    }
}
