import SwiftUI

struct LiftSessionWatchView: View {
    @StateObject private var controller = LiftSetSessionController()

    var body: some View {
        VStack(spacing: 10) {
            Text("Reps: \(controller.repCount)")
                .font(.headline)

            Text(controller.lastRepDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.7)

            Button(controller.isActive ? "End Set" : "Start Set") {
                if controller.isActive {
                    controller.stop()
                } else {
                    controller.start()
                }
            }
            .tint(controller.isActive ? .red : .green)
        }
        .padding()
        .navigationTitle("Lift")
    }
}
