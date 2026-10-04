import Foundation

// Test runner harness executing focused tests for core logic, calculations, date boundaries, and persistence.
@main
struct ExpenseTrackerTests {
    static var passedCount = 0
    static var failedCount = 0

    static func assert(_ condition: Bool, _ message: String) {
        if condition {
            print("  ✅ PASS: \(message)")
            passedCount += 1
        } else {
            print("  ❌ FAIL: \(message)")
            failedCount += 1
        }
    }

    static func main() {
        print("==========================================")
        print("RUNNING EXPENSE TRACKER VERIFICATION SUITE")
        print("==========================================")

        testDailyPaceAndRounding()
        testContributionsOnSameDay()
        testGoalCompletionAndOverContribution()
        testDateBoundariesAndLeapYears()
        testHistoricalSnapshotPreservation()
        testExpensePersistenceAndBackwardCompatibility()
        testCSVExportAndImport()

        print("==========================================")
        print("RESULTS: \(passedCount) passed, \(failedCount) failed.")
        print("==========================================")

        if failedCount > 0 {
            exit(1)
        }
    }

    // MARK: - Test 1: Daily Pace and Rounding
    static func testDailyPaceAndRounding() {
        print("\n[Test Suite 1: Daily Pace and Rounding]")

        // Prompt example: ₹20,000 goal over 180 days -> starts at about ₹112/day.
        let pace1 = SavingsGoal.calculateDailyPace(remaining: Decimal(20000), days: 180)
        assert(pace1 == Decimal(112), "₹20,000 over 180 days must round up (ceil) to ₹112/day (actual: \(pace1))")

        // Prompt example: If ₹500 contributed on day 1 -> remaining ₹19,500 over 179 days -> about ₹109/day.
        let pace2 = SavingsGoal.calculateDailyPace(remaining: Decimal(19500), days: 179)
        assert(pace2 == Decimal(109), "₹19,500 over 179 days must round up (ceil) to ₹109/day (actual: \(pace2))")

        // Exact division (₹1,000 over 10 days = ₹100)
        let exactPace = SavingsGoal.calculateDailyPace(remaining: Decimal(1000), days: 10)
        assert(exactPace == Decimal(100), "₹1,000 over 10 days must equal exactly ₹100 (actual: \(exactPace))")

        // ₹1 over 3 days -> ₹0.333... must round up to ₹1
        let fractionPace = SavingsGoal.calculateDailyPace(remaining: Decimal(1), days: 3)
        assert(fractionPace == Decimal(1), "₹1 over 3 days must round up to whole ₹1 (actual: \(fractionPace))")

        // 0 remaining -> 0 pace
        let zeroPace = SavingsGoal.calculateDailyPace(remaining: .zero, days: 30)
        assert(zeroPace == .zero, "0 remaining must yield 0 daily pace")
    }

    // MARK: - Test 2: Contributions On Same Day
    static func testContributionsOnSameDay() {
        print("\n[Test Suite 2: Contributions On Same Day]")

        let calendar = Calendar.current
        let today = Date()
        let targetDate = calendar.date(byAdding: .day, value: 30, to: today)!

        var goal = SavingsGoal(
            title: "Weekend Trip",
            targetAmount: Decimal(10000),
            targetDate: targetDate
        )

        // Add 3 contributions on the same day
        let c1 = GoalContribution(date: today, amount: Decimal(300), note: "Morning savings")
        let c2 = GoalContribution(date: today.addingTimeInterval(3600), amount: Decimal(200), note: "Lunch savings")
        let c3 = GoalContribution(date: today.addingTimeInterval(7200), amount: Decimal(500), note: "Dinner savings")

        goal.contributions.append(contentsOf: [c1, c2, c3])

        let sameDayTotal = goal.contributionAmount(on: today, calendar: calendar)
        assert(sameDayTotal == Decimal(1000), "Three same-day contributions (300 + 200 + 500) must sum to ₹1,000 (actual: \(sameDayTotal))")

        // Contribution days count should count this as 1 day, not 3 days
        assert(goal.totalContributionDaysCount == 1, "Multiple contributions on the same calendar day must count as 1 contribution day (actual: \(goal.totalContributionDaysCount))")

        // Remaining amount should be 9000
        assert(goal.remainingAmount == Decimal(9000), "Remaining amount must be ₹9,000 (actual: \(goal.remainingAmount))")
    }

