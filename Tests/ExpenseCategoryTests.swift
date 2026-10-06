import XCTest
import SwiftUI
#if canImport(ExpenseTracker)
@testable import ExpenseTracker
#endif

final class ExpenseCategoryTests: XCTestCase {

    func testAllCasesCount() {
        XCTAssertEqual(ExpenseCategory.allCases.count, 7, "ExpenseCategory should have exactly 7 cases")
    }

    func testRawValues() {
        XCTAssertEqual(ExpenseCategory.food.rawValue, "Food")
        XCTAssertEqual(ExpenseCategory.transport.rawValue, "Transport")
        XCTAssertEqual(ExpenseCategory.groceries.rawValue, "Groceries")
        XCTAssertEqual(ExpenseCategory.bills.rawValue, "Bills")
        XCTAssertEqual(ExpenseCategory.health.rawValue, "Health")
        XCTAssertEqual(ExpenseCategory.shopping.rawValue, "Shopping")
        XCTAssertEqual(ExpenseCategory.other.rawValue, "Other")
    }

    func testIdMatchesRawValue() {
        for category in ExpenseCategory.allCases {
            XCTAssertEqual(category.id, category.rawValue, "id should match rawValue for \(category)")
        }
    }

    func testIconNames() {
        XCTAssertEqual(ExpenseCategory.food.iconName, "fork.knife")
        XCTAssertEqual(ExpenseCategory.transport.iconName, "car.fill")
        XCTAssertEqual(ExpenseCategory.groceries.iconName, "cart.fill")
        XCTAssertEqual(ExpenseCategory.bills.iconName, "doc.text.fill")
        XCTAssertEqual(ExpenseCategory.health.iconName, "heart.fill")
        XCTAssertEqual(ExpenseCategory.shopping.iconName, "bag.fill")
        XCTAssertEqual(ExpenseCategory.other.iconName, "ellipsis.circle.fill")
    }

    func testColorNames() {
        XCTAssertEqual(ExpenseCategory.food.colorName, "orange")
        XCTAssertEqual(ExpenseCategory.transport.colorName, "blue")
        XCTAssertEqual(ExpenseCategory.groceries.colorName, "green")
        XCTAssertEqual(ExpenseCategory.bills.colorName, "purple")
        XCTAssertEqual(ExpenseCategory.health.colorName, "red")
        XCTAssertEqual(ExpenseCategory.shopping.colorName, "pink")
        XCTAssertEqual(ExpenseCategory.other.colorName, "gray")
    }

    func testColors() {
        XCTAssertEqual(ExpenseCategory.food.color, Color.orange)
        XCTAssertEqual(ExpenseCategory.transport.color, Color.blue)
        XCTAssertEqual(ExpenseCategory.groceries.color, Color.green)
        XCTAssertEqual(ExpenseCategory.bills.color, Color.purple)
        XCTAssertEqual(ExpenseCategory.health.color, Color.red)
        XCTAssertEqual(ExpenseCategory.shopping.color, Color.pink)
        XCTAssertEqual(ExpenseCategory.other.color, Color.gray)
    }

    func testAccessibilityDescriptions() {
        for category in ExpenseCategory.allCases {
            XCTAssertEqual(category.accessibilityDescription, "\(category.rawValue) category")
        }
    }

    func testCodableRoundTrip() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        for category in ExpenseCategory.allCases {
            let data = try encoder.encode(category)
            let decoded = try decoder.decode(ExpenseCategory.self, from: data)
            XCTAssertEqual(decoded, category, "Encoding and decoding should preserve category \(category)")
        }
    }

    func testInitFromInvalidRawValueReturnsNil() {
        let invalid = ExpenseCategory(rawValue: "UnknownCategory")
        XCTAssertNil(invalid, "Initializing with an unknown rawValue should return nil")
    }
}
