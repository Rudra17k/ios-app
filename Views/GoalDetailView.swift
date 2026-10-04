import SwiftUI

struct GoalDetailView: View {
    @ObservedObject var goalStore: GoalStore
    let goalId: UUID

    @State private var showingContributeSheet = false
    @State private var showingEditSheet = false
    @State private var selectedCalendarDate: Date? = Date()
    @State private var calendarMonth: Date = Date()

    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var goal: SavingsGoal? {
        goalStore.goals.first(where: { $0.id == goalId })
    }

    var body: some View {
        Group {
            if let goal = goal {
                ScrollView {
                    VStack(spacing: 20) {
                        // Header Summary Card
                        goalSummaryCard(goal)

                        // Consistency Dashboard
                        consistencyMetricsSection(goal)

                        // Savings Calendar (Stage 4)
                        savingsCalendarSection(goal)

                        // Cost Breakdown (if present)
                        if !goal.costBreakdown.isEmpty {
                            costBreakdownSection(goal)
                        }

                        // Contribution History
                        contributionHistorySection(goal)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                }
                .navigationTitle(goal.title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            showingEditSheet = true
                        } label: {
                            Text("Edit")
                        }
                    }
                }
                .safeAreaInset(edge: .bottom) {
                    contributeFloatingBar(goal)
                }
                .sheet(isPresented: $showingContributeSheet) {
                    ContributeSheet(goalStore: goalStore, goalId: goal.id)
                }
                .sheet(isPresented: $showingEditSheet) {
                    EditGoalSheet(goalStore: goalStore, goal: goal)
                }
            } else {
                VStack(spacing: 12) {
                    Text("Goal Not Found")
                        .font(.headline)
                    Button("Go Back") { dismiss() }
                }
            }
        }
    }

    // MARK: - Goal Summary Card
    private func goalSummaryCard(_ goal: SavingsGoal) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    if let destination = goal.destination {
                        Label(destination, systemImage: "mappin.and.ellipse")
                            .font(.subheadline)
                            .foregroundColor(.blue)
                    }
                    Text(goal.title)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                }
                Spacer()
                if goal.isCompleted {
                    Label("Target Achieved", systemImage: "checkmark.seal.fill")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.green.opacity(0.15))
                        .clipShape(Capsule())
                }
            }

            // Progress Bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(.tertiarySystemFill))
                        .frame(height: 10)
                    Capsule()
                        .fill(goal.isCompleted ? Color.green : Color.blue)
                        .frame(width: max(0, min(geo.size.width, geo.size.width * CGFloat(goal.progressFraction))), height: 10)
                }
            }
            .frame(height: 10)

            // Primary Numbers Grid
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Saved")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(CurrencyHelper.shared.format(goal.confirmedSaved))
                        .font(.system(.title3, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                }
                Spacer()
                VStack(alignment: .center, spacing: 2) {
                    Text("Target")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(CurrencyHelper.shared.format(goal.targetAmount))
                        .font(.system(.title3, design: .rounded))
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Remaining")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(CurrencyHelper.shared.format(goal.remainingAmount))
                        .font(.system(.title3, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundColor(goal.isCompleted ? .green : .orange)
                }
            }

            Divider()

            // Required Daily Pace & Days Left
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Daily Suggested Pace")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(CurrencyHelper.shared.formatWhole(goal.currentDailyPace()))
                            .font(.system(.title3, design: .rounded))
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                        Text("/ day")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Time Left")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(goal.remainingDays()) days")
                        .font(.headline)
                        .foregroundColor(.primary)
                }
            }
        }
        .padding(18)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(18)
    }

    // MARK: - Consistency Metrics Section
    private func consistencyMetricsSection(_ goal: SavingsGoal) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Consistency & Habits")
                .font(.headline)
                .foregroundColor(.primary)

            HStack(spacing: 12) {
                // Streak Card
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "flame.fill")
                            .foregroundColor(.orange)
                        Text("Active Streak")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Text("\(goal.consecutiveContributionStreak) days")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    Text("Encouraging pace")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(14)

                // Days Met Target Card
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.blue)
                        Text("Target Met")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Text("\(goal.daysMeetingTargetCount) days")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    Text("Total saved days: \(goal.totalContributionDaysCount)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(14)
            }
        }
    }

    // MARK: - Savings Calendar Section (Stage 4)
    private func savingsCalendarSection(_ goal: SavingsGoal) -> some View {
        let calendar = Calendar.current
        let monthDays = daysInMonth(for: calendarMonth, calendar: calendar)

        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Savings Calendar")
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text(monthTitle(for: calendarMonth))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
                // Month Navigation
                HStack(spacing: 12) {
                    Button {
                        if let prev = calendar.date(byAdding: .month, value: -1, to: calendarMonth) {
                            calendarMonth = prev
                        }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.body)
                            .padding(8)
                            .background(Color(.tertiarySystemBackground))
                            .clipShape(Circle())
                    }
                    .accessibilityLabel("Previous month")

                    Button {
                        if let next = calendar.date(byAdding: .month, value: 1, to: calendarMonth) {
                            calendarMonth = next
                        }
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.body)
                            .padding(8)
                            .background(Color(.tertiarySystemBackground))
                            .clipShape(Circle())
                    }
                    .accessibilityLabel("Next month")
                }
            }

            // Compact Legend (Color + Symbol + Text)
            HStack(spacing: 14) {
                legendItem(symbol: "star.fill", label: "Above Target", color: .purple)
                legendItem(symbol: "checkmark", label: "Target Met", color: .green)
                legendItem(symbol: "circle.fill", label: "Below Target", color: .blue.opacity(0.6))
                legendItem(symbol: "circle", label: "No Activity", color: .secondary.opacity(0.4))
            }
            .font(.caption2)

            // Day of Week Header
            HStack {
                ForEach(["S", "M", "T", "W", "T", "F", "S"], id: \.self) { day in
                    Text(day)
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            // Days Grid
            let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(monthDays, id: \.self) { date in
                    if let date = date {
                        calendarCell(for: date, in: goal, calendar: calendar)
                    } else {
                        Color.clear.frame(height: 38)
                    }
                }
            }

            // Date Inspector
            if let selected = selectedCalendarDate {
                dateInspectorCard(for: selected, in: goal, calendar: calendar)
            }
        }
        .padding(18)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(18)
    }

    private func legendItem(symbol: String, label: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: symbol)
                .foregroundColor(color)
            Text(label)
                .foregroundColor(.secondary)
        }
    }

    private func calendarCell(for date: Date, in goal: SavingsGoal, calendar: Calendar) -> some View {
        let comparison = goal.comparisonForDate(date, calendar: calendar)
        let isSelected = selectedCalendarDate.map { calendar.isDate($0, inSameDayAs: date) } ?? false
        let dayNum = calendar.component(.day, from: date)

        let cellColor: Color
        let symbol: String?

        switch comparison {
        case .aboveTarget:
            cellColor = Color.purple.opacity(0.3)
            symbol = "star.fill"
        case .targetReached:
            cellColor = Color.green.opacity(0.25)
            symbol = "checkmark"
        case .belowTarget:
            cellColor = Color.blue.opacity(0.18)
            symbol = "circle.fill"
        case .neutral:
            cellColor = Color(.tertiarySystemBackground)
            symbol = nil
        }

        return Button {
            selectedCalendarDate = date
            HapticsManager.shared.lightFeedback()
        } label: {
            VStack(spacing: 2) {
                Text("\(dayNum)")
                    .font(.caption)
                    .fontWeight(isSelected ? .bold : .regular)
                    .foregroundColor(.primary)

                if let symbol = symbol {
                    Image(systemName: symbol)
                        .font(.system(size: 8))
                        .foregroundColor(comparison == .aboveTarget ? .purple : (comparison == .targetReached ? .green : .blue))
                } else {
                    Spacer().frame(height: 8)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 38)
            .background(cellColor)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(calendar.component(.day, from: date)) \(monthTitle(for: date)): \(comparison.rawValue)")
    }

    private func dateInspectorCard(for date: Date, in goal: SavingsGoal, calendar: Calendar) -> some View {
        let savedOnDay = goal.contributionAmount(on: date, calendar: calendar)
        let snapshotTarget = goal.targetForDate(date, calendar: calendar)
        let comparison = goal.comparisonForDate(date, calendar: calendar)

        let df = DateFormatter()
        df.dateStyle = .medium
        let dateString = df.string(from: date)

        return HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(dateString)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                Text(comparison.rawValue)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("Saved: \(CurrencyHelper.shared.format(savedOnDay))")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                Text("Day's Target: \(CurrencyHelper.shared.formatWhole(snapshotTarget))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .background(Color(.tertiarySystemBackground))
        .cornerRadius(12)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Cost Breakdown Section
    private func costBreakdownSection(_ goal: SavingsGoal) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Trip Cost Breakdown")
                .font(.headline)
                .foregroundColor(.primary)

            ForEach(goal.costBreakdown) { item in
                HStack {
                    Text(item.title)
                        .font(.body)
                        .foregroundColor(.primary)
                    Spacer()
                    Text(CurrencyHelper.shared.format(item.amount))
                        .font(.body)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }
                .padding(12)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
            }
        }
    }

    // MARK: - Contribution History Section
    private func contributionHistorySection(_ goal: SavingsGoal) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Contribution History (\(goal.contributions.count))")
                .font(.headline)
                .foregroundColor(.primary)

            if goal.contributions.isEmpty {
                Text("No contributions recorded yet. Tap '+ Contribute' below to start!")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
            } else {
                let sortedContributions = goal.contributions.sorted { $0.date > $1.date }
                ForEach(sortedContributions) { contrib in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(dateString(for: contrib.date))
                                .font(.caption)
                                .foregroundColor(.secondary)
                            if let note = contrib.note, !note.isEmpty {
                                Text(note)
                                    .font(.body)
                                    .foregroundColor(.primary)
                            }
                        }
                        Spacer()
                        Text("+\(CurrencyHelper.shared.format(contrib.amount))")
                            .font(.system(.headline, design: .rounded))
                            .fontWeight(.bold)
                            .foregroundColor(.green)

                        Button {
                            goalStore.deleteContribution(contributionId: contrib.id, from: goal.id)
                        } label: {
                            Image(systemName: "trash")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(6)
                        }
                        .accessibilityLabel("Delete contribution")
                    }
                    .padding(12)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                }
            }
        }
    }

    // MARK: - Contribute Floating Bar
    private func contributeFloatingBar(_ goal: SavingsGoal) -> some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 12) {
                Button {
                    showingContributeSheet = true
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Record Contribution")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(14)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)
        }
    }

    // MARK: - Calendar Helpers
    private func monthTitle(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }

    private func dateString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func daysInMonth(for date: Date, calendar: Calendar) -> [Date?] {
        guard let interval = calendar.dateInterval(of: .month, for: date) else { return [] }
        let firstDay = interval.start
        let weekday = calendar.component(.weekday, from: firstDay) - 1 // 0 for Sunday
        let range = calendar.range(of: .day, in: .month, for: date)!

        var days: [Date?] = Array(repeating: nil, count: weekday)
        for day in 1...range.count {
            if let dayDate = calendar.date(byAdding: .day, value: day - 1, to: firstDay) {
                days.append(dayDate)
            }
        }
        return days
    }
}

