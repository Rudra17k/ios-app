import Foundation

struct CategoryBudget: Identifiable, Codable, Equatable {
    var id: String { category.rawValue }
    var category: ExpenseCategory
    var monthlyLimit: Decimal

    enum CodingKeys: String, CodingKey {
        case category, monthlyLimit
    }

    init(category: ExpenseCategory, monthlyLimit: Decimal) {
        self.category = category
        self.monthlyLimit = monthlyLimit
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.category = try container.decode(ExpenseCategory.self, forKey: .category)
        if let dec = try? container.decode(Decimal.self, forKey: .monthlyLimit) {
            self.monthlyLimit = dec
        } else if let dbl = try? container.decode(Double.self, forKey: .monthlyLimit) {
            self.monthlyLimit = Decimal(dbl)
        } else {
            self.monthlyLimit = .zero
        }
    }
}

struct RecurringBill: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var amount: Decimal
    var dueDayOfMonth: Int
    var category: ExpenseCategory

    init(id: UUID = UUID(), title: String, amount: Decimal, dueDayOfMonth: Int, category: ExpenseCategory = .bills) {
        self.id = id
        self.title = title
        self.amount = amount
        self.dueDayOfMonth = max(1, min(31, dueDayOfMonth))
        self.category = category
    }

    enum CodingKeys: String, CodingKey {
        case id, title, amount, dueDayOfMonth, category
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.title = try container.decode(String.self, forKey: .title)
        self.dueDayOfMonth = try container.decodeIfPresent(Int.self, forKey: .dueDayOfMonth) ?? 1
        self.category = try container.decodeIfPresent(ExpenseCategory.self, forKey: .category) ?? .bills
        if let dec = try? container.decode(Decimal.self, forKey: .amount) {
            self.amount = dec
        } else if let dbl = try? container.decode(Double.self, forKey: .amount) {
            self.amount = Decimal(dbl)
        } else {
            self.amount = .zero
        }
    }
}
