import Foundation
import Combine

final class BudgetStore: ObservableObject {
    @Published var budgets: [ExpenseCategory: Decimal] = [:]
    @Published var recurringBills: [RecurringBill] = []
    @Published var monthlyIncome: Decimal = .zero
    @Published var essentialsEstimate: Decimal = .zero

    private let budgetsFilename = "budgets.json"
    private let billsFilename = "bills.json"

    init() {
        loadData()
    }

    private func fileURL(for filename: String) -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0].appendingPathComponent(filename)
    }

    func loadData() {
        // Load monthly income & essentials
        let incomeStr = UserDefaults.standard.string(forKey: "monthlyIncome") ?? "0"
        let essentialsStr = UserDefaults.standard.string(forKey: "essentialsEstimate") ?? "0"
        self.monthlyIncome = CurrencyHelper.shared.parseDecimal(from: incomeStr) ?? .zero
        self.essentialsEstimate = CurrencyHelper.shared.parseDecimal(from: essentialsStr) ?? .zero

        // Load budgets
        let budgetsUrl = fileURL(for: budgetsFilename)
        if FileManager.default.fileExists(atPath: budgetsUrl.path) {
            do {
                let data = try Data(contentsOf: budgetsUrl)
                let items = try JSONDecoder().decode([CategoryBudget].self, from: data)
                var map: [ExpenseCategory: Decimal] = [:]
                for item in items {
                    map[item.category] = item.monthlyLimit
                }
                self.budgets = map
            } catch {
                print("Failed to load budgets: \(error.localizedDescription)")
            }
        }

        // Load recurring bills
        let billsUrl = fileURL(for: billsFilename)
        if FileManager.default.fileExists(atPath: billsUrl.path) {
            do {
                let data = try Data(contentsOf: billsUrl)
                let decoded = try JSONDecoder().decode([RecurringBill].self, from: data)
                self.recurringBills = decoded
            } catch {
                print("Failed to load recurring bills: \(error.localizedDescription)")
            }
        }
    }

    func saveBudgets() {
        let list = budgets.map { CategoryBudget(category: $0.key, monthlyLimit: $0.value) }
        do {
            let data = try JSONEncoder().encode(list)
            try data.write(to: fileURL(for: budgetsFilename), options: [.atomicWrite, .completeFileProtection])
        } catch {
            print("Failed to save budgets: \(error.localizedDescription)")
        }
    }

    func saveBills() {
        do {
            let data = try JSONEncoder().encode(recurringBills)
            try data.write(to: fileURL(for: billsFilename), options: [.atomicWrite, .completeFileProtection])
        } catch {
            print("Failed to save bills: \(error.localizedDescription)")
        }
    }

    func setBudget(for category: ExpenseCategory, limit: Decimal) {
        if limit <= 0 {
            budgets.removeValue(forKey: category)
        } else {
            budgets[category] = limit
        }
        saveBudgets()
    }

    func addRecurringBill(title: String, amount: Decimal, dueDay: Int, category: ExpenseCategory = .bills) {
        let bill = RecurringBill(title: title, amount: amount, dueDayOfMonth: dueDay, category: category)
        recurringBills.append(bill)
        saveBills()
    }

    func deleteRecurringBill(id: UUID) {
        recurringBills.removeAll { $0.id == id }
        saveBills()
    }

    func updateMonthlyIncome(_ income: Decimal) {
        self.monthlyIncome = income
        UserDefaults.standard.set(NSDecimalNumber(decimal: income).stringValue, forKey: "monthlyIncome")
    }

    func updateEssentialsEstimate(_ essentials: Decimal) {
        self.essentialsEstimate = essentials
        UserDefaults.standard.set(NSDecimalNumber(decimal: essentials).stringValue, forKey: "essentialsEstimate")
    }

    var totalMonthlyBills: Decimal {
        recurringBills.reduce(Decimal.zero) { $0 + $1.amount }
    }

    /// Evaluates budget room for each budgeted category given current month's spending
    func budgetRoom(categorySpending: [ExpenseCategory: Decimal]) -> [(category: ExpenseCategory, limit: Decimal, spent: Decimal, room: Decimal)] {
        var results: [(category: ExpenseCategory, limit: Decimal, spent: Decimal, room: Decimal)] = []
        for (category, limit) in budgets {
            let spent = categorySpending[category] ?? .zero
            let room = limit - spent
            results.append((category: category, limit: limit, spent: spent, room: room))
        }
        return results.sorted { $0.category.rawValue < $1.category.rawValue }
    }

    /// Generates 3-month outlook projections based on user-entered income, essentials, recurring bills, and active goals
    func generateThreeMonthOutlook(goalsTotalMonthlyPace: Decimal) -> [MonthOutlook] {
        let calendar = Calendar.current
        let today = Date()
        var results: [MonthOutlook] = []

        let monthFormatter = DateFormatter()
        monthFormatter.dateFormat = "MMMM yyyy"

        let totalOutflow = essentialsEstimate + totalMonthlyBills + goalsTotalMonthlyPace
        let projectedNet = monthlyIncome - totalOutflow

        for i in 0..<3 {
            guard let monthDate = calendar.date(byAdding: .month, value: i, to: today) else { continue }
            let monthName = monthFormatter.string(from: monthDate)

            let outlook = MonthOutlook(
                monthName: monthName,
                monthDate: monthDate,
                projectedIncome: monthlyIncome,
                estimatedEssentials: essentialsEstimate,
                recurringBills: totalMonthlyBills,
                savingsGoalsAllocation: goalsTotalMonthlyPace,
                projectedNetBalance: projectedNet
            )
            results.append(outlook)
        }

        return results
    }
}

struct MonthOutlook: Identifiable {
    var id: String { monthName }
    let monthName: String
    let monthDate: Date
    let projectedIncome: Decimal
    let estimatedEssentials: Decimal
    let recurringBills: Decimal
    let savingsGoalsAllocation: Decimal
    let projectedNetBalance: Decimal

    var totalProjectedOutflow: Decimal {
        estimatedEssentials + recurringBills + savingsGoalsAllocation
    }
}
