import AppIntents
import SwiftUI

@available(iOS 16.0, macOS 13.0, *)
struct QuickAddExpenseIntent: AppIntent {
    static var title: LocalizedStringResource = "Log an Expense"
    static var description = IntentDescription("Opens the quick expense capture screen for instant entry or Back Tap.")
    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        AppState.shared.shouldShowQuickAdd = true
        return .result()
    }
}

@available(iOS 16.0, macOS 13.0, *)
struct ExpenseTrackerShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: QuickAddExpenseIntent(),
            phrases: [
                "Log an expense in \(.applicationName)",
                "Add expense in \(.applicationName)",
                "Track expense in \(.applicationName)",
                "Quick capture in \(.applicationName)"
            ],
            shortTitle: "Log Expense",
            systemImageName: "plus.circle.fill"
        )
    }
}
