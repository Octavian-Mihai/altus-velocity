import SwiftUI
import SwiftData
import AltusKit

struct LiftSessionLiveView: View {
    @EnvironmentObject private var connectivity: PhoneConnectivityManager
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \LiftSet.date, order: .reverse) private var recentSets: [LiftSet]

    @State private var selectedCategory: ExerciseCategory = .squat
    private let rirEstimator: RIREstimating = TableBasedRIREstimator()

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                ConnectionBadge(isReachable: connectivity.isWatchReachable)

                Picker("Exercise", selection: $selectedCategory) {
                    ForEach(ExerciseCategory.allCases, id: \.self) { category in
                        Text(label(for: category)).tag(category)
                    }
                }
                .pickerStyle(.segmented)

                if !selectedCategory.isWristVelocityReliable {
                    Label(
                        "Wrist velocity is less reliable for this movement — treat results as experimental.",
                        systemImage: "exclamationmark.triangle"
                    )
                    .font(.caption)
                    .foregroundStyle(.orange)
                }

                liveMetricCard

                if let lastSet = recentSets.first, let mostRecentRep = lastSet.reps.last {
                    VStack(spacing: 4) {
                        Text("Last set: \(lastSet.reps.count) reps")
                            .font(.subheadline.bold())
                        Text(String(format: "%.0f%% velocity loss • Est. RIR %@", mostRecentRep.velocityLossPercent, mostRecentRep.estimatedRIR.map(String.init) ?? "—"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Text("Start a lift set from the Altus app on your Apple Watch. Reps and velocity stream here live.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .padding()
            .navigationTitle("Lift Set")
        }
        .onChange(of: connectivity.latestFinalResult) { _, newValue in
            guard let newValue, newValue.kind == .liftSet,
                  let repResults = newValue.repResults, !repResults.isEmpty else { return }
            persist(repResults)
        }
    }

    private func persist(_ repResults: [RepResult]) {
        let exercise = Exercise(name: label(for: selectedCategory), category: selectedCategory)
        let liftSet = LiftSet(exercise: exercise)
        liftSet.reps = repResults.map { result in
            Rep(
                result: result,
                estimatedRIR: rirEstimator.estimateRIR(velocityLossPercent: result.velocityLossPercent, exercise: selectedCategory)
            )
        }
        modelContext.insert(exercise)
        modelContext.insert(liftSet)
        try? modelContext.save()
    }

    private var liveMetricCard: some View {
        VStack(spacing: 8) {
            if let live = connectivity.latestLiveMetrics, live.kind == .liftSet {
                if let repIndex = live.repIndex {
                    Text("Rep \(repIndex)")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                Text(String(format: "%.2f m/s", live.currentValue))
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .monospacedDigit()
                if let loss = live.cumulativeVelocityLossPercent {
                    Text(String(format: "%.0f%% velocity loss", loss))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Image(systemName: "dumbbell.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.secondary)
                Text("Waiting for a lift set to start on your Watch")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20))
    }

    private func label(for category: ExerciseCategory) -> String {
        switch category {
        case .squat: return "Squat"
        case .deadlift: return "Deadlift"
        case .benchPress: return "Bench Press"
        case .other: return "Other"
        }
    }
}
