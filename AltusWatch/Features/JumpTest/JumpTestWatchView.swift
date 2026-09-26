import SwiftUI

struct JumpTestWatchView: View {
    @StateObject private var controller = JumpTestSessionController()

    var body: some View {
        VStack(spacing: 10) {
            Text(controller.phaseDescription)
                .font(.headline)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.7)

            if let result = controller.lastResult {
                Text(String(format: "%.1f cm", result.jumpHeightCm))
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                Text(String(format: "%.2f s hang time", result.hangTime))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Button(controller.isActive ? "Stop" : "Start Jump Test") {
                if controller.isActive {
                    controller.stop()
                } else {
                    controller.start()
                }
            }
            .tint(controller.isActive ? .red : .green)
        }
        .padding()
        .navigationTitle("Jump")
    }
}
