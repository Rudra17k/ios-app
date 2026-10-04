import SwiftUI

@main
struct ExpenseTrackerApp: App {
    @StateObject private var appState = AppState.shared

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(appState)
                .onOpenURL { url in
                    appState.handle(url: url)
                }
        }
    }
}
