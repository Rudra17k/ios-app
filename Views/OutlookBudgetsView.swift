import SwiftUI

struct OutlookBudgetsView: View {
    @ObservedObject var expenseStore: ExpenseStore
    @ObservedObject var budgetStore: BudgetStore
    @ObservedObject var goalStore: GoalStore
    @Environment(\.colorScheme) private var colorScheme

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
            ZStack {
                Color(uiColor: .systemGroupedBackground)
                    .ignoresSafeArea()

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
            }
            .navigationTitle("Outlook & Budgets")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            showingAddBill = true
                            HapticsManager.shared.lightFeedback()
                        } label: {
                            Label("Add Recurring Bill", systemImage: "doc.text.fill")
                        }
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Color.blue)
                            .clipShape(Circle())
                    }
                    .buttonStyle(BouncyButtonStyle(scaleAmount: 0.88))
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

        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.left.arrow.right.circle.fill")
                        .foregroundColor(.blue)
                        .font(.system(size: 14))
                    Text("MONTH-OVER-MONTH")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(.secondary)
                }

                Spacer()

                if prior > 0 {
                    let percent = NSDecimalNumber(decimal: (diff / prior) * 100).intValue
                    HStack(spacing: 4) {
                        Image(systemName: isHigher ? "arrow.up.right" : "arrow.down.right")
                            .font(.system(size: 10, weight: .bold))
                        Text("\(abs(percent))%")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(isHigher ? .orange : .green)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background((isHigher ? Color.orange : Color.green).opacity(0.14))
                    .clipShape(Capsule())
                }
            }

            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("This Month")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(CurrencyHelper.shared.format(current))
                        .font(.system(.title3, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                }

                Spacer()

                VStack(alignment: .center, spacing: 3) {
                    Text("Last Month")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(CurrencyHelper.shared.format(prior))
                        .font(.system(.title3, design: .rounded))
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 3) {
                    Text("Difference")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    if prior == 0 {
                        Text("—")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    } else {
                        Text("\(isHigher ? "+" : "")\(CurrencyHelper.shared.format(diff))")
                            .font(.system(.title3, design: .rounded))
                            .fontWeight(.bold)
                            .foregroundColor(isHigher ? .orange : .green)
                    }
                }
            }
        }
        .padding(18)
        .glassCard(cornerRadius: 22, strokeOpacity: 0.1, shadowRadius: 10)
    }

    // MARK: - Category Breakdown Card
    private var categoryBreakdownCard: some View {
        let totals = currentMonthCategoryTotals
        let totalSpend = expenseStore.thisMonthTotal

        return VStack(alignment: .leading, spacing: 14) {
            Text("SPENDING BY CATEGORY")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(.secondary)
                .padding(.leading, 2)

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

                        VStack(spacing: 6) {
                            HStack {
                                HStack(spacing: 8) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .fill(cat.color.opacity(0.18))
                                            .frame(width: 26, height: 26)
                                        Image(systemName: cat.iconName)
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundColor(cat.color)
                                    }
                                    Text(cat.rawValue)
                                        .font(.system(.body, design: .rounded))
                                        .fontWeight(.semibold)
                                        .foregroundColor(.primary)
                                }

                                Spacer()

                                Text(CurrencyHelper.shared.format(spent))
                                    .font(.system(.body, design: .rounded))
                                    .fontWeight(.bold)
                                    .foregroundColor(.primary)

                                Text("(\(Int(fraction * 100))%)")
                                    .font(.system(size: 11, weight: .medium, design: .rounded))
                                    .foregroundColor(.secondary)
                            }

                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(Color(uiColor: .tertiarySystemFill)).frame(height: 8)
                                    Capsule()
                                        .fill(cat.color)
                                        .frame(width: max(6, min(geo.size.width, geo.size.width * CGFloat(fraction))), height: 8)
                                        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: fraction)
                                }
                            }
                            .frame(height: 8)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .padding(18)
        .glassCard(cornerRadius: 22, strokeOpacity: 0.1, shadowRadius: 10)
    }

    // MARK: - Category Budgets & Headroom
    private var categoryBudgetsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("BUDGET LIMITS & HEADROOM")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(.secondary)
                    .padding(.leading, 2)

                Spacer()

                Menu {
                    ForEach(ExpenseCategory.allCases) { cat in
                        Button {
                            selectedBudgetCategory = cat
                            showingEditBudget = true
                            HapticsManager.shared.lightFeedback()
                        } label: {
                            Label(cat.rawValue, systemImage: cat.iconName)
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                        Text("Set Limit")
                    }
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(.blue)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.12))
                    .clipShape(Capsule())
                }
            }

            if budgetStore.budgets.isEmpty {
                Text("No budgets set yet. Tap 'Set Limit' above to prevent overspending and calculate unspent headroom for your goals.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 4)
            } else {
                let rooms = budgetStore.budgetRoom(categorySpending: currentMonthCategoryTotals)
                ForEach(rooms, id: \.category) { item in
                    VStack(spacing: 8) {
                        HStack {
                            HStack(spacing: 6) {
                                Image(systemName: item.category.iconName)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(item.category.color)
                                Text(item.category.rawValue)
                                    .font(.system(.body, design: .rounded))
                                    .fontWeight(.semibold)
                            }

                            Spacer()

                            Text("\(CurrencyHelper.shared.format(item.spent)) / \(CurrencyHelper.shared.format(item.limit))")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundColor(.secondary)
                        }

                        let fraction = item.limit > 0 ? min(1.0, NSDecimalNumber(decimal: item.spent / item.limit).doubleValue) : 0
                        let isOver = item.spent > item.limit

                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color(uiColor: .tertiarySystemFill)).frame(height: 8)
                                Capsule()
                                    .fill(isOver ? Color.red : (fraction > 0.8 ? Color.orange : Color.blue))
                                    .frame(width: max(6, min(geo.size.width, geo.size.width * CGFloat(fraction))), height: 8)
                                    .animation(.spring(response: 0.35, dampingFraction: 0.75), value: fraction)
                            }
                        }
                        .frame(height: 8)

                        HStack {
                            Text(isOver ? "Over budget" : "Headroom remaining")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(isOver ? "-\(CurrencyHelper.shared.format(item.spent - item.limit))" : CurrencyHelper.shared.format(item.room))
                                .font(.system(.caption, design: .rounded))
                                .fontWeight(.bold)
                                .foregroundColor(isOver ? .red : .green)
                        }
                    }
                    .padding(14)
                    .glassCard(cornerRadius: 16, strokeOpacity: 0.08, shadowRadius: 4)
                }
            }
        }
        .padding(18)
        .glassCard(cornerRadius: 22, strokeOpacity: 0.1, shadowRadius: 10)
    }

    // MARK: - Recurring Bills
    private var recurringBillsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("RECURRING BILLS")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(.secondary)
                    .padding(.leading, 2)

                Spacer()

                Button {
                    showingAddBill = true
                    HapticsManager.shared.lightFeedback()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                        Text("Add Bill")
                    }
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(.blue)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.12))
                    .clipShape(Capsule())
                }
                .buttonStyle(BouncyButtonStyle(scaleAmount: 0.94))
            }

            if budgetStore.recurringBills.isEmpty {
                Text("No recurring bills added yet (e.g. WiFi, Rent, Subscriptions).")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 4)
            } else {
                ForEach(budgetStore.recurringBills) { bill in
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(bill.category.color.opacity(0.18))
                                .frame(width: 36, height: 36)
                            Image(systemName: bill.category.iconName)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(bill.category.color)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(bill.title)
                                .font(.system(.body, design: .rounded))
                                .fontWeight(.semibold)
                            Text("Due day \(bill.dueDayOfMonth) • \(bill.category.rawValue)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Text(CurrencyHelper.shared.format(bill.amount))
                            .font(.system(.headline, design: .rounded))
                            .fontWeight(.bold)

                        Button {
                            HapticsManager.shared.warningFeedback()
                            budgetStore.deleteRecurringBill(id: bill.id)
                        } label: {
                            Image(systemName: "trash")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(6)
                        }
                        .buttonStyle(BouncyButtonStyle(scaleAmount: 0.88))
                        .accessibilityLabel("Delete bill")
                    }
                    .padding(12)
                    .glassCard(cornerRadius: 16, strokeOpacity: 0.08, shadowRadius: 4)
                }

                Divider()
                    .opacity(0.6)

                HStack {
                    Text("Total Committed Monthly")
                        .font(.system(.subheadline, design: .rounded))
                        .fontWeight(.semibold)
                    Spacer()
                    Text(CurrencyHelper.shared.format(budgetStore.totalMonthlyBills))
                        .font(.system(.title3, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                }
            }
        }
        .padding(18)
        .glassCard(cornerRadius: 22, strokeOpacity: 0.1, shadowRadius: 10)
    }

    // MARK: - Three-Month Outlook Section
    private var threeMonthOutlookSection: some View {
        let outlooks = budgetStore.generateThreeMonthOutlook(goalsTotalMonthlyPace: totalMonthlyGoalPace)

        return VStack(alignment: .leading, spacing: 14) {
            Text("3-MONTH CASHFLOW OUTLOOK")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(.secondary)
                .padding(.leading, 2)

            Text("Forward-looking projections combining your monthly income, essential baseline, fixed bills, and active goal paces.")
                .font(.system(size: 12, design: .rounded))
                .foregroundColor(.secondary)

            // Income & Essentials Inputs Card
            VStack(spacing: 12) {
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.down.left.circle.fill")
                            .foregroundColor(.green)
                        Text("Monthly Income")
                            .font(.system(.subheadline, design: .rounded))
                            .fontWeight(.semibold)
                    }
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
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.up.right.circle.fill")
                            .foregroundColor(.orange)
                        Text("Estimated Essentials")
                            .font(.system(.subheadline, design: .rounded))
                            .fontWeight(.semibold)
                    }
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
            .padding(14)
            .glassCard(cornerRadius: 16, strokeOpacity: 0.08, shadowRadius: 4)

            // Monthly Outlook Cards
            ForEach(outlooks) { outlook in
                let net = outlook.projectedNetBalance

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(outlook.monthName)
                            .font(.system(.headline, design: .rounded))
                            .fontWeight(.bold)
                        Spacer()
                        Text(CurrencyHelper.shared.format(net))
                            .font(.system(.title3, design: .rounded))
                            .fontWeight(.bold)
                            .foregroundColor(net >= 0 ? .green : .red)
                    }

                    HStack {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.down.left")
                                .font(.system(size: 10, weight: .bold))
                            Text("Inflow: \(CurrencyHelper.shared.format(outlook.projectedIncome))")
                        }
                        Spacer()
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 10, weight: .bold))
                            Text("Outflow: \(CurrencyHelper.shared.format(outlook.totalProjectedOutflow))")
                        }
                    }
                    .font(.system(size: 12, design: .rounded))
                    .foregroundColor(.secondary)

                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 10))
                        Text("Includes \(CurrencyHelper.shared.format(outlook.savingsGoalsAllocation)) reserved for goals")
                    }
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(.blue)
                }
                .padding(14)
                .glassCard(cornerRadius: 16, strokeOpacity: 0.08, shadowRadius: 4)
            }
        }
        .padding(18)
        .glassCard(cornerRadius: 22, strokeOpacity: 0.1, shadowRadius: 10)
    }

    private var financialDisclaimer: some View {
        Text("Projections, daily paces, and budget headroom are estimates calculated locally on-device based on your entries. They do not constitute financial advice.")
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
                Section {
                    HStack {
                        Text("₹")
                            .font(.title2)
                            .bold()
                            .foregroundColor(.blue)
                        TextField("0", text: $amountString)
                            .font(.title2)
                            .keyboardType(.decimalPad)
                    }
                } header: {
                    Text("Bill Amount")
                }

                Section("Bill Details") {
                    TextField("Title (e.g. WiFi, Rent, iCloud)", text: $title)
                    Picker("Category", selection: $category) {
                        ForEach(ExpenseCategory.allCases) { cat in
                            Label(cat.rawValue, systemImage: cat.iconName).tag(cat)
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
                            HapticsManager.shared.successFeedback()
                            budgetStore.addRecurringBill(title: title, amount: amount, dueDay: dueDay, category: category)
                            dismiss()
                        }
                    }
                    .fontWeight(.semibold)
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
                Section {
                    HStack {
                        Text("₹")
                            .font(.title2)
                            .bold()
                            .foregroundColor(category.color)
                        TextField("0", text: $limitString)
                            .font(.title2)
                            .keyboardType(.decimalPad)
                    }
                } header: {
                    Text("Monthly Limit for \(category.rawValue)")
                }

                if currentLimit > 0 {
                    Section {
                        Button(role: .destructive) {
                            HapticsManager.shared.warningFeedback()
                            budgetStore.setBudget(for: category, limit: .zero)
                            dismiss()
                        } label: {
                            HStack {
                                Spacer()
                                Image(systemName: "trash")
                                Text("Remove Limit")
                                    .fontWeight(.semibold)
                                Spacer()
                            }
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
                        HapticsManager.shared.successFeedback()
                        let amount = CurrencyHelper.shared.parseDecimal(from: limitString) ?? .zero
                        budgetStore.setBudget(for: category, limit: amount)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}
