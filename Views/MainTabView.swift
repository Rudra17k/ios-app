import SwiftUI

struct MainTabView: View {
    @StateObject private var expenseStore = ExpenseStore()
    @StateObject private var goalStore = GoalStore()
    @StateObject private var budgetStore = BudgetStore()
    @EnvironmentObject private var appState: AppState

    @State private var selectedTab: Int = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView(store: expenseStore)
                .tabItem {
                    Label("Expenses", systemImage: "creditcard.fill")
                }
                .tag(0)

            GoalsView(
                goalStore: goalStore,
                expenseStore: expenseStore,
                budgetStore: budgetStore
            )
            .tabItem {
                Label("Goals & Trips", systemImage: "airplane.circle.fill")
            }
            .tag(1)

            OutlookBudgetsView(
                expenseStore: expenseStore,
                budgetStore: budgetStore,
                goalStore: goalStore
            )
            .tabItem {
                Label("Outlook", systemImage: "chart.pie.fill")
            }
            .tag(2)

            SettingsPrivacyView(expenseStore: expenseStore)
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(3)
        }
        .tint(.blue)
    }
}
