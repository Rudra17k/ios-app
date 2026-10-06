import XCTest
#if canImport(ExpenseTracker)
@testable import ExpenseTracker
#endif

final class SavingsGoalTests: XCTestCase {

    // MARK: - CostBreakdownItem Tests

    func testCostBreakdownItemInitialization() {
        let item = CostBreakdownItem(title: "Flight Tickets", amount: Decimal(15000))
        XCTAssertNotNil(item.id)
        XCTAssertEqual(item.title, "Flight Tickets")
        XCTAssertEqual(item.amount, Decimal(15000))
    }

    func testCostBreakdownItemCodableRoundTrip() throws {
        let item = CostBreakdownItem(title: "Hotel Stay", amount: Decimal(12000.50))
        let data = try JSONEncoder().encode(item)
        let decoded = try JSONDecoder().decode(CostBreakdownItem.self, from: data)

        XCTAssertEqual(decoded, item)
    }

    func testCostBreakdownItemDecodeFallbacks() throws {
        let json = """
        {
            "title": "Sightseeing"
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(CostBreakdownItem.self, from: json)
        XCTAssertNotNil(decoded.id)
        XCTAssertEqual(decoded.title, "Sightseeing")
        XCTAssertEqual(decoded.amount, .zero)
    }

    func testCostBreakdownItemDecodeDoubleAmount() throws {
        let json = """
        {
            "id": "A1B2C3D4-E5F6-7A8B-9C0D-1E2F3A4B5C6D",
            "title": "Museum Passes",
            "amount": 1500.75
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(CostBreakdownItem.self, from: json)
        XCTAssertEqual(decoded.id, UUID(uuidString: "A1B2C3D4-E5F6-7A8B-9C0D-1E2F3A4B5C6D"))
        XCTAssertEqual(decoded.amount, Decimal(1500.75))
    }

    // MARK: - GoalContribution Tests

    func testGoalContributionInitialization() {
        let before = Date()
        let contribution = GoalContribution(amount: Decimal(500), note: "Bonus money")
        let after = Date()

        XCTAssertNotNil(contribution.id)
        XCTAssertEqual(contribution.amount, Decimal(500))
        XCTAssertEqual(contribution.note, "Bonus money")
        XCTAssertTrue(contribution.date >= before && contribution.date <= after)
    }

    func testGoalContributionCodableRoundTrip() throws {
        let original = GoalContribution(
            id: UUID(),
            date: Date(timeIntervalSince1970: 1700000000),
            amount: Decimal(750.25),
            note: "Coffee savings"
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(GoalContribution.self, from: data)

        XCTAssertEqual(decoded, original)
    }

    func testGoalContributionDecodeFallbacks() throws {
        let json = """
        {
            "date": "2026-10-01T12:00:00Z"
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(GoalContribution.self, from: json)

        XCTAssertNotNil(decoded.id)
        XCTAssertEqual(decoded.amount, .zero)
        XCTAssertNil(decoded.note)
    }

    // MARK: - DayTargetComparison Tests

    func testDayTargetComparisonRawValues() {
        XCTAssertEqual(DayTargetComparison.aboveTarget.rawValue, "Above Target")
        XCTAssertEqual(DayTargetComparison.targetReached.rawValue, "Target Reached")
        XCTAssertEqual(DayTargetComparison.belowTarget.rawValue, "Below Target")
        XCTAssertEqual(DayTargetComparison.neutral.rawValue, "No Contribution")
    }

    // MARK: - SavingsGoal Initialization & Destination Trimming

    func testSavingsGoalInitialization() {
        let calendar = Calendar.current
        let today = Date()
        let target = calendar.date(byAdding: .day, value: 60, to: today)!

        let goal = SavingsGoal(
            title: "Trip to Goa",
            destination: " Goa Beach ",
            targetAmount: Decimal(30000),
            targetDate: target,
            createdDate: today
        )

        XCTAssertEqual(goal.title, "Trip to Goa")
        XCTAssertEqual(goal.destination, " Goa Beach ")
        XCTAssertEqual(goal.targetAmount, Decimal(30000))
        XCTAssertEqual(goal.confirmedSaved, .zero)
        XCTAssertEqual(goal.remainingAmount, Decimal(30000))
        XCTAssertFalse(goal.isCompleted)

        // Verifies automatic creation day snapshot recording
        let todayKey = SavingsGoal.dateKey(for: today, calendar: calendar)
        XCTAssertNotNil(goal.dailySnapshots[todayKey], "Creation day snapshot should be recorded on init")
    }

    func testSavingsGoalDestinationTrimmingToNil() {
        let calendar = Calendar.current
        let today = Date()
        let target = calendar.date(byAdding: .day, value: 30, to: today)!

        let goalEmpty = SavingsGoal(
            title: "Emergency Fund",
            destination: "",
            targetAmount: Decimal(50000),
            targetDate: target
        )
        XCTAssertNil(goalEmpty.destination, "Empty destination should normalize to nil")

        let goalWhitespace = SavingsGoal(
            title: "Emergency Fund",
            destination: "   \n\t  ",
            targetAmount: Decimal(50000),
            targetDate: target
        )
        XCTAssertNil(goalWhitespace.destination, "Whitespace destination should normalize to nil")
    }

    // MARK: - Calculations: Daily Pace & Ceil Rounding

    func testCalculateDailyPaceRoundingRules() {
        // ₹20,000 goal over 180 days -> starts at ₹112/day (ceil of 111.111...)
        let pace1 = SavingsGoal.calculateDailyPace(remaining: Decimal(20000), days: 180)
        XCTAssertEqual(pace1, Decimal(112))

        // ₹19,500 over 179 days -> ₹109/day (ceil of 108.938...)
        let pace2 = SavingsGoal.calculateDailyPace(remaining: Decimal(19500), days: 179)
        XCTAssertEqual(pace2, Decimal(109))

        // Exact division (₹1,000 over 10 days = ₹100)
        let paceExact = SavingsGoal.calculateDailyPace(remaining: Decimal(1000), days: 10)
        XCTAssertEqual(paceExact, Decimal(100))

        // Small fractional quotient (₹1 over 3 days = ₹1)
        let paceFraction = SavingsGoal.calculateDailyPace(remaining: Decimal(1), days: 3)
        XCTAssertEqual(paceFraction, Decimal(1))

        // Zero or negative edge cases
        XCTAssertEqual(SavingsGoal.calculateDailyPace(remaining: .zero, days: 30), .zero)
        XCTAssertEqual(SavingsGoal.calculateDailyPace(remaining: Decimal(-500), days: 30), .zero)
        XCTAssertEqual(SavingsGoal.calculateDailyPace(remaining: Decimal(500), days: 0), .zero)
        XCTAssertEqual(SavingsGoal.calculateDailyPace(remaining: Decimal(500), days: -5), .zero)
    }

    // MARK: - Date Boundaries, Calendars, & Leap Years

    func testRemainingDaysAndLeapYears() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Kolkata")!

        // Leap Year 2024: Feb 28 to March 1 (includes Feb 29 -> 2 days)
        var feb28_2024_comps = DateComponents()
        feb28_2024_comps.year = 2024
        feb28_2024_comps.month = 2
        feb28_2024_comps.day = 28
        let feb28_2024 = calendar.date(from: feb28_2024_comps)!

        var mar1_2024_comps = DateComponents()
        mar1_2024_comps.year = 2024
        mar1_2024_comps.month = 3
        mar1_2024_comps.day = 1
        let mar1_2024 = calendar.date(from: mar1_2024_comps)!

        let leapGoal = SavingsGoal(
            title: "Leap Goal",
            targetAmount: Decimal(1000),
            targetDate: mar1_2024,
            createdDate: feb28_2024
        )
        XCTAssertEqual(leapGoal.remainingDays(from: feb28_2024, calendar: calendar), 2)

        // Non-Leap Year 2025: Feb 28 to March 1 -> 1 day
        var feb28_2025_comps = DateComponents()
        feb28_2025_comps.year = 2025
        feb28_2025_comps.month = 2
        feb28_2025_comps.day = 28
        let feb28_2025 = calendar.date(from: feb28_2025_comps)!

        var mar1_2025_comps = DateComponents()
        mar1_2025_comps.year = 2025
        mar1_2025_comps.month = 3
        mar1_2025_comps.day = 1
        let mar1_2025 = calendar.date(from: mar1_2025_comps)!

        let nonLeapGoal = SavingsGoal(
            title: "Non-Leap Goal",
            targetAmount: Decimal(1000),
            targetDate: mar1_2025,
            createdDate: feb28_2025
        )
        XCTAssertEqual(nonLeapGoal.remainingDays(from: feb28_2025, calendar: calendar), 1)

        // Past target date -> 0 days
        let pastDate = calendar.date(byAdding: .day, value: -10, to: feb28_2025)!
        XCTAssertEqual(nonLeapGoal.remainingDays(from: pastDate, calendar: calendar), 11)
        let futureRef = calendar.date(byAdding: .day, value: 5, to: mar1_2025)!
        XCTAssertEqual(nonLeapGoal.remainingDays(from: futureRef, calendar: calendar), 0)
    }

    // MARK: - Progress, Completion, & Over-Contribution

    func testProgressFractionAndCompletion() {
        let calendar = Calendar.current
        let today = Date()
        let target = calendar.date(byAdding: .day, value: 10, to: today)!

        var goal = SavingsGoal(
            title: "Laptop",
            targetAmount: Decimal(100000),
            targetDate: target,
            createdDate: today
        )

        XCTAssertEqual(goal.progressFraction, 0.0)
        XCTAssertFalse(goal.isCompleted)

        // 50% contribution
        goal.contributions.append(GoalContribution(amount: Decimal(50000)))
        XCTAssertEqual(goal.progressFraction, 0.5, accuracy: 0.0001)
        XCTAssertEqual(goal.remainingAmount, Decimal(50000))
        XCTAssertFalse(goal.isCompleted)

        // 100% completion
        goal.contributions.append(GoalContribution(amount: Decimal(50000)))
        XCTAssertEqual(goal.progressFraction, 1.0, accuracy: 0.0001)
        XCTAssertEqual(goal.remainingAmount, Decimal.zero)
        XCTAssertTrue(goal.isCompleted)
        XCTAssertEqual(goal.currentDailyPace(from: today, calendar: calendar), Decimal.zero)

        // Over-contribution
        goal.contributions.append(GoalContribution(amount: Decimal(20000)))
        XCTAssertEqual(goal.confirmedSaved, Decimal(120000))
        XCTAssertEqual(goal.remainingAmount, Decimal.zero, "Remaining amount cannot be negative")
        XCTAssertEqual(goal.progressFraction, 1.0, "Progress fraction is clamped at 1.0")
        XCTAssertTrue(goal.isCompleted)
    }

    func testZeroTargetAmountHandling() {
        let goal = SavingsGoal(
            title: "Zero Goal",
            targetAmount: .zero,
            targetDate: Date()
        )

        XCTAssertEqual(goal.progressFraction, 0.0)
        XCTAssertFalse(goal.isCompleted)
        XCTAssertEqual(goal.remainingAmount, .zero)
        XCTAssertEqual(goal.currentDailyPace(), .zero)
    }

    // MARK: - Same-Day Multiple Contributions & Aggregations

    func testMultipleContributionsOnSameDay() {
        let calendar = Calendar.current
        let today = Date()
        let startOfDay = calendar.startOfDay(for: today)
        let target = calendar.date(byAdding: .day, value: 30, to: startOfDay)!

        var goal = SavingsGoal(
            title: "Gadget Fund",
            targetAmount: Decimal(10000),
            targetDate: target,
            createdDate: startOfDay
        )

        let morning = startOfDay.addingTimeInterval(3600 * 8)
        let noon = startOfDay.addingTimeInterval(3600 * 12)
        let evening = startOfDay.addingTimeInterval(3600 * 18)

        goal.contributions.append(GoalContribution(date: morning, amount: Decimal(300), note: "Morning"))
        goal.contributions.append(GoalContribution(date: noon, amount: Decimal(200), note: "Noon"))
        goal.contributions.append(GoalContribution(date: evening, amount: Decimal(500), note: "Evening"))

        let dayTotal = goal.contributionAmount(on: startOfDay, calendar: calendar)
        XCTAssertEqual(dayTotal, Decimal(1000), "Three same-day contributions should sum to 1000")
        XCTAssertEqual(goal.totalContributionDaysCount, 1, "Should count as 1 distinct contribution day")
    }

    // MARK: - Historical Snapshot Preservation

    func testHistoricalSnapshotPreservation() {
        let calendar = Calendar.current
        let today = Date()
        let day1 = calendar.date(byAdding: .day, value: -5, to: today)!
        let targetDate = calendar.date(byAdding: .day, value: 20, to: today)!

        var goal = SavingsGoal(
            title: "Vacation",
            targetAmount: Decimal(20000),
            targetDate: targetDate,
            createdDate: day1
        )

        let day1Key = SavingsGoal.dateKey(for: day1, calendar: calendar)
        goal.dailySnapshots[day1Key] = Decimal(112)

        // Day 1: Met target
        goal.contributions.append(GoalContribution(date: day1, amount: Decimal(112)))
        XCTAssertEqual(goal.comparisonForDate(day1, calendar: calendar), .targetReached)

        // Today: Huge deposit
        goal.contributions.append(GoalContribution(date: today, amount: Decimal(18000)))

        // Day 1 historical target must remain unaffected by future changes
        let day1HistoricalTarget = goal.targetForDate(day1, calendar: calendar)
        XCTAssertEqual(day1HistoricalTarget, Decimal(112), "Historical snapshot target should remain ₹112")
        XCTAssertEqual(goal.comparisonForDate(day1, calendar: calendar), .targetReached)
    }

    func testSnapshotTodayTarget() {
        let calendar = Calendar.current
        let today = Date()
        let pastDate = calendar.date(byAdding: .day, value: -10, to: today)!
        let targetDate = calendar.date(byAdding: .day, value: 10, to: today)!

        var goal = SavingsGoal(
            title: "Bike",
            targetAmount: Decimal(10000),
            targetDate: targetDate,
            createdDate: pastDate
        )

        let todayKey = SavingsGoal.dateKey(for: today, calendar: calendar)
        goal.dailySnapshots.removeValue(forKey: todayKey)
        XCTAssertNil(goal.dailySnapshots[todayKey], "Snapshot for today should be nil prior to calling snapshotTodayTarget")

        goal.snapshotTodayTarget(calendar: calendar)
        XCTAssertNotNil(goal.dailySnapshots[todayKey], "Snapshot for today should be recorded after calling snapshotTodayTarget")
        XCTAssertEqual(goal.dailySnapshots[todayKey], Decimal(1000), "Recorded today target should match current daily pace of ₹1000")
    }

    // MARK: - DayTargetComparison Tests

    func testComparisonForDateCases() {
        let calendar = Calendar.current
        let today = Date()
        let targetDate = calendar.date(byAdding: .day, value: 10, to: today)!

        var goal = SavingsGoal(
            title: "Test Goal",
            targetAmount: Decimal(1000),
            targetDate: targetDate,
            createdDate: today
        )
        let todayKey = SavingsGoal.dateKey(for: today, calendar: calendar)
        goal.dailySnapshots[todayKey] = Decimal(100)

        // 1. Neutral (no contribution)
        XCTAssertEqual(goal.comparisonForDate(today, calendar: calendar), .neutral)

        // 2. Below Target
        goal.contributions = [GoalContribution(date: today, amount: Decimal(50))]
        XCTAssertEqual(goal.comparisonForDate(today, calendar: calendar), .belowTarget)

        // 3. Target Reached
        goal.contributions = [GoalContribution(date: today, amount: Decimal(100))]
        XCTAssertEqual(goal.comparisonForDate(today, calendar: calendar), .targetReached)

        // 4. Above Target
        goal.contributions = [GoalContribution(date: today, amount: Decimal(150))]
        XCTAssertEqual(goal.comparisonForDate(today, calendar: calendar), .aboveTarget)
    }

    // MARK: - Consistency Statistics & Streaks

    func testDaysMeetingTargetCount() {
        let calendar = Calendar.current
        let today = Date()
        let d1 = calendar.date(byAdding: .day, value: -3, to: today)!
        let d2 = calendar.date(byAdding: .day, value: -2, to: today)!
        let d3 = calendar.date(byAdding: .day, value: -1, to: today)!
        let targetDate = calendar.date(byAdding: .day, value: 10, to: today)!

        var goal = SavingsGoal(
            title: "Consistency Goal",
            targetAmount: Decimal(10000),
            targetDate: targetDate,
            createdDate: d1
        )

        goal.dailySnapshots[SavingsGoal.dateKey(for: d1, calendar: calendar)] = Decimal(100)
        goal.dailySnapshots[SavingsGoal.dateKey(for: d2, calendar: calendar)] = Decimal(100)
        goal.dailySnapshots[SavingsGoal.dateKey(for: d3, calendar: calendar)] = Decimal(100)

        // d1 met target (100 >= 100), d2 missed (50 < 100), d3 exceeded (150 >= 100)
        goal.contributions = [
            GoalContribution(date: d1, amount: Decimal(100)),
            GoalContribution(date: d2, amount: Decimal(50)),
            GoalContribution(date: d3, amount: Decimal(150))
        ]

        XCTAssertEqual(goal.totalContributionDaysCount, 3)
        XCTAssertEqual(goal.daysMeetingTargetCount, 2)
    }

    func testConsecutiveContributionStreak() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: today)!
        let threeDaysAgo = calendar.date(byAdding: .day, value: -3, to: today)!
        let targetDate = calendar.date(byAdding: .day, value: 30, to: today)!

        var goal = SavingsGoal(
            title: "Streak Goal",
            targetAmount: Decimal(5000),
            targetDate: targetDate,
            createdDate: threeDaysAgo
        )

        // Case 1: No contributions -> streak 0
        XCTAssertEqual(goal.consecutiveContributionStreak, 0)

        // Case 2: Contributed today, yesterday, and two days ago -> streak 3
        goal.contributions = [
            GoalContribution(date: twoDaysAgo, amount: Decimal(50)),
            GoalContribution(date: yesterday, amount: Decimal(50)),
            GoalContribution(date: today, amount: Decimal(50))
        ]
        XCTAssertEqual(goal.consecutiveContributionStreak, 3)

        // Case 3: Contributed yesterday and two days ago, but NOT today -> streak 2 (grace day for today)
        goal.contributions = [
            GoalContribution(date: twoDaysAgo, amount: Decimal(50)),
            GoalContribution(date: yesterday, amount: Decimal(50))
        ]
        XCTAssertEqual(goal.consecutiveContributionStreak, 2)

        // Case 4: Gap yesterday -> streak broken -> 0
        goal.contributions = [
            GoalContribution(date: twoDaysAgo, amount: Decimal(50))
        ]
        XCTAssertEqual(goal.consecutiveContributionStreak, 0)
    }

    // MARK: - Codable Round-Trip

    func testSavingsGoalCodableRoundTrip() throws {
        let calendar = Calendar.current
        let today = Date()
        let target = calendar.date(byAdding: .day, value: 45, to: today)!

        let contribution = GoalContribution(date: today, amount: Decimal(1250), note: "First deposit")
        let breakdown = CostBreakdownItem(title: "Flight", amount: Decimal(25000))

        let original = SavingsGoal(
            id: UUID(),
            title: "Japan Trip",
            destination: "Tokyo & Kyoto",
            targetAmount: Decimal(200000),
            targetDate: target,
            createdDate: today,
            contributions: [contribution],
            costBreakdown: [breakdown],
            dailySnapshots: ["2026-10-06": Decimal(4444)]
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(SavingsGoal.self, from: data)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.title, original.title)
        XCTAssertEqual(decoded.destination, original.destination)
        XCTAssertEqual(decoded.targetAmount, original.targetAmount)
        XCTAssertEqual(decoded.contributions.count, 1)
        XCTAssertEqual(decoded.costBreakdown.count, 1)
        XCTAssertEqual(decoded.dailySnapshots["2026-10-06"], Decimal(4444))
    }
}
