import SwiftUI

@main
struct HydrationApp: App {
    @State private var store = HydrationStore()

    var body: some Scene {
        WindowGroup {
            HydrationRootView()
                .environment(store)
        }
    }
}
