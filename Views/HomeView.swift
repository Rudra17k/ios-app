import SwiftUI

struct HomeView: View {
    @ObservedObject var store: ExpenseStore
    @EnvironmentObject private var appState: AppState
    @Environment(\.colorScheme) private var colorScheme

    @State private var showingAddExpense = false
    @State private var editingExpense: Expense? = nil
    @State private var searchText = ""
    @State private var selectedFilterCategory: ExpenseCategory? = nil
    @State private var showUndoBanner = false
    @State private var undoBannerExpense: Expense? = nil

    private var filteredExpenses: [Expense] {
        var list = store.expenses
        if let cat = selectedFilterCategory {
            list = list.filter { $0.category == cat }
        }
        if !searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            let query = searchText.lowercased()
            list = list.filter {
                $0.category.rawValue.lowercased().contains(query) ||
                ($0.note?.lowercased().contains(query) ?? false) ||
                CurrencyHelper.shared.format($0.amount).contains(query)
            }
        }
        return list
    }

    private var daysPassedInMonth: Int {
        max(1, Calendar.current.component(.day, from: Date()))
    }

    private var dailyAverageThisMonth: Decimal {
        let days = Decimal(daysPassedInMonth)
        return days > 0 ? store.thisMonthTotal / days : .zero
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(uiColor: .systemGroupedBackground)
                    .ignoresSafeArea()

                contentScrollView
            }
            .searchable(text: $searchText, prompt: "Search notes, categories, amounts")
            .navigationTitle("Expenses")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    addExpenseToolbarButton
                }
            }
            .sheet(isPresented: $showingAddExpense) {
                QuickAddView(store: store)
            }
            .sheet(item: $editingExpense) { expense in
                EditExpenseSheet(store: store, expense: expense)
            }
            .onAppear {
                checkDeepLink()
            }
            .onChange(of: appState.shouldShowQuickAdd) { shouldShow in
                if shouldShow {
                    showingAddExpense = true
                    appState.shouldShowQuickAdd = false
                }
            }
            .onChange(of: store.lastAddedExpense) { newExpense in
                handleLastAdded(newExpense)
            }
        }
    }

    private var contentScrollView: some View {
        ScrollView {
            VStack(spacing: 16) {
                if showUndoBanner, let expense = undoBannerExpense {
                    undoConfirmationBanner(for: expense)
                        .transition(.asymmetric(
                            insertion: .move(edge: .top).combined(with: .opacity).combined(with: .scale(scale: 0.9)),
                            removal: .move(edge: .top).combined(with: .opacity)
                        ))
                        .zIndex(10)
                }

                monthlySummaryCard
                    .padding(.horizontal, 16)
                    .padding(.top, 4)

                categoryFilterScrollView

                if filteredExpenses.isEmpty {
                    emptyStateView
                        .padding(.top, 20)
                } else {
                    recentActivitySection
                }
            }
        }
    }

    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Activity")
                    .font(.system(.title3, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                Spacer()
                Text("\(filteredExpenses.count) \(filteredExpenses.count == 1 ? "entry" : "entries")")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 20)

            LazyVStack(spacing: 10) {
                ForEach(filteredExpenses) { expense in
                    transactionCard(for: expense)
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.bottom, 24)
    }

    private func transactionCard(for expense: Expense) -> some View {
        Button {
            editingExpense = expense
            HapticsManager.shared.lightFeedback()
        } label: {
            ExpenseRowView(expense: expense)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(uiColor: .secondarySystemGroupedBackground))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(
                            colorScheme == .dark
                                ? Color.white.opacity(0.06)
                                : Color.black.opacity(0.04),
                            lineWidth: 1
                        )
                )
        }
        .buttonStyle(SubtlePressStyle())
        .contextMenu {
            Button(role: .destructive) {
                HapticsManager.shared.lightFeedback()
                store.deleteExpense(id: expense.id)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private var addExpenseToolbarButton: some View {
        Button {
            showingAddExpense = true
            HapticsManager.shared.lightFeedback()
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.white)
                .padding(8)
                .background(
                    Circle()
                        .fill(Color.blue.gradient)
                )
                .shadow(color: Color.blue.opacity(0.3), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(BouncyButtonStyle(scaleAmount: 0.88))
        .accessibilityLabel("Add Expense")
    }

    private func handleLastAdded(_ newExpense: Expense?) {
        if let exp = newExpense {
            undoBannerExpense = exp
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                showUndoBanner = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                withAnimation(.easeInOut(duration: 0.25)) {
                    if self.undoBannerExpense?.id == exp.id {
                        self.showUndoBanner = false
                    }
                }
            }
        }
    }

    private func checkDeepLink() {
        if appState.shouldShowQuickAdd {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.showingAddExpense = true
                self.appState.shouldShowQuickAdd = false
            }
        }
    }

    // MARK: - In-App Confirmation Banner
    private func undoConfirmationBanner(for expense: Expense) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.18))
                    .frame(width: 32, height: 32)
                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.green)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Expense Recorded")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                Text("\(CurrencyHelper.shared.format(expense.amount)) in \(expense.category.rawValue)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .lineLimit(1)
            }

            Spacer()

            Button {
                store.undoLastAdded()
                HapticsManager.shared.mediumFeedback()
                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                    showUndoBanner = false
                }
            } label: {
                Text("Undo")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(Color.blue)
                    .clipShape(Capsule())
            }
            .buttonStyle(BouncyButtonStyle(scaleAmount: 0.92))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.12), radius: 14, x: 0, y: 6)
        )
        .padding(.horizontal, 16)
        .padding(.top, 4)
    }

    // MARK: - Monthly Summary Card
    private var monthlySummaryCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.blue)
                    Text("THIS MONTH'S SPENDING")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(.secondary)
                        .tracking(0.5)
                }

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.caption2)
                    Text(currentMonthName())
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                }
                .foregroundColor(.blue)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(Color.blue.opacity(colorScheme == .dark ? 0.18 : 0.10))
                )
            }

            Text(CurrencyHelper.shared.format(store.thisMonthTotal))
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
                .contentTransition(.numericText())
                .minimumScaleFactor(0.7)
                .lineLimit(1)

            Divider()
                .opacity(colorScheme == .dark ? 0.2 : 0.6)

            // Sub-metrics Pill Row
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Daily Average")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(CurrencyHelper.shared.formatWhole(dailyAverageThisMonth) + "/day")
                        .font(.system(.subheadline, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 3) {
                    Text("Total Entries")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("\(store.expenses.count)")
                        .font(.system(.subheadline, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: colorScheme == .dark
                            ? [Color(uiColor: .secondarySystemGroupedBackground), Color(uiColor: .tertiarySystemGroupedBackground).opacity(0.6)]
                            : [Color.white, Color(uiColor: .secondarySystemGroupedBackground)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(
                    colorScheme == .dark
                        ? Color.white.opacity(0.08)
                        : Color.black.opacity(0.04),
                    lineWidth: 1
                )
        )
        .shadow(
            color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.05),
            radius: 12,
            x: 0,
            y: 4
        )
    }

    private func currentMonthName() -> String {
        let df = DateFormatter()
        df.dateFormat = "MMM yyyy"
        return df.string(from: Date())
    }

    // MARK: - Filter Pills
    private var categoryFilterScrollView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                        selectedFilterCategory = nil
                    }
                    HapticsManager.shared.lightFeedback()
                } label: {
                    Text("All Entries")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            selectedFilterCategory == nil
                                ? Color.blue
                                : Color(uiColor: .secondarySystemGroupedBackground)
                        )
                        .foregroundColor(selectedFilterCategory == nil ? .white : .secondary)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .strokeBorder(
                                    selectedFilterCategory == nil ? Color.clear : Color.primary.opacity(0.06),
                                    lineWidth: 1
                                )
                        )
                }
                .buttonStyle(SubtlePressStyle())

                ForEach(ExpenseCategory.allCases) { cat in
                    let isSelected = selectedFilterCategory == cat
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            if selectedFilterCategory == cat {
                                selectedFilterCategory = nil
                            } else {
                                selectedFilterCategory = cat
                            }
                        }
                        HapticsManager.shared.lightFeedback()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: cat.iconName)
                                .font(.system(size: 12, weight: .bold))
                            Text(cat.rawValue)
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                        }
                        .padding(.horizontal, 13)
                        .padding(.vertical, 8)
                        .background(
                            isSelected
                                ? cat.color
                                : Color(uiColor: .secondarySystemGroupedBackground)
                        )
                        .foregroundColor(isSelected ? .white : .secondary)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .strokeBorder(
                                    isSelected ? Color.clear : Color.primary.opacity(0.06),
                                    lineWidth: 1
                                )
                        )
                    }
                    .buttonStyle(SubtlePressStyle())
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Empty State View
    private var emptyStateView: some View {
        VStack(spacing: 18) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.12))
                    .frame(width: 100, height: 100)
                Image(systemName: "creditcard.and.123")
                    .font(.system(size: 46))
                    .foregroundColor(.blue)
            }

            VStack(spacing: 6) {
                Text("No Expenses Recorded")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)

                Text("Tap the button below or double-tap the back of your iPhone to swiftly capture an expense.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 36)
            }

            Button {
                showingAddExpense = true
                HapticsManager.shared.lightFeedback()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                    Text("Add First Expense")
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 22)
                .padding(.vertical, 12)
                .background(Color.blue)
                .clipShape(Capsule())
            }
            .buttonStyle(BouncyButtonStyle())
            .padding(.top, 4)

            Spacer()
            Spacer()
        }
    }
}