    // MARK: - Test 3: Goal Completion and Contributions Above Target
    static func testGoalCompletionAndOverContribution() {
        print("\n[Test Suite 3: Goal Completion and Over-Contribution]")

        let calendar = Calendar.current
        let today = Date()
        let targetDate = calendar.date(byAdding: .day, value: 10, to: today)!

        var goal = SavingsGoal(
            title: "Gadget",
            targetAmount: Decimal(5000),
            targetDate: targetDate
        )

        assert(!goal.isCompleted, "Goal should not be completed initially")

        // Contribute exact target
        goal.contributions.append(GoalContribution(date: today, amount: Decimal(5000)))
        assert(goal.isCompleted, "Goal should be completed after meeting target")
        assert(goal.remainingAmount == .zero, "Remaining amount should be 0 when completed")
        assert(goal.currentDailyPace() == .zero, "Daily pace should be 0 when completed")

        // Contribute above target (e.g. ₹1,000 extra)
        goal.contributions.append(GoalContribution(date: today, amount: Decimal(1000)))
        assert(goal.isCompleted, "Goal remains completed with extra savings")
        assert(goal.confirmedSaved == Decimal(6000), "Total saved should be ₹6,000")
        assert(goal.remainingAmount == .zero, "Remaining amount cannot be negative")

        // Day comparison for above target
        let comp = goal.comparisonForDate(today, calendar: calendar)
        assert(comp == .aboveTarget || comp == .targetReached, "Status must show aboveTarget or targetReached (actual: \(comp))")
    }

    // MARK: - Test 4: Date Boundaries and Leap Years
    static func testDateBoundariesAndLeapYears() {
        print("\n[Test Suite 4: Date Boundaries and Leap Years]")

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Kolkata")!

        // Test leap year 2024: Feb 28 2024 to March 1 2024
        var compsStart = DateComponents()
        compsStart.year = 2024
        compsStart.month = 2
        compsStart.day = 28
        let feb28 = calendar.date(from: compsStart)!

        var compsEnd = DateComponents()
        compsEnd.year = 2024
        compsEnd.month = 3
        compsEnd.day = 1
        let mar1 = calendar.date(from: compsEnd)!

        let leapGoal = SavingsGoal(
            title: "Leap Goal",
            targetAmount: Decimal(200),
            targetDate: mar1,
            createdDate: feb28
        )

        let leapDays = leapGoal.remainingDays(from: feb28, calendar: calendar)
        assert(leapDays == 2, "Feb 28 to March 1 in leap year 2024 must be 2 calendar days (Feb 28 & Feb 29) (actual: \(leapDays))")

        // Non-leap year 2025: Feb 28 2025 to March 1 2025
        compsStart.year = 2025
        let feb28_2025 = calendar.date(from: compsStart)!
        compsEnd.year = 2025
        let mar1_2025 = calendar.date(from: compsEnd)!

        let nonLeapGoal = SavingsGoal(
            title: "Non-Leap Goal",
            targetAmount: Decimal(200),
            targetDate: mar1_2025,
            createdDate: feb28_2025
        )

        let nonLeapDays = nonLeapGoal.remainingDays(from: feb28_2025, calendar: calendar)
        assert(nonLeapDays == 1, "Feb 28 to March 1 in non-leap year 2025 must be 1 calendar day (actual: \(nonLeapDays))")
    }

