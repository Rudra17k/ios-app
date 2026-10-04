import SwiftUI

struct HomeView: View {
    @ObservedObject var store: ExpenseStore
    @EnvironmentObject private var appState: AppState

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

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // In-App Confirmation Toast (Stage 2)
                if showUndoBanner, let expense = undoBannerExpense {
                    undoConfirmationBanner(for: expense)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                // Monthly Summary Card
                monthlySummaryCard
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 10)

                // Category Filter Pills
                categoryFilterScrollView
                    .padding(.bottom, 8)

                // Expenses List or Empty State
                if filteredExpenses.isEmpty {
                    emptyStateView
                } else {
                    List {
                        Section {
                            ForEach(filteredExpenses) { expense in
                                Button {
                                    editingExpense = expense
                                } label: {
                                    ExpenseRowView(expense: expense)
                                }
                                .buttonStyle(.plain)
                            }
                            .onDelete { offsets in
                                store.deleteExpenses(at: offsets, from: filteredExpenses)
                            }
                        } header: {
                            HStack {
                                Text("Recent Entries")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Spacer()
                                Text("\(filteredExpenses.count) \(filteredExpenses.count == 1 ? "entry" : "entries")")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .textCase(nil)
                            .padding(.vertical, 4)
                        }
                    }
                    .listStyle(.insetGrouped)
                    .safeAreaInset(edge: .bottom) {
                        Color.clear.frame(height: 72)
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search note, category, or amount")
            .navigationTitle("Expenses")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddExpense = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.blue)
                    }
                    .accessibilityLabel("Add Expense")
                }
            }
            .sheet(isPresented: $showingAddExpense) {
                QuickAddView(store: store)
            }
            .sheet(item: $editingExpense) { expense in
                EditExpenseSheet(store: store, expense: expense)
            }
            .overlay(alignment: .bottom) {
                // Floating Quick-Add CTA for one-thumb reachability
                Button {
                    showingAddExpense = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus")
                            .font(.headline)
                        Text("Add Expense")
                            .font(.headline)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                    .background(Color.blue)
                    .clipShape(Capsule())
                    .shadow(color: Color.blue.opacity(0.35), radius: 8, x: 0, y: 4)
                }
                .padding(.bottom, 16)
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
                if let exp = newExpense {
                    undoBannerExpense = exp
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        showUndoBanner = true
                    }
                    // Auto-hide after 5 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                        withAnimation {
                            if self.undoBannerExpense?.id == exp.id {
                                self.showUndoBanner = false
                            }
                        }
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
        HStack {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
            Text("Logged \(CurrencyHelper.shared.format(expense.amount)) in \(expense.category.rawValue)")
                .font(.footnote)
                .fontWeight(.medium)
                .lineLimit(1)

            Spacer()

            Button("Undo") {
                store.undoLastAdded()
                HapticsManager.shared.lightFeedback()
                withAnimation {
                    showUndoBanner = false
                }
            }
            .font(.footnote)
            .fontWeight(.bold)
            .foregroundColor(.blue)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .padding(.horizontal, 16)
        .padding(.top, 4)
    }

    // MARK: - Monthly Summary Card
    private var monthlySummaryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("This Month's Spending")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                Image(systemName: "calendar")
                    .foregroundColor(.secondary)
            }

            Text(CurrencyHelper.shared.format(store.thisMonthTotal))
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
        .padding(18)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(18)
    }

    // MARK: - Filter Pills
    private var categoryFilterScrollView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Button {
                    selectedFilterCategory = nil
                    HapticsManager.shared.lightFeedback()
                } label: {
                    Text("All")
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(selectedFilterCategory == nil ? Color.blue : Color(.secondarySystemBackground))
                        .foregroundColor(selectedFilterCategory == nil ? .white : .primary)
                        .clipShape(Capsule())
                }

                ForEach(ExpenseCategory.allCases) { cat in
                    Button {
                        if selectedFilterCategory == cat {
                            selectedFilterCategory = nil
                        } else {
                            selectedFilterCategory = cat
                        }
                        HapticsManager.shared.lightFeedback()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: cat.iconName)
                                .font(.caption2)
                            Text(cat.rawValue)
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(selectedFilterCategory == cat ? cat.color : Color(.secondarySystemBackground))
                        .foregroundColor(selectedFilterCategory == cat ? .white : .primary)
                        .clipShape(Capsule())
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "creditcard.and.123")
                .font(.system(size: 60))
                .foregroundColor(.secondary.opacity(0.6))

            Text("No Expenses Recorded")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.primary)

            Text("Tap the '+' button below or use Back Tap on your iPhone to quickly record an expense.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

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
                Section("Amount") {
                    HStack {
                        Text("₹")
                            .font(.title3)
                            .bold()
                        TextField("0", text: $amountString)
                            .font(.title3)
                            .keyboardType(.decimalPad)
                    }
                }

                Section("Category") {
                    Picker("Category", selection: $selectedCategory) {
                        ForEach(ExpenseCategory.allCases) { cat in
                            Text(cat.rawValue).tag(cat)
                        }
                    }
                }

                Section("Details") {
                    DatePicker("Date & Time", selection: $date)
                    TextField("Note", text: $note)
                }

                Section {
                    Button(role: .destructive) {
                        store.deleteExpense(id: expense.id)
                        dismiss()
                    } label: {
                        Text("Delete Expense")
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
                            var updated = expense
                            updated.amount = dec
                            updated.category = selectedCategory
                            updated.date = date
                            updated.note = note.isEmpty ? nil : note
                            store.updateExpense(updated)
                            dismiss()
                        }
                    }
                }
            }
        }
    }
}
