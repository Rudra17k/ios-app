import Foundation
import XCTest

@main
struct TestRunner {
    static func main() {
        print("========================================")
        print("RUNNING ALL XCTEST UNIT TEST SUITES")
        print("========================================")

        let testSuite = XCTestSuite(name: "AllModelTestsSuite")
        testSuite.addTest(ExpenseCategoryTests.defaultTestSuite)
        testSuite.addTest(ExpenseTests.defaultTestSuite)
        testSuite.addTest(CurrencyHelperTests.defaultTestSuite)
        testSuite.addTest(BudgetPlanTests.defaultTestSuite)
        testSuite.addTest(SavingsGoalTests.defaultTestSuite)

        let observer = TestProgressObserver()
        XCTestObservationCenter.shared.addTestObserver(observer)

        testSuite.run()

        print("========================================")
        print("SUMMARY: \(observer.passedCount) passed, \(observer.failedCount) failed (\(observer.totalCount) total)")
        print("========================================")

        if observer.failedCount > 0 {
            exit(1)
        }
    }
}

final class TestProgressObserver: NSObject, XCTestObservation {
    var passedCount = 0
    var failedCount = 0
    var totalCount = 0
    private var currentTestFailed = false

    func testCaseWillStart(_ testCase: XCTestCase) {
        currentTestFailed = false
        totalCount += 1
    }

    func testCase(_ testCase: XCTestCase, didRecord issue: XCTIssue) {
        currentTestFailed = true
        failedCount += 1
        print("  ❌ [FAIL] \(testCase.name): \(issue.compactDescription)")
    }

    func testCaseDidFinish(_ testCase: XCTestCase) {
        if !currentTestFailed {
            passedCount += 1
            print("  ✅ [PASS] \(testCase.name)")
        }
    }
}
