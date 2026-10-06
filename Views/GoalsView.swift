import SwiftUI

struct GoalsView: View {
    @ObservedObject var goalStore: GoalStore
    @ObservedObject var expenseStore: ExpenseStore
    @ObservedObject var budgetStore: BudgetStore
    @Environment(\.colorScheme) private var colorScheme

    @State private var showingAddGoal = false
    @State private var selectedBudgetRoomGoal: SavingsGoal? = nil
    @State private var budgetRoomSuggestedAmount: Decimal = .zero

    var body: some View {
        NavigationStack {
            ZStack {
                Color(uiColor: .systemGroupedBackground)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 18) {
                        // Smart Budget Room Suggestion Card (if applicable)
                        budgetRoomSuggestionBanner

                        if goalStore.goals.isEmpty {
                            emptyGoalsView
                        } else {
                            VStack(spacing: 14) {
                                ForEach(goalStore.goals) { goal in
                                    NavigationLink {
                                        GoalDetailView(goalStore: goalStore, goalId: goal.id)
                                    } label: {
                                        goalCard(goal)
                                    }
                                    .buttonStyle(BouncyButtonStyle(scaleAmount: 0.97))
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                }
            }
            .navigationTitle("Goals & Plans")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddGoal = true
                        HapticsManager.shared.lightFeedback()
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Color.blue)
                            .clipShape(Circle())
                    }
                    .buttonStyle(BouncyButtonStyle(scaleAmount: 0.88))
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

    // MARK: - Smart Budget Room Suggestion Banner
    @ViewBuilder
    private var budgetRoomSuggestionBanner: some View {
        let calendar = Calendar.current
        let now = Date()
        if let interval = calendar.dateInterval(of: .month, for: now), !goalStore.goals.isEmpty {
            let catTotals = expenseStore.categoryTotals(for: interval)
            let rooms = budgetStore.budgetRoom(categorySpending: catTotals).filter { $0.room > 500 }

            if let firstRoom = rooms.first, let targetGoal = goalStore.goals.first(where: { !$0.isCompleted }) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.blue, Color.purple],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 28, height: 28)
                            Image(systemName: "sparkles")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.white)
                        }

                        Text("Smart Savings Insight")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(.blue)

                        Spacer()
                    }

                    Text("You have \(CurrencyHelper.shared.formatWhole(firstRoom.room)) unspent in \(firstRoom.category.rawValue) this month. Put some toward \"\(targetGoal.title)\"?")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundColor(.primary)
                        .lineSpacing(2)

                    HStack {
                        Button {
                            selectedBudgetRoomGoal = targetGoal
                            HapticsManager.shared.lightFeedback()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.right.circle.fill")
                                Text("Set Aside Headroom")
                            }
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                LinearGradient(
                                    colors: [Color.blue, Color.purple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .foregroundColor(.white)
                            .clipShape(Capsule())
                            .shadow(color: Color.blue.opacity(0.3), radius: 6, x: 0, y: 3)
                        }
                        .buttonStyle(BouncyButtonStyle(scaleAmount: 0.94))

                        Spacer()

                        Text("Optional")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.blue.opacity(colorScheme == .dark ? 0.22 : 0.12),
                                    Color.purple.opacity(colorScheme == .dark ? 0.18 : 0.08)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(Color.blue.opacity(colorScheme == .dark ? 0.3 : 0.2), lineWidth: 1)
                )
            }
        }
    }

    // MARK: - Goal Card
    private func goalCard(_ goal: SavingsGoal) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    if let dest = goal.destination, !dest.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "mappin.and.ellipse")
                                .font(.system(size: 10, weight: .bold))
                            Text(dest.uppercased())
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                        }
                        .foregroundColor(.blue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.blue.opacity(0.12))
                        .clipShape(Capsule())
                    }

                    Text(goal.title)
                        .font(.system(.title3, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                }

                Spacer()

                if goal.isCompleted {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.seal.fill")
                        Text("Achieved")
                    }
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(.green)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.green.opacity(0.16))
                    .clipShape(Capsule())
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.caption2)
                        Text("\(goal.remainingDays())d left")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(uiColor: .tertiarySystemFill))
                    .clipShape(Capsule())
                }
            }

            // High-def Gradient Progress bar
            VStack(spacing: 6) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color(uiColor: .tertiarySystemFill))
                            .frame(height: 10)

                        Capsule()
                            .fill(
                                goal.isCompleted
                                    ? LinearGradient(colors: [Color.green, Color.mint], startPoint: .leading, endPoint: .trailing)
                                    : LinearGradient(colors: [Color.blue, Color.cyan], startPoint: .leading, endPoint: .trailing)
                            )
                            .frame(
                                width: max(8, min(geo.size.width, geo.size.width * CGFloat(goal.progressFraction))),
                                height: 10
                            )
                            .animation(.spring(response: 0.4, dampingFraction: 0.75), value: goal.progressFraction)
                    }
                }
                .frame(height: 10)

                HStack {
                    Text("\(Int(goal.progressFraction * 100))% funded")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("Target: \(CurrencyHelper.shared.format(goal.targetAmount))")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(.secondary)
                }
            }

            Divider()
                .opacity(0.6)

            // Metrics Row
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("SAVED")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(.secondary)
                    Text(CurrencyHelper.shared.format(goal.confirmedSaved))
                        .font(.system(.subheadline, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                }

                Spacer()

                VStack(alignment: .center, spacing: 2) {
                    Text("DAILY PACE")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(.secondary)
                    Text(CurrencyHelper.shared.formatWhole(goal.currentDailyPace()) + "/d")
                        .font(.system(.subheadline, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("REMAINING")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(.secondary)
                    Text(CurrencyHelper.shared.format(goal.remainingAmount))
                        .font(.system(.subheadline, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundColor(goal.isCompleted ? .green : .orange)
                }
            }
        }
        .padding(18)
        .glassCard(cornerRadius: 22, strokeOpacity: 0.1, shadowRadius: 10)
        .contentShape(Rectangle())
    }

    // MARK: - Empty Goals View
    private var emptyGoalsView: some View {
        VStack(spacing: 18) {
            Spacer().frame(height: 30)

            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.blue.opacity(0.18), Color.purple.opacity(0.12)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 110, height: 110)

                Image(systemName: "airplane.circle.fill")
                    .font(.system(size: 58))
                    .foregroundColor(.blue)
            }

            VStack(spacing: 8) {
                Text("Plan Your Next Milestone")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)

                Text("Break down trips, gadgets, or emergency cushions into achievable daily targets that feel effortless.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
            }

            Button {
                showingAddGoal = true
                HapticsManager.shared.lightFeedback()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                    Text("Create Your First Goal")
                }
                .font(.system(.headline, design: .rounded))
                .fontWeight(.bold)
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        colors: [Color.blue, Color.blue.opacity(0.88)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(Capsule())
                .shadow(color: Color.blue.opacity(0.35), radius: 10, x: 0, y: 5)
            }
            .buttonStyle(BouncyButtonStyle())
            .padding(.top, 8)
        }
    }
}
