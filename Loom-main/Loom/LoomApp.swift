import SwiftUI

@main
struct LoomApp: App {
    @StateObject private var store = LoomStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .preferredColorScheme(.dark)
        }
    }
}