// MARK: - Contribute Sheet
struct ContributeSheet: View {
    @ObservedObject var goalStore: GoalStore
    let goalId: UUID
    @Environment(\.dismiss) private var dismiss

    @State private var amountString = ""
    @State private var date = Date()
    @State private var note = ""
    @State private var showError = false

    private var parsedAmount: Decimal? {
        guard let dec = CurrencyHelper.shared.parseDecimal(from: amountString), dec > 0 else { return nil }
        return dec
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Amount Set Aside") {
                    HStack {
                        Text("₹")
                            .font(.title2)
                            .bold()
                        TextField("0", text: $amountString)
                            .font(.title2)
                            .keyboardType(.decimalPad)
                    }
                }

                Section("Details") {
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                    TextField("Note (optional)", text: $note)
                }
            }
            .navigationTitle("Record Contribution")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard let amount = parsedAmount else {
                            showError = true
                            return
                        }
                        goalStore.addContribution(to: goalId, amount: amount, date: date, note: note.isEmpty ? nil : note)
                        dismiss()
                    }
                    .disabled(parsedAmount == nil)
                }
            }
            .alert("Invalid Amount", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Please enter an amount greater than ₹0.")
            }
        }
    }
}

// MARK: - Edit Goal Sheet
struct EditGoalSheet: View {
    @ObservedObject var goalStore: GoalStore
    let goal: SavingsGoal
    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var destination: String
    @State private var targetAmountString: String
    @State private var targetDate: Date

