import SwiftUI
import SwiftData

@main
struct AltusApp: App {
    private let container = ModelContainer.makeAltusContainer()
    @StateObject private var connectivity = PhoneConnectivityManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(connectivity)
        }
        .modelContainer(container)
    }
}
