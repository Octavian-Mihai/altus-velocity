import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            JumpTestLiveView()
                .tabItem { Label("Jump", systemImage: "figure.jumprope") }

            LiftSessionLiveView()
                .tabItem { Label("Lift", systemImage: "dumbbell.fill") }

            HistoryListView()
                .tabItem { Label("History", systemImage: "clock.arrow.circlepath") }
        }
    }
}
