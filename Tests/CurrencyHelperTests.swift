import XCTest
#if canImport(ExpenseTracker)
@testable import ExpenseTracker
#endif

final class CurrencyHelperTests: XCTestCase {

    var helper: CurrencyHelper!

    override func setUp() {
        super.setUp()
        helper = CurrencyHelper.shared
    }

    override func tearDown() {
        helper = nil
        super.tearDown()
    }

    func testFormatDecimalStandard() {
        // Standard format should omit decimals for whole numbers
        let formattedWhole = helper.format(Decimal(500))
        XCTAssertTrue(formattedWhole.contains("500"))
        XCTAssertTrue(formattedWhole.contains("₹"))

        // Standard format should include decimals when fractional
        let formattedFraction = helper.format(Decimal(500.75))
        XCTAssertTrue(formattedFraction.contains("500.75") || formattedFraction.contains("500,75"))
        XCTAssertTrue(formattedFraction.contains("₹"))
    }

    func testFormatDecimalForceDecimals() {
        let formatted = helper.format(Decimal(500), forceDecimals: true)
        XCTAssertTrue(formatted.contains(".00") || formatted.contains(",00"), "forceDecimals should display two zero decimals")
        XCTAssertTrue(formatted.contains("500"))
        XCTAssertTrue(formatted.contains("₹"))
    }

    func testFormatWhole() {
        let formatted = helper.formatWhole(Decimal(1250.85))
        XCTAssertTrue(formatted.contains("₹"))
        // Should format without decimal digits
        XCTAssertFalse(formatted.contains(".85"))
    }

    func testFormatDouble() {
        let formatted = helper.format(299.99)
        XCTAssertTrue(formatted.contains("299.99") || formatted.contains("299,99"))
        XCTAssertTrue(formatted.contains("₹"))

        let formattedForced = helper.format(100.0, forceDecimals: true)
        XCTAssertTrue(formattedForced.contains(".00") || formattedForced.contains(",00"))
    }

    func testParseDecimalStandardNumbers() {
        XCTAssertEqual(helper.parseDecimal(from: "100"), Decimal(100))
        XCTAssertEqual(helper.parseDecimal(from: "250.50"), Decimal(250.50))
        XCTAssertEqual(helper.parseDecimal(from: "0"), Decimal(0))
        XCTAssertEqual(helper.parseDecimal(from: "0.99"), Decimal(0.99))
    }

    func testParseDecimalWithCurrencySymbolAndSpaces() {
        XCTAssertEqual(helper.parseDecimal(from: "₹ 500"), Decimal(500))
        XCTAssertEqual(helper.parseDecimal(from: "  ₹1,250.75 \n"), Decimal(1250.75))
        XCTAssertEqual(helper.parseDecimal(from: "₹0.00"), Decimal(0))
    }

    func testParseDecimalIndianCommaGrouping() {
        // Indian numbering format: 1,50,000 -> 150000
        XCTAssertEqual(helper.parseDecimal(from: "1,50,000"), Decimal(150000))
        XCTAssertEqual(helper.parseDecimal(from: "₹ 10,00,000"), Decimal(1000000))
        XCTAssertEqual(helper.parseDecimal(from: "1,50,000.50"), Decimal(string: "150000.50"))
    }

    func testParseDecimalEuropeanCommaFraction() {
        // e.g. "150,50" -> 150.50 (2 decimal places after comma)
        let parsed = helper.parseDecimal(from: "150,50")
        XCTAssertEqual(parsed, Decimal(string: "150.50"))

        let parsedSingleDigit = helper.parseDecimal(from: "99,5")
        XCTAssertEqual(parsedSingleDigit, Decimal(string: "99.5"))
    }

    func testParseDecimalFormattingVariations() {
        XCTAssertEqual(helper.parseDecimal(from: "10,000"), Decimal(10000))
        XCTAssertEqual(helper.parseDecimal(from: "2,500.00"), Decimal(string: "2500.00"))
        XCTAssertEqual(helper.parseDecimal(from: "₹ 5,00,000.75"), Decimal(string: "500000.75"))
    }
}
