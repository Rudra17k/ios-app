import Foundation

struct Expense: Identifiable, Codable, Equatable {
    let id: UUID
    var amount: Decimal
    var category: ExpenseCategory
    var date: Date
    var note: String?

    init(id: UUID = UUID(), amount: Decimal, category: ExpenseCategory, date: Date = Date(), note: String? = nil) {
        self.id = id
        self.amount = amount
        self.category = category
        self.date = date
        self.note = (note?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false) ? note : nil
    }

    // Convenience initializer for Double to preserve backward source compatibility
    init(id: UUID = UUID(), amount: Double, category: ExpenseCategory, date: Date = Date(), note: String? = nil) {
        self.init(id: id, amount: Decimal(amount), category: category, date: date, note: note)
    }

    var amountDouble: Double {
        NSDecimalNumber(decimal: amount).doubleValue
    }

    enum CodingKeys: String, CodingKey {
        case id
        case amount
        case category
        case date
        case note
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.category = try container.decode(ExpenseCategory.self, forKey: .category)
        self.date = try container.decode(Date.self, forKey: .date)
        self.note = try container.decodeIfPresent(String.self, forKey: .note)

        // Robustly decode amount whether it was stored as Decimal, Double, or Int in JSON
        if let decimalVal = try? container.decode(Decimal.self, forKey: .amount) {
            self.amount = decimalVal
        } else if let doubleVal = try? container.decode(Double.self, forKey: .amount) {
            self.amount = Decimal(doubleVal)
        } else if let intVal = try? container.decode(Int.self, forKey: .amount) {
            self.amount = Decimal(intVal)
        } else {
            self.amount = Decimal.zero
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(amount, forKey: .amount)
        try container.encode(category, forKey: .category)
        try container.encode(date, forKey: .date)
        try container.encodeIfPresent(note, forKey: .note)
    }
}