    // MARK: - Test 5: Historical Snapshot Preservation
    static func testHistoricalSnapshotPreservation() {
        print("\n[Test Suite 5: Historical Snapshot Preservation]")

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone.current

        let today = Date()
        let day1 = calendar.date(byAdding: .day, value: -5, to: today)!
        let targetDate = calendar.date(byAdding: .day, value: 20, to: today)!

        var goal = SavingsGoal(
            title: "Trip",
            targetAmount: Decimal(20000),
            targetDate: targetDate,
            createdDate: day1
        )

        // Day 1 had initial snapshot target of ₹112
        let day1Key = SavingsGoal.dateKey(for: day1, calendar: calendar)
        goal.dailySnapshots[day1Key] = Decimal(112)

        // User contributed ₹112 on Day 1
        goal.contributions.append(GoalContribution(date: day1, amount: Decimal(112)))

        let day1ComparisonBefore = goal.comparisonForDate(day1, calendar: calendar)
        assert(day1ComparisonBefore == .targetReached, "Day 1 should be targetReached initially")

        // Now later (e.g. today), huge contributions are added which drastically lowers future pace
        goal.contributions.append(GoalContribution(date: today, amount: Decimal(15000)))

        // Querying Day 1's target must STILL return the historical snapshot ₹112, NOT the new future pace!
        let day1TargetAfter = goal.targetForDate(day1, calendar: calendar)
        assert(day1TargetAfter == Decimal(112), "Historical Day 1 target must remain ₹112 even after future pace changes (actual: \(day1TargetAfter))")

        let day1ComparisonAfter = goal.comparisonForDate(day1, calendar: calendar)
        assert(day1ComparisonAfter == .targetReached, "Day 1 status must not mutate when future pace changes")
    }

    // MARK: - Test 6: Persistence & Backward Compatibility
    static func testExpensePersistenceAndBackwardCompatibility() {
        print("\n[Test Suite 6: Persistence & Backward Compatibility]")

        // Simulate legacy JSON where amount was written as a Double
        let legacyJSON = """
        [
            {
                "id": "11111111-2222-3333-4444-555555555555",
                "amount": 249.50,
                "category": "Food",
                "date": "2026-10-04T05:00:00Z",
                "note": "Chai and snacks"
            },
            {
                "id": "22222222-3333-4444-5555-666666666666",
                "amount": 1500,
                "category": "Groceries",
                "date": "2026-10-03T10:00:00Z"
            }
        ]
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            let expenses = try decoder.decode([Expense].self, from: legacyJSON)
            assert(expenses.count == 2, "Successfully decoded 2 legacy expenses")
            assert(expenses[0].amount == Decimal(string: "249.5") || expenses[0].amount == Decimal(249.5), "Legacy Double 249.50 decoded into Decimal amount: \(expenses[0].amount)")
            assert(expenses[0].category == .food, "Category decoded as Food")
            assert(expenses[1].amount == Decimal(1500), "Legacy Int 1500 decoded into Decimal: \(expenses[1].amount)")
            assert(expenses[1].note == nil, "Missing note decoded as nil")

            // Re-encode to test round-trip
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let reencoded = try encoder.encode(expenses)
            let roundTripped = try decoder.decode([Expense].self, from: reencoded)
            assert(roundTripped == expenses, "Round-trip JSON encoding/decoding preserved exact equality")
        } catch {
            assert(false, "Legacy JSON decoding threw error: \(error.localizedDescription)")
        }
    }

    // MARK: - Test 7: CSV Export and Import
    static func testCSVExportAndImport() {
        print("\n[Test Suite 7: CSV Export and Import]")

        let store = ExpenseStore()
        let exp1 = Expense(amount: Decimal(150), category: .food, date: Date(), note: "Tea & Biscuit")
        let exp2 = Expense(amount: Decimal(800), category: .transport, date: Date(), note: "Metro, with comma in note")
        store.expenses = [exp1, exp2]

        let csv = store.exportCSV()
        assert(csv.contains("Tea & Biscuit"), "CSV export contains note")
        assert(csv.contains("\"Metro, with comma in note\""), "CSV export properly escapes comma in note")

        // Import test
        let sampleCSV = """
        ID,Date,Category,Amount,Note
        \(UUID().uuidString),2026-10-04T08:00:00Z,Bills,2500,Electricity
        \(UUID().uuidString),2026-10-04T09:00:00Z,Health,450.50,"Medicine, Pharmacy"
        """

        do {
            let res = try store.importCSV(sampleCSV)
            assert(res.imported == 2, "CSV import imported 2 valid records (actual: \(res.imported))")
            assert(res.skipped == 0, "0 skipped records")
            assert(store.expenses.contains { $0.category == .bills && $0.amount == Decimal(2500) }, "Imported bills expense present in store")
        } catch {
            assert(false, "CSV import failed: \(error.localizedDescription)")
        }
    }
}
