import SwiftUI

struct OutlookBudgetsView: View {
    @ObservedObject var expenseStore: ExpenseStore
    @ObservedObject var budgetStore: BudgetStore
    @ObservedObject var goalStore: GoalStore

    @State private var showingAddBill = false
    @State private var showingEditBudget = false
    @State private var selectedBudgetCategory: ExpenseCategory = .food
    @State private var budgetInputString = ""
    @State private var incomeInputString = ""
    @State private var essentialsInputString = ""

    private var currentMonthInterval: DateInterval {
        Calendar.current.dateInterval(of: .month, for: Date()) ?? DateInterval(start: Date(), duration: 86400 * 30)
    }

    private var currentMonthCategoryTotals: [ExpenseCategory: Decimal] {
        expenseStore.categoryTotals(for: currentMonthInterval)
    }

    private var totalMonthlyGoalPace: Decimal {
        goalStore.goals.filter { !$0.isCompleted }.reduce(Decimal.zero) { $0 + ($1.currentDailyPace() * 30) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Month over Month Comparison Card
                    monthOverMonthCard

                    // Category Spending Breakdown
                    categoryBreakdownCard

                    // Category Budgets & Headroom
                    categoryBudgetsSection

                    // Recurring Bills Section
                    recurringBillsSection

                    // 3-Month Outlook Projections
                    threeMonthOutlookSection

                    // Financial Disclaimer
                    financialDisclaimer
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            }
            .navigationTitle("Outlook & Budgets")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            showingAddBill = true
                        } label: {
                            Label("Add Recurring Bill", systemImage: "doc.text.fill")
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 22))
                    }
                }
            }
            .sheet(isPresented: $showingAddBill) {
                AddRecurringBillSheet(budgetStore: budgetStore)
            }
            .sheet(isPresented: $showingEditBudget) {
                SetBudgetSheet(
                    budgetStore: budgetStore,
                    category: selectedBudgetCategory,
                    currentLimit: budgetStore.budgets[selectedBudgetCategory] ?? .zero
                )
            }
            .onAppear {
                incomeInputString = NSDecimalNumber(decimal: budgetStore.monthlyIncome).stringValue
                essentialsInputString = NSDecimalNumber(decimal: budgetStore.essentialsEstimate).stringValue
            }
        }
    }

    // MARK: - Month Over Month Comparison
    private var monthOverMonthCard: some View {
        let current = expenseStore.thisMonthTotal
        let prior = expenseStore.priorMonthTotal

        let diff = current - prior
        let isHigher = diff > 0

        return VStack(alignment: .leading, spacing: 12) {
            Text("Month-over-Month Comparison")
                .font(.headline)
                .foregroundColor(.primary)

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("This Month")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(CurrencyHelper.shared.format(current))
                        .font(.system(.title3, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                }

                Spacer()

                VStack(alignment: .center, spacing: 2) {
                    Text("Last Month")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(CurrencyHelper.shared.format(prior))
                        .font(.system(.title3, design: .rounded))
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("Change")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    if prior == 0 {
                        Text("—")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    } else {
                        Text("\(isHigher ? "+" : "")\(CurrencyHelper.shared.format(diff))")
                            .font(.system(.subheadline, design: .rounded))
                            .fontWeight(.bold)
                            .foregroundColor(isHigher ? .orange : .green)
                    }
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
    }

    // MARK: - Category Breakdown Card
    private var categoryBreakdownCard: some View {
        let totals = currentMonthCategoryTotals
        let totalSpend = expenseStore.thisMonthTotal

        return VStack(alignment: .leading, spacing: 12) {
            Text("This Month's Spending by Category")
                .font(.headline)
                .foregroundColor(.primary)

            if totals.isEmpty {
                Text("No spending recorded this month.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
            } else {
                ForEach(ExpenseCategory.allCases) { cat in
                    let spent = totals[cat] ?? .zero
                    if spent > 0 {
                        let fraction = totalSpend > 0 ? NSDecimalNumber(decimal: spent / totalSpend).doubleValue : 0.0

                        VStack(spacing: 4) {
                            HStack {
                                Label(cat.rawValue, systemImage: cat.iconName)
                                    .font(.subheadline)
                                    .foregroundColor(.primary)
                                Spacer()
                                Text(CurrencyHelper.shared.format(spent))
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                                Text("(\(Int(fraction * 100))%)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }

                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(Color(.tertiarySystemFill)).frame(height: 6)
                                    Capsule().fill(cat.color).frame(width: max(0, min(geo.size.width, geo.size.width * CGFloat(fraction))), height: 6)
                                }
                            }
                            .frame(height: 6)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
    }

    // MARK: - Category Budgets & Headroom
    private var categoryBudgetsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Category Budgets")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
                Menu("Set Budget") {
                    ForEach(ExpenseCategory.allCases) { cat in
                        Button(cat.rawValue) {
                            selectedBudgetCategory = cat
                            showingEditBudget = true
                        }
                    }
                }
                .font(.subheadline)
            }

            if budgetStore.budgets.isEmpty {
                Text("No budgets set. Tap 'Set Budget' above to establish limits and spot headroom.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 4)
            } else {
                let rooms = budgetStore.budgetRoom(categorySpending: currentMonthCategoryTotals)
                ForEach(rooms, id: \.category) { item in
                    VStack(spacing: 6) {
                        HStack {
                            Label(item.category.rawValue, systemImage: item.category.iconName)
                                .font(.subheadline)
                            Spacer()
                            Text("\(CurrencyHelper.shared.format(item.spent)) / \(CurrencyHelper.shared.format(item.limit))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        let fraction = item.limit > 0 ? min(1.0, NSDecimalNumber(decimal: item.spent / item.limit).doubleValue) : 0
                        let isOver = item.spent > item.limit

                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color(.tertiarySystemFill)).frame(height: 6)
                                Capsule()
                                    .fill(isOver ? Color.red : Color.blue)
                                    .frame(width: max(0, min(geo.size.width, geo.size.width * CGFloat(fraction))), height: 6)
                            }
                        }
                        .frame(height: 6)

                        HStack {
                            Text(isOver ? "Over budget" : "Headroom remaining")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(isOver ? "-\(CurrencyHelper.shared.format(item.spent - item.limit))" : CurrencyHelper.shared.format(item.room))
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(isOver ? .red : .green)
                        }
                    }
                    .padding(12)
                    .background(Color(.tertiarySystemBackground))
                    .cornerRadius(12)
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
    }

    // MARK: - Recurring Bills
    private var recurringBillsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recurring Bills & Commitments")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
                Button {
                    showingAddBill = true
                } label: {
                    Text("+ Add")
                        .font(.subheadline)
                }
            }

            if budgetStore.recurringBills.isEmpty {
                Text("No recurring bills added yet (e.g. WiFi, Rent, Subscriptions).")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 4)
            } else {
                ForEach(budgetStore.recurringBills) { bill in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(bill.title)
                                .font(.body)
                                .fontWeight(.medium)
                            Text("Due day \(bill.dueDayOfMonth) each month • \(bill.category.rawValue)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Text(CurrencyHelper.shared.format(bill.amount))
                            .font(.system(.body, design: .rounded))
                            .fontWeight(.semibold)

                        Button {
                            budgetStore.deleteRecurringBill(id: bill.id)
                        } label: {
                            Image(systemName: "trash")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(6)
                        }
                        .accessibilityLabel("Delete bill")
                    }
                    .padding(10)
                    .background(Color(.tertiarySystemBackground))
                    .cornerRadius(10)
                }

                HStack {
                    Text("Total Monthly Bills")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Spacer()
                    Text(CurrencyHelper.shared.format(budgetStore.totalMonthlyBills))
                        .font(.headline)
                        .fontWeight(.bold)
                }
                .padding(.top, 4)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
    }

    // MARK: - Three-Month Outlook Section
    private var threeMonthOutlookSection: some View {
        let outlooks = budgetStore.generateThreeMonthOutlook(goalsTotalMonthlyPace: totalMonthlyGoalPace)

        return VStack(alignment: .leading, spacing: 12) {
            Text("3-Month Cashflow Outlook")
                .font(.headline)
                .foregroundColor(.primary)

            Text("Projections based on your stated monthly income, essential expenses, recurring bills, and active goal paces.")
                .font(.caption)
                .foregroundColor(.secondary)

            // Income & Essentials Inputs
            VStack(spacing: 8) {
                HStack {
                    Text("Est. Monthly Income")
                        .font(.subheadline)
                    Spacer()
                    TextField("₹0", text: $incomeInputString)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 140)
                        .onChange(of: incomeInputString) { val in
                            if let dec = CurrencyHelper.shared.parseDecimal(from: val) {
                                budgetStore.updateMonthlyIncome(dec)
                            }
                        }
                }

                HStack {
                    Text("Est. Essentials (Rent/Food)")
                        .font(.subheadline)
                    Spacer()
                    TextField("₹0", text: $essentialsInputString)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 140)
                        .onChange(of: essentialsInputString) { val in
                            if let dec = CurrencyHelper.shared.parseDecimal(from: val) {
                                budgetStore.updateEssentialsEstimate(dec)
                            }
                        }
                }
            }
            .padding(12)
            .background(Color(.tertiarySystemBackground))
            .cornerRadius(12)

            // Monthly Outlook Cards
            ForEach(outlooks) { outlook in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(outlook.monthName)
                            .font(.headline)
                        Spacer()
                        let net = outlook.projectedNetBalance
                        Text(CurrencyHelper.shared.format(net))
                            .font(.system(.headline, design: .rounded))
                            .fontWeight(.bold)
                            .foregroundColor(net >= 0 ? .green : .red)
                    }

                    HStack {
                        Text("Inflow: \(CurrencyHelper.shared.format(outlook.projectedIncome))")
                        Spacer()
                        Text("Outflow: \(CurrencyHelper.shared.format(outlook.totalProjectedOutflow))")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)

                    Text("Includes \(CurrencyHelper.shared.format(outlook.savingsGoalsAllocation)) toward active savings goals.")
                        .font(.caption2)
                        .foregroundColor(.blue)
                }
                .padding(12)
                .background(Color(.tertiarySystemBackground))
                .cornerRadius(12)
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
    }

    private var financialDisclaimer: some View {
        Text("Projections, daily paces, and budget room are estimates based entirely on local user entries. They do not constitute certified financial or investment advice.")
            .font(.caption2)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
    }
}

// MARK: - Add Recurring Bill Sheet
struct AddRecurringBillSheet: View {
    @ObservedObject var budgetStore: BudgetStore
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var amountString = ""
    @State private var dueDay = 1
    @State private var category: ExpenseCategory = .bills

    var body: some View {
        NavigationStack {
            Form {
                Section("Bill Details") {
                    TextField("Title (e.g. WiFi, Rent, Phone)", text: $title)
                    HStack {
                        Text("₹")
                        TextField("Amount", text: $amountString)
                            .keyboardType(.decimalPad)
                    }
                    Picker("Category", selection: $category) {
                        ForEach(ExpenseCategory.allCases) { cat in
                            Text(cat.rawValue).tag(cat)
                        }
                    }
                    Stepper("Due Day of Month: \(dueDay)", value: $dueDay, in: 1...31)
                }
            }
            .navigationTitle("Add Recurring Bill")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if let amount = CurrencyHelper.shared.parseDecimal(from: amountString), !title.isEmpty {
                            budgetStore.addRecurringBill(title: title, amount: amount, dueDay: dueDay, category: category)
                            dismiss()
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Set Budget Sheet
struct SetBudgetSheet: View {
    @ObservedObject var budgetStore: BudgetStore
    let category: ExpenseCategory
    let currentLimit: Decimal
    @Environment(\.dismiss) private var dismiss

    @State private var limitString: String

    init(budgetStore: BudgetStore, category: ExpenseCategory, currentLimit: Decimal) {
        self.budgetStore = budgetStore
        self.category = category
        self.currentLimit = currentLimit
        _limitString = State(initialValue: currentLimit > 0 ? NSDecimalNumber(decimal: currentLimit).stringValue : "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Monthly Budget for \(category.rawValue)") {
                    HStack {
                        Text("₹")
                        TextField("0", text: $limitString)
                            .keyboardType(.decimalPad)
                    }
                }

                if currentLimit > 0 {
                    Section {
                        Button(role: .destructive) {
                            budgetStore.setBudget(for: category, limit: .zero)
                            dismiss()
                        } label: {
                            Text("Remove Budget")
                        }
                    }
                }
            }
            .navigationTitle("Set Category Budget")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let amount = CurrencyHelper.shared.parseDecimal(from: limitString) ?? .zero
                        budgetStore.setBudget(for: category, limit: amount)
                        dismiss()
                    }
                }
            }
        }
    }
}
