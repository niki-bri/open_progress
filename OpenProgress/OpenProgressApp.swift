import SwiftUI

@main
struct OpenProgressApp: App {
    @StateObject private var store = ProgressStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
        }
    }
}
