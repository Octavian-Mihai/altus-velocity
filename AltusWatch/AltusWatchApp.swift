import SwiftUI

@main
struct AltusWatchApp: App {
    var body: some Scene {
        WindowGroup {
            TabView {
                NavigationStack {
                    JumpTestWatchView()
                }
                NavigationStack {
                    LiftSessionWatchView()
                }
            }
            .tabViewStyle(.verticalPage)
        }
    }
}