// MARK: - Edit Expense Sheet
struct EditExpenseSheet: View {
    @ObservedObject var store: ExpenseStore
    let expense: Expense
    @Environment(\.dismiss) private var dismiss

    @State private var amountString: String
    @State private var selectedCategory: ExpenseCategory
    @State private var date: Date
    @State private var note: String

    init(store: ExpenseStore, expense: Expense) {
        self.store = store
        self.expense = expense
        _amountString = State(initialValue: NSDecimalNumber(decimal: expense.amount).stringValue)
        _selectedCategory = State(initialValue: expense.category)
        _date = State(initialValue: expense.date)
        _note = State(initialValue: expense.note ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text("₹")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                        TextField("0", text: $amountString)
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .keyboardType(.decimalPad)
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Amount")
                }

                Section("Category") {
                    Picker("Category", selection: $selectedCategory) {
                        ForEach(ExpenseCategory.allCases) { cat in
                            Label(cat.rawValue, systemImage: cat.iconName).tag(cat)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section("Details") {
                    DatePicker("Date & Time", selection: $date)
                    HStack {
                        Image(systemName: "note.text")
                            .foregroundColor(.secondary)
                        TextField("Note (optional)", text: $note)
                    }
                }

                Section {
                    Button(role: .destructive) {
                        HapticsManager.shared.warningFeedback()
                        store.deleteExpense(id: expense.id)
                        dismiss()
                    } label: {
                        HStack {
                            Spacer()
                            Image(systemName: "trash")
                            Text("Delete Expense")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Edit Expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if let dec = CurrencyHelper.shared.parseDecimal(from: amountString), dec > 0 {
                            HapticsManager.shared.successFeedback()
                            var updated = expense
                            updated.amount = dec
                            updated.category = selectedCategory
                            updated.date = date
                            updated.note = note.isEmpty ? nil : note
                            store.updateExpense(updated)
                            dismiss()
                        }
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}
