import XCTest
#if canImport(ExpenseTracker)
@testable import ExpenseTracker
#endif

final class ExpenseTests: XCTestCase {

    func testDefaultInitialization() {
        let before = Date()
        let expense = Expense(amount: Decimal(250), category: .food)
        let after = Date()

        XCTAssertNotNil(expense.id, "Expense should generate a valid UUID by default")
        XCTAssertEqual(expense.amount, Decimal(250), "Amount should match initialized Decimal value")
        XCTAssertEqual(expense.category, .food, "Category should match initialized category")
        XCTAssertNil(expense.note, "Note should default to nil")
        XCTAssertTrue(expense.date >= before && expense.date <= after, "Date should default to current timestamp")
    }

    func testCustomInitializationWithDecimal() {
        let fixedId = UUID()
        let fixedDate = Date(timeIntervalSince1970: 1700000000)
        let expense = Expense(
            id: fixedId,
            amount: Decimal(123.45),
            category: .groceries,
            date: fixedDate,
            note: "Supermarket shopping"
        )

        XCTAssertEqual(expense.id, fixedId)
        XCTAssertEqual(expense.amount, Decimal(123.45))
        XCTAssertEqual(expense.category, .groceries)
        XCTAssertEqual(expense.date, fixedDate)
        XCTAssertEqual(expense.note, "Supermarket shopping")
    }

    func testDoubleConvenienceInitializer() {
        let expense = Expense(
            amount: 450.75,
            category: .transport,
            note: "Taxi ride"
        )

        XCTAssertEqual(expense.amount, Decimal(450.75), "Convenience init should convert Double to Decimal")
        XCTAssertEqual(expense.amountDouble, 450.75, accuracy: 0.0001, "amountDouble should return accurate Double value")
        XCTAssertEqual(expense.category, .transport)
        XCTAssertEqual(expense.note, "Taxi ride")
    }

    func testNoteTrimmingBehavior() {
        // Empty string -> nil
        let expenseEmpty = Expense(amount: Decimal(100), category: .bills, note: "")
        XCTAssertNil(expenseEmpty.note, "Empty string note should be normalized to nil")

        // Whitespace only -> nil
        let expenseWhitespace = Expense(amount: Decimal(100), category: .bills, note: "   \n\t  ")
        XCTAssertNil(expenseWhitespace.note, "Whitespace-only note should be normalized to nil")

        // Non-empty note -> preserved
        let expenseValid = Expense(amount: Decimal(100), category: .bills, note: "Electricity Bill")
        XCTAssertEqual(expenseValid.note, "Electricity Bill", "Valid note should be retained")
    }

    func testAmountDoubleComputedProperty() {
        let expense = Expense(amount: Decimal(999.99), category: .shopping)
        XCTAssertEqual(expense.amountDouble, 999.99, accuracy: 0.0001)

        let zeroExpense = Expense(amount: Decimal.zero, category: .other)
        XCTAssertEqual(zeroExpense.amountDouble, 0.0)
    }

    func testEquatable() {
        let id = UUID()
        let date = Date(timeIntervalSince1970: 1700000000)
        let exp1 = Expense(id: id, amount: Decimal(500), category: .health, date: date, note: "Medicine")
        let exp2 = Expense(id: id, amount: Decimal(500), category: .health, date: date, note: "Medicine")
        let exp3 = Expense(id: UUID(), amount: Decimal(500), category: .health, date: date, note: "Medicine")
        let exp4 = Expense(id: id, amount: Decimal(600), category: .health, date: date, note: "Medicine")
        let exp5 = Expense(id: id, amount: Decimal(500), category: .other, date: date, note: "Medicine")

        XCTAssertEqual(exp1, exp2, "Expenses with matching properties should be equal")
        XCTAssertNotEqual(exp1, exp3, "Expenses with different IDs should not be equal")
        XCTAssertNotEqual(exp1, exp4, "Expenses with different amounts should not be equal")
        XCTAssertNotEqual(exp1, exp5, "Expenses with different categories should not be equal")
    }

    func testCodableRoundTrip() throws {
        let original = Expense(
            id: UUID(),
            amount: Decimal(1549.50),
            category: .shopping,
            date: Date(),
            note: "New headphones"
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(Expense.self, from: data)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.amount, original.amount)
        XCTAssertEqual(decoded.category, original.category)
        XCTAssertEqual(decoded.note, original.note)
        XCTAssertEqual(
            decoded.date.timeIntervalSince1970,
            original.date.timeIntervalSince1970,
            accuracy: 1.0
        )
    }

    func testDecodingFromLegacyDoubleAmountJSON() throws {
        let json = """
        {
            "id": "A1B2C3D4-E5F6-7A8B-9C0D-1E2F3A4B5C6D",
            "amount": 249.50,
            "category": "Food",
            "date": "2026-10-04T05:00:00Z",
            "note": "Chai and snacks"
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(Expense.self, from: json)

        XCTAssertEqual(decoded.id, UUID(uuidString: "A1B2C3D4-E5F6-7A8B-9C0D-1E2F3A4B5C6D"))
        XCTAssertEqual(decoded.amount, Decimal(249.50))
        XCTAssertEqual(decoded.category, .food)
        XCTAssertEqual(decoded.note, "Chai and snacks")
    }

    func testDecodingFromLegacyIntAmountJSON() throws {
        let json = """
        {
            "id": "B1B2C3D4-E5F6-7A8B-9C0D-1E2F3A4B5C6E",
            "amount": 1500,
            "category": "Groceries",
            "date": "2026-10-03T10:00:00Z"
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(Expense.self, from: json)

        XCTAssertEqual(decoded.amount, Decimal(1500))
        XCTAssertEqual(decoded.category, .groceries)
        XCTAssertNil(decoded.note)
    }

    func testDecodingWithMissingIdGeneratesNewUUID() throws {
        let json = """
        {
            "amount": 75.0,
            "category": "Transport",
            "date": "2026-10-01T12:00:00Z"
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(Expense.self, from: json)

        XCTAssertNotNil(decoded.id)
        XCTAssertEqual(decoded.amount, Decimal(75.0))
        XCTAssertEqual(decoded.category, .transport)
    }

    func testDecodingWithInvalidAmountDefaultsToZero() throws {
        let json = """
        {
            "id": "C1B2C3D4-E5F6-7A8B-9C0D-1E2F3A4B5C6F",
            "amount": "invalid_number",
            "category": "Other",
            "date": "2026-10-01T12:00:00Z"
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(Expense.self, from: json)

        XCTAssertEqual(decoded.amount, Decimal.zero, "Unparseable amount should default to Decimal.zero")
    }
}