    init(goalStore: GoalStore, goal: SavingsGoal) {
        self.goalStore = goalStore
        self.goal = goal
        _title = State(initialValue: goal.title)
        _destination = State(initialValue: goal.destination ?? "")
        _targetAmountString = State(initialValue: NSDecimalNumber(decimal: goal.targetAmount).stringValue)
        _targetDate = State(initialValue: goal.targetDate)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Goal Details") {
                    TextField("Goal Name (e.g. Goa Trip)", text: $title)
                    TextField("Destination (optional)", text: $destination)
                }

                Section("Target") {
                    HStack {
                        Text("₹")
                        TextField("Target Amount", text: $targetAmountString)
                            .keyboardType(.decimalPad)
                    }
                    DatePicker("Target Date", selection: $targetDate, in: Date()..., displayedComponents: .date)
                }

                Section {
                    Button(role: .destructive) {
                        goalStore.deleteGoal(id: goal.id)
                        dismiss()
                    } label: {
                        Text("Delete Goal")
                    }
                }
            }
            .navigationTitle("Edit Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if let targetDec = CurrencyHelper.shared.parseDecimal(from: targetAmountString), !title.isEmpty {
                            var updated = goal
                            updated.title = title
                            updated.destination = destination.isEmpty ? nil : destination
                            updated.targetAmount = targetDec
                            updated.targetDate = targetDate
                            goalStore.updateGoal(updated)
                            dismiss()
                        }
                    }
                }
            }
        }
    }
}
