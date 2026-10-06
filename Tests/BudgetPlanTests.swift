import XCTest
#if canImport(ExpenseTracker)
@testable import ExpenseTracker
#endif

final class BudgetPlanTests: XCTestCase {

    // MARK: - CategoryBudget Tests

    func testCategoryBudgetInitialization() {
        let budget = CategoryBudget(category: .groceries, monthlyLimit: Decimal(15000))
        XCTAssertEqual(budget.category, .groceries)
        XCTAssertEqual(budget.monthlyLimit, Decimal(15000))
        XCTAssertEqual(budget.id, ExpenseCategory.groceries.rawValue)
    }

    func testCategoryBudgetEquatable() {
        let b1 = CategoryBudget(category: .food, monthlyLimit: Decimal(5000))
        let b2 = CategoryBudget(category: .food, monthlyLimit: Decimal(5000))
        let b3 = CategoryBudget(category: .food, monthlyLimit: Decimal(6000))
        let b4 = CategoryBudget(category: .bills, monthlyLimit: Decimal(5000))

        XCTAssertEqual(b1, b2)
        XCTAssertNotEqual(b1, b3)
        XCTAssertNotEqual(b1, b4)
    }

    func testCategoryBudgetCodableRoundTrip() throws {
        let original = CategoryBudget(category: .transport, monthlyLimit: Decimal(4500))
        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(CategoryBudget.self, from: data)

        XCTAssertEqual(decoded, original)
    }

    func testCategoryBudgetDecodeDoubleFallback() throws {
        let json = """
        {
            "category": "Shopping",
            "monthlyLimit": 12500.50
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(CategoryBudget.self, from: json)

        XCTAssertEqual(decoded.category, .shopping)
        XCTAssertEqual(decoded.monthlyLimit, Decimal(12500.50))
    }

    func testCategoryBudgetDecodeMissingLimitDefaultsToZero() throws {
        let json = """
        {
            "category": "Health"
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(CategoryBudget.self, from: json)

        XCTAssertEqual(decoded.category, .health)
        XCTAssertEqual(decoded.monthlyLimit, .zero)
    }

    // MARK: - RecurringBill Tests

    func testRecurringBillInitializationAndClamping() {
        let normalBill = RecurringBill(title: "Broadband", amount: Decimal(999), dueDayOfMonth: 15)
        XCTAssertEqual(normalBill.title, "Broadband")
        XCTAssertEqual(normalBill.amount, Decimal(999))
        XCTAssertEqual(normalBill.dueDayOfMonth, 15)
        XCTAssertEqual(normalBill.category, .bills)

        // Clamping dueDayOfMonth < 1 to 1
        let billUnderflow = RecurringBill(title: "Gym", amount: Decimal(2000), dueDayOfMonth: 0)
        XCTAssertEqual(billUnderflow.dueDayOfMonth, 1, "dueDayOfMonth less than 1 should clamp to 1")

        let billNegative = RecurringBill(title: "Gym", amount: Decimal(2000), dueDayOfMonth: -10)
        XCTAssertEqual(billNegative.dueDayOfMonth, 1, "Negative dueDayOfMonth should clamp to 1")

        // Clamping dueDayOfMonth > 31 to 31
        let billOverflow = RecurringBill(title: "Rent", amount: Decimal(25000), dueDayOfMonth: 32)
        XCTAssertEqual(billOverflow.dueDayOfMonth, 31, "dueDayOfMonth greater than 31 should clamp to 31")

        let billFarOverflow = RecurringBill(title: "Rent", amount: Decimal(25000), dueDayOfMonth: 99)
        XCTAssertEqual(billFarOverflow.dueDayOfMonth, 31, "Large dueDayOfMonth should clamp to 31")
    }

    func testRecurringBillCustomCategoryAndId() {
        let fixedId = UUID()
        let bill = RecurringBill(
            id: fixedId,
            title: "Subway Pass",
            amount: Decimal(1200),
            dueDayOfMonth: 5,
            category: .transport
        )
        XCTAssertEqual(bill.id, fixedId)
        XCTAssertEqual(bill.category, .transport)
    }

    func testRecurringBillEquatable() {
        let id = UUID()
        let b1 = RecurringBill(id: id, title: "Netflix", amount: Decimal(649), dueDayOfMonth: 10, category: .bills)
        let b2 = RecurringBill(id: id, title: "Netflix", amount: Decimal(649), dueDayOfMonth: 10, category: .bills)
        let b3 = RecurringBill(id: UUID(), title: "Netflix", amount: Decimal(649), dueDayOfMonth: 10, category: .bills)
        let b4 = RecurringBill(id: id, title: "Spotify", amount: Decimal(649), dueDayOfMonth: 10, category: .bills)

        XCTAssertEqual(b1, b2)
        XCTAssertNotEqual(b1, b3)
        XCTAssertNotEqual(b1, b4)
    }

    func testRecurringBillCodableRoundTrip() throws {
        let original = RecurringBill(
            id: UUID(),
            title: "Electricity",
            amount: Decimal(3200),
            dueDayOfMonth: 22,
            category: .bills
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(RecurringBill.self, from: data)

        XCTAssertEqual(decoded, original)
    }

    func testRecurringBillDecodingFallbacks() throws {
        let json = """
        {
            "title": "iCloud Storage"
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(RecurringBill.self, from: json)

        XCTAssertNotNil(decoded.id)
        XCTAssertEqual(decoded.title, "iCloud Storage")
        XCTAssertEqual(decoded.amount, .zero)
        XCTAssertEqual(decoded.dueDayOfMonth, 1)
        XCTAssertEqual(decoded.category, .bills)
    }

    func testRecurringBillDecodingDoubleAmount() throws {
        let json = """
        {
            "id": "A1B2C3D4-E5F6-7A8B-9C0D-1E2F3A4B5C6D",
            "title": "Mobile Plan",
            "amount": 799.50,
            "dueDayOfMonth": 20,
            "category": "Bills"
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(RecurringBill.self, from: json)

        XCTAssertEqual(decoded.id, UUID(uuidString: "A1B2C3D4-E5F6-7A8B-9C0D-1E2F3A4B5C6D"))
        XCTAssertEqual(decoded.title, "Mobile Plan")
        XCTAssertEqual(decoded.amount, Decimal(799.50))
        XCTAssertEqual(decoded.dueDayOfMonth, 20)
        XCTAssertEqual(decoded.category, .bills)
    }
}
