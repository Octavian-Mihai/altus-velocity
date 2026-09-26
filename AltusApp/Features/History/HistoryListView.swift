import SwiftUI
import SwiftData
import Charts

struct HistoryListView: View {
    @Query(sort: \JumpTest.date, order: .reverse) private var jumpTests: [JumpTest]
    @Query(sort: \LiftSet.date, order: .reverse) private var liftSets: [LiftSet]

    var body: some View {
        NavigationStack {
            List {
                if jumpTests.count > 1 {
                    Section("Jump Height Trend") {
                        Chart(jumpTests.reversed(), id: \.id) { jump in
                            LineMark(
                                x: .value("Date", jump.date),
                                y: .value("Height (cm)", jump.jumpHeightCm)
                            )
                            .interpolationMethod(.catmullRom)
                            PointMark(
                                x: .value("Date", jump.date),
                                y: .value("Height (cm)", jump.jumpHeightCm)
                            )
                        }
                        .frame(height: 160)
                    }
                }

                Section("Jump Tests") {
                    if jumpTests.isEmpty {
                        Text("No jump tests yet").foregroundStyle(.secondary)
                    }
                    ForEach(jumpTests, id: \.id) { jump in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(String(format: "%.1f cm", jump.jumpHeightCm))
                                    .font(.headline)
                                Text(jump.date, style: .date)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if jump.confidence < 1.0 {
                                Image(systemName: "exclamationmark.triangle")
                                    .foregroundStyle(.orange)
                                    .help("Possible arm-swing during flight")
                            }
                        }
                    }
                }

                Section("Lift Sets") {
                    if liftSets.isEmpty {
                        Text("No lift sets yet").foregroundStyle(.secondary)
                    }
                    ForEach(liftSets, id: \.id) { set in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(set.exercise?.name ?? "Lift")
                                .font(.headline)
                            Text("\(set.reps.count) reps • \(set.date.formatted(date: .abbreviated, time: .shortened))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if let last = set.reps.last {
                                Text(String(format: "%.0f%% velocity loss", last.velocityLossPercent))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("History")
        }
    }
}
