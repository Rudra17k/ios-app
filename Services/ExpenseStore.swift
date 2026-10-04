import Foundation
import Combine

final class ExpenseStore: ObservableObject {
    @Published var expenses: [Expense] = []
    @Published var lastAddedExpense: Expense? = nil
    @Published var errorMessage: String? = nil

    private let filename = "expenses.json"

    init() {
        loadExpenses()
    }

    private var fileURL: URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0].appendingPathComponent(filename)
    }

    func loadExpenses() {
        let url = fileURL
        guard FileManager.default.fileExists(atPath: url.path) else {
            self.expenses = []
            return
        }

        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let decoded = try decoder.decode([Expense].self, from: data)
            self.expenses = decoded.sorted {
                if $0.date == $1.date {
                    return $0.id.uuidString > $1.id.uuidString
                }
                return $0.date > $1.date
            }
        } catch {
            print("Failed to load expenses: \(error.localizedDescription)")
            self.errorMessage = "Could not read saved expenses: \(error.localizedDescription)"
            self.expenses = []
        }
    }

    func saveExpenses() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(expenses)
            try data.write(to: fileURL, options: [.atomicWrite, .completeFileProtection])
        } catch {
            print("Failed to save expenses: \(error.localizedDescription)")
            self.errorMessage = "Failed to save changes: \(error.localizedDescription)"
        }
    }

    func addExpense(amount: Decimal, category: ExpenseCategory, date: Date, note: String?) -> Expense {
        let newExpense = Expense(amount: amount, category: category, date: date, note: note)
        expenses.append(newExpense)
        sortExpenses()
        saveExpenses()
        lastAddedExpense = newExpense
        return newExpense
    }

    // Double overload for backward compatibility
    @discardableResult
    func addExpense(amount: Double, category: ExpenseCategory, date: Date, note: String?) -> Expense {
        return addExpense(amount: Decimal(amount), category: category, date: date, note: note)
    }

    func updateExpense(_ updated: Expense) {
        if let index = expenses.firstIndex(where: { $0.id == updated.id }) {
            expenses[index] = updated
            sortExpenses()
            saveExpenses()
        }
    }

    func deleteExpense(id: UUID) {
        expenses.removeAll { $0.id == id }
        saveExpenses()
    }

    func deleteExpenses(at offsets: IndexSet, from currentList: [Expense]) {
        let idsToDelete = offsets.map { currentList[$0].id }
        expenses.removeAll { idsToDelete.contains($0.id) }
        saveExpenses()
    }

    func undoLastAdded() {
        guard let last = lastAddedExpense else { return }
        deleteExpense(id: last.id)
        lastAddedExpense = nil
    }

    private func sortExpenses() {
        expenses.sort {
            if $0.date == $1.date {
                return $0.id.uuidString > $1.id.uuidString
            }
            return $0.date > $1.date
        }
    }

    // MARK: - Computed Stats & Analytics
    var thisMonthTotal: Decimal {
        let calendar = Calendar.current
        let now = Date()
        guard let interval = calendar.dateInterval(of: .month, for: now) else { return .zero }
        return expenses
            .filter { interval.contains($0.date) }
            .reduce(Decimal.zero) { $0 + $1.amount }
    }

    var priorMonthTotal: Decimal {
        let calendar = Calendar.current
        guard let priorMonthDate = calendar.date(byAdding: .month, value: -1, to: Date()),
              let interval = calendar.dateInterval(of: .month, for: priorMonthDate) else {
            return .zero
        }
        return expenses
            .filter { interval.contains($0.date) }
            .reduce(Decimal.zero) { $0 + $1.amount }
    }

    var recentExpenses: [Expense] {
        return expenses
    }

    func categoryTotals(for interval: DateInterval) -> [ExpenseCategory: Decimal] {
        var totals: [ExpenseCategory: Decimal] = [:]
        for expense in expenses where interval.contains(expense.date) {
            totals[expense.category, default: .zero] += expense.amount
        }
        return totals
    }

    func expenses(in interval: DateInterval) -> [Expense] {
        return expenses.filter { interval.contains($0.date) }
    }

    // MARK: - CSV Export & Import
    func exportCSV() -> String {
        var csv = "ID,Date,Category,Amount,Note\n"
        let isoFormatter = ISO8601DateFormatter()

        for exp in expenses {
            let noteEscaped = (exp.note ?? "").replacingOccurrences(of: "\"", with: "\"\"")
            let dateStr = isoFormatter.string(from: exp.date)
            csv += "\(exp.id.uuidString),\(dateStr),\(exp.category.rawValue),\(exp.amount),\"\(noteEscaped)\"\n"
        }
        return csv
    }

    enum CSVImportError: LocalizedError {
        case emptyData
        case invalidFormat(String)

        var errorDescription: String? {
            switch self {
            case .emptyData: return "CSV file is empty."
            case .invalidFormat(let msg): return "CSV format error: \(msg)"
            }
        }
    }

    func importCSV(_ csvText: String) throws -> (imported: Int, skipped: Int) {
        let lines = csvText.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        guard lines.count > 1 else {
            throw CSVImportError.emptyData
        }

        let isoFormatter = ISO8601DateFormatter()
        let fallbackDateFormatter = DateFormatter()
        fallbackDateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"

        var importedCount = 0
        var skippedCount = 0
        var newExpenses: [Expense] = []

        // Line 0 is header: ID,Date,Category,Amount,Note
        for line in lines.dropFirst() {
            let parts = parseCSVLine(line)
            guard parts.count >= 4 else {
                skippedCount += 1
                continue
            }

            // Columns: 0: ID (optional), 1: Date, 2: Category, 3: Amount, 4: Note (optional)
            let id = UUID(uuidString: parts[0]) ?? UUID()
            let dateStr = parts[1]
            let catStr = parts[2]
            let amountStr = parts[3]
            let noteStr = parts.count > 4 ? parts[4] : nil

            let date = isoFormatter.date(from: dateStr)
                ?? fallbackDateFormatter.date(from: dateStr)
                ?? Date()

            let category = ExpenseCategory.allCases.first {
                $0.rawValue.caseInsensitiveCompare(catStr) == .orderedSame
            } ?? .other

            guard let amount = CurrencyHelper.shared.parseDecimal(from: amountStr), amount > 0 else {
                skippedCount += 1
                continue
            }

            // Skip exact duplicates by ID
            if expenses.contains(where: { $0.id == id }) || newExpenses.contains(where: { $0.id == id }) {
                skippedCount += 1
                continue
            }

            let exp = Expense(id: id, amount: amount, category: category, date: date, note: noteStr)
            newExpenses.append(exp)
            importedCount += 1
        }

        if importedCount > 0 {
            expenses.append(contentsOf: newExpenses)
            sortExpenses()
            saveExpenses()
        }

        return (imported: importedCount, skipped: skippedCount)
    }

    private func parseCSVLine(_ line: String) -> [String] {
        var fields: [String] = []
        var current = ""
        var insideQuotes = false

        for char in line {
            if char == "\"" {
                insideQuotes.toggle()
            } else if char == "," && !insideQuotes {
                fields.append(current.trimmingCharacters(in: .whitespaces))
                current = ""
            } else {
                current.append(char)
            }
        }
        fields.append(current.trimmingCharacters(in: .whitespaces))
        return fields
    }

    // MARK: - JSON Backup & Restore
    func createBackupData() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        return try encoder.encode(expenses)
    }

    func restoreFromBackup(data: Data) throws -> Int {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let restored = try decoder.decode([Expense].self, from: data)
        var count = 0
        for item in restored {
            if !expenses.contains(where: { $0.id == item.id }) {
                expenses.append(item)
                count += 1
            }
        }
        sortExpenses()
        saveExpenses()
        return count
    }
}
