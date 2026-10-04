import SwiftUI

struct GoalsView: View {
    @ObservedObject var goalStore: GoalStore
    @ObservedObject var expenseStore: ExpenseStore
    @ObservedObject var budgetStore: BudgetStore

    @State private var showingAddGoal = false
    @State private var selectedBudgetRoomGoal: SavingsGoal? = nil
    @State private var budgetRoomSuggestedAmount: Decimal = .zero

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Budget Room Suggestion Card (if applicable)
                    budgetRoomSuggestionBanner

                    if goalStore.goals.isEmpty {
                        emptyGoalsView
                    } else {
                        ForEach(goalStore.goals) { goal in
                            NavigationLink {
                                GoalDetailView(goalStore: goalStore, goalId: goal.id)
                            } label: {
                                goalCard(goal)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            }
            .navigationTitle("Goals & Plans")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddGoal = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 22))
                    }
                    .accessibilityLabel("Add Goal")
                }
            }
            .sheet(isPresented: $showingAddGoal) {
                AddGoalView(goalStore: goalStore)
            }
            .sheet(item: $selectedBudgetRoomGoal) { goal in
                ContributeSheet(goalStore: goalStore, goalId: goal.id)
            }
        }
    }

    // MARK: - Budget Room Suggestion Banner
    @ViewBuilder
    private var budgetRoomSuggestionBanner: some View {
        let calendar = Calendar.current
        let now = Date()
        if let interval = calendar.dateInterval(of: .month, for: now), !goalStore.goals.isEmpty {
            let catTotals = expenseStore.categoryTotals(for: interval)
            let rooms = budgetStore.budgetRoom(categorySpending: catTotals).filter { $0.room > 500 }

            if let firstRoom = rooms.first, let targetGoal = goalStore.goals.first(where: { !$0.isCompleted }) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "sparkles")
                            .foregroundColor(.blue)
                        Text("Possible Budget Room")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.blue)
                    }

                    Text("You have \(CurrencyHelper.shared.formatWhole(firstRoom.room)) unspent in \(firstRoom.category.rawValue) this month. Would you like to set some aside toward \"\(targetGoal.title)\"?")
                        .font(.subheadline)
                        .foregroundColor(.primary)

                    HStack {
                        Button {
                            selectedBudgetRoomGoal = targetGoal
                        } label: {
                            Text("Set Aside Amount")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .clipShape(Capsule())
                        }

                        Text("Unspent budget is optional headroom")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(14)
                .background(Color.blue.opacity(0.12))
                .cornerRadius(14)
            }
        }
    }

    // MARK: - Goal Card
    private func goalCard(_ goal: SavingsGoal) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    if let dest = goal.destination {
                        Text(dest.uppercased())
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                    }
                    Text(goal.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                }

                Spacer()

                if goal.isCompleted {
                    Label("Completed", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.green)
                } else {
                    Text("\(goal.remainingDays()) days left")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(.tertiarySystemFill))
                        .frame(height: 8)
                    Capsule()
                        .fill(goal.isCompleted ? Color.green : Color.blue)
                        .frame(width: max(0, min(geo.size.width, geo.size.width * CGFloat(goal.progressFraction))), height: 8)
                }
            }
            .frame(height: 8)

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Saved")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(CurrencyHelper.shared.format(goal.confirmedSaved))
                        .font(.system(.subheadline, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                }

                Spacer()

                VStack(alignment: .center, spacing: 2) {
                    Text("Daily Pace")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(CurrencyHelper.shared.formatWhole(goal.currentDailyPace()))
                        .font(.system(.subheadline, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("Remaining")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(CurrencyHelper.shared.format(goal.remainingAmount))
                        .font(.system(.subheadline, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundColor(goal.isCompleted ? .green : .primary)
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
        .contentShape(Rectangle())
    }

    private var emptyGoalsView: some View {
        VStack(spacing: 16) {
            Spacer().frame(height: 40)
            Image(systemName: "airplane.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.blue.opacity(0.7))

            Text("Plan Your Next Goal or Trip")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.primary)

            Text("Set aside money steadily with a clear daily pace. Whether it's a beach getaway, a new laptop, or an emergency cushion.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            Button {
                showingAddGoal = true
            } label: {
                Text("+ Create Your First Goal")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                    .background(Color.blue)
                    .clipShape(Capsule())
            }
            .padding(.top, 8)
        }
    }
}
