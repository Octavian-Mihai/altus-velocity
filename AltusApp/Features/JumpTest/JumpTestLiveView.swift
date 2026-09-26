import SwiftUI
import SwiftData
import AltusKit

struct JumpTestLiveView: View {
    @EnvironmentObject private var connectivity: PhoneConnectivityManager
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \JumpTest.date, order: .reverse) private var recentJumps: [JumpTest]

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                ConnectionBadge(isReachable: connectivity.isWatchReachable)

                liveMetricCard

                if let best = recentJumps.first {
                    VStack(spacing: 4) {
                        Text("Last jump")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(String(format: "%.1f cm", best.jumpHeightCm))
                            .font(.title2.bold())
                    }
                }

                Spacer()

                Text("Start a jump test from the Altus app on your Apple Watch. Results appear here live and are saved automatically.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .padding()
            .navigationTitle("Jump Test")
        }
        .onChange(of: connectivity.latestFinalResult) { _, newValue in
            guard let newValue, newValue.kind == .jumpTest, let result = newValue.jumpResult else { return }
            modelContext.insert(JumpTest(result: result))
            try? modelContext.save()
        }
    }

    private var liveMetricCard: some View {
        VStack(spacing: 8) {
            if let live = connectivity.latestLiveMetrics, live.kind == .jumpTest {
                Text(phaseLabel(for: live.phase))
                    .font(.title3)
                    .foregroundStyle(.secondary)
                Text(String(format: "%.2f s", live.currentValue))
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .monospacedDigit()
            } else {
                Image(systemName: "figure.jumprope")
                    .font(.system(size: 40))
                    .foregroundStyle(.secondary)
                Text("Waiting for a jump test to start on your Watch")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20))
    }

    private func phaseLabel(for phase: LivePhase) -> String {
        switch phase {
        case .armed: return "Armed"
        case .propulsion: return "Pushing off"
        case .flight: return "Airborne"
        case .landed: return "Landed"
        default: return phase.rawValue.capitalized
        }
    }
}

struct ConnectionBadge: View {
    let isReachable: Bool

    var body: some View {
        Label(
            isReachable ? "Watch connected" : "Watch not reachable",
            systemImage: isReachable ? "applewatch.radiowaves.left.and.right" : "applewatch.slash"
        )
        .font(.footnote)
        .foregroundStyle(isReachable ? .green : .secondary)
    }
}
