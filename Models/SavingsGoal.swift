import Foundation

struct CostBreakdownItem: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var amount: Decimal

    init(id: UUID = UUID(), title: String, amount: Decimal) {
        self.id = id
        self.title = title
        self.amount = amount
    }

    enum CodingKeys: String, CodingKey {
        case id, title, amount
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.title = try container.decode(String.self, forKey: .title)
        if let dec = try? container.decode(Decimal.self, forKey: .amount) {
            self.amount = dec
        } else if let dbl = try? container.decode(Double.self, forKey: .amount) {
            self.amount = Decimal(dbl)
        } else {
            self.amount = .zero
        }
    }
}

struct GoalContribution: Identifiable, Codable, Equatable {
    let id: UUID
    var date: Date
    var amount: Decimal
    var note: String?

    init(id: UUID = UUID(), date: Date = Date(), amount: Decimal, note: String? = nil) {
        self.id = id
        self.date = date
        self.amount = amount
        self.note = note
    }

    enum CodingKeys: String, CodingKey {
        case id, date, amount, note
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.date = try container.decode(Date.self, forKey: .date)
        self.note = try container.decodeIfPresent(String.self, forKey: .note)
        if let dec = try? container.decode(Decimal.self, forKey: .amount) {
            self.amount = dec
        } else if let dbl = try? container.decode(Double.self, forKey: .amount) {
            self.amount = Decimal(dbl)
        } else {
            self.amount = .zero
        }
    }
}

enum DayTargetComparison: String {
    case aboveTarget = "Above Target"
    case targetReached = "Target Reached"
    case belowTarget = "Below Target"
    case neutral = "No Contribution"
}

struct SavingsGoal: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var destination: String?
    var targetAmount: Decimal
    var targetDate: Date
    var createdDate: Date
    var contributions: [GoalContribution]
    var costBreakdown: [CostBreakdownItem]
    /// Preserved historical snapshots of the daily target for each calendar day: "yyyy-MM-dd" -> targetPace
    var dailySnapshots: [String: Decimal]

    init(
        id: UUID = UUID(),
        title: String,
        destination: String? = nil,
        targetAmount: Decimal,
        targetDate: Date,
        createdDate: Date = Date(),
        contributions: [GoalContribution] = [],
        costBreakdown: [CostBreakdownItem] = [],
        dailySnapshots: [String: Decimal] = [:]
    ) {
        self.id = id
        self.title = title
        self.destination = (destination?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false) ? destination : nil
        self.targetAmount = targetAmount
        self.targetDate = targetDate
        self.createdDate = createdDate
        self.contributions = contributions
        self.costBreakdown = costBreakdown
        self.dailySnapshots = dailySnapshots

        // Snapshot initial target pace for creation day if not present
        ensureInitialSnapshotRecorded()
    }

    // MARK: - Computed Properties
    var confirmedSaved: Decimal {
        contributions.reduce(Decimal.zero) { $0 + $1.amount }
    }

    var remainingAmount: Decimal {
        max(Decimal.zero, targetAmount - confirmedSaved)
    }

    var isCompleted: Bool {
        confirmedSaved >= targetAmount && targetAmount > 0
    }

    var progressFraction: Double {
        guard targetAmount > 0 else { return 0 }
        let saved = NSDecimalNumber(decimal: confirmedSaved).doubleValue
        let target = NSDecimalNumber(decimal: targetAmount).doubleValue
        return min(1.0, max(0.0, saved / target))
    }

    func remainingDays(from referenceDate: Date = Date(), calendar: Calendar = .current) -> Int {
        let startOfRef = calendar.startOfDay(for: referenceDate)
        let startOfTarget = calendar.startOfDay(for: targetDate)
        let diff = calendar.dateComponents([.day], from: startOfRef, to: startOfTarget).day ?? 0
        return max(0, diff)
    }

    /// Calculates pace for future days starting from reference date
    func currentDailyPace(from referenceDate: Date = Date(), calendar: Calendar = .current) -> Decimal {
        let remaining = remainingAmount
        guard remaining > 0 else { return .zero }
        let days = remainingDays(from: referenceDate, calendar: calendar)
        // If target date is today or has passed, daily pace is the full remaining amount
        let activeDays = max(1, days)
        return Self.calculateDailyPace(remaining: remaining, days: activeDays)
    }

    static func calculateDailyPace(remaining: Decimal, days: Int) -> Decimal {
        guard remaining > 0, days > 0 else { return .zero }
        let nsRemaining = NSDecimalNumber(decimal: remaining)
        let nsDays = NSDecimalNumber(value: days)
        let quotient = nsRemaining.dividing(by: nsDays)
        let handler = NSDecimalNumberHandler(
            roundingMode: .up,
            scale: 0,
            raiseOnExactness: false,
            raiseOnOverflow: false,
            raiseOnUnderflow: false,
            raiseOnDivideByZero: false
        )
        return quotient.rounding(accordingToBehavior: handler) as Decimal
    }

    // MARK: - Snapshot & Historical Truth
    static func dateKey(for date: Date, calendar: Calendar = .current) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private mutating func ensureInitialSnapshotRecorded() {
        let todayKey = Self.dateKey(for: createdDate)
        if dailySnapshots[todayKey] == nil {
            let initialDays = max(1, remainingDays(from: createdDate))
            let initialPace = Self.calculateDailyPace(remaining: targetAmount, days: initialDays)
            dailySnapshots[todayKey] = initialPace
        }
    }

    /// Gets the historical target that applied on that specific calendar day
    func targetForDate(_ date: Date, calendar: Calendar = .current) -> Decimal {
        let key = Self.dateKey(for: date, calendar: calendar)
        if let recorded = dailySnapshots[key] {
            return recorded
        }
        // Fallback for dates without explicit snapshot: return current daily pace
        return currentDailyPace(from: date, calendar: calendar)
    }

    /// Records today's target pace before or during modifications
    mutating func snapshotTodayTarget(calendar: Calendar = .current) {
        let today = Date()
        let key = Self.dateKey(for: today, calendar: calendar)
        if dailySnapshots[key] == nil {
            let pace = currentDailyPace(from: today, calendar: calendar)
            dailySnapshots[key] = pace
        }
    }

    // MARK: - Contributions on specific date
    func contributionAmount(on date: Date, calendar: Calendar = .current) -> Decimal {
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            return .zero
        }

        return contributions
            .filter { $0.date >= startOfDay && $0.date < endOfDay }
            .reduce(Decimal.zero) { $0 + $1.amount }
    }

    func comparisonForDate(_ date: Date, calendar: Calendar = .current) -> DayTargetComparison {
        let dayContribution = contributionAmount(on: date, calendar: calendar)
        let dayTarget = targetForDate(date, calendar: calendar)

        if dayContribution == .zero {
            return .neutral
        } else if dayTarget > .zero && dayContribution > dayTarget {
            return .aboveTarget
        } else if dayTarget > .zero && dayContribution == dayTarget {
            return .targetReached
        } else if dayTarget > .zero && dayContribution < dayTarget {
            return .belowTarget
        } else {
            // Contributed when target was zero (e.g. goal reached)
            return .targetReached
        }
    }

    // MARK: - Consistency Statistics
    var totalContributionDaysCount: Int {
        var daysSet = Set<String>()
        let calendar = Calendar.current
        for c in contributions where c.amount > 0 {
            daysSet.insert(Self.dateKey(for: c.date, calendar: calendar))
        }
        return daysSet.count
    }

    var daysMeetingTargetCount: Int {
        var count = 0
        var daysSet = Set<String>()
        let calendar = Calendar.current
        for c in contributions where c.amount > 0 {
            let key = Self.dateKey(for: c.date, calendar: calendar)
            if !daysSet.contains(key) {
                daysSet.insert(key)
                let totalForDay = contributionAmount(on: c.date, calendar: calendar)
                let targetForDay = targetForDate(c.date, calendar: calendar)
                if totalForDay >= targetForDay && targetForDay > 0 {
                    count += 1
                }
            }
        }
        return count
    }

    var consecutiveContributionStreak: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var streak = 0
        var checkDate = today

        // Check if contributed today
        if contributionAmount(on: today, calendar: calendar) > 0 {
            streak += 1
            checkDate = calendar.date(byAdding: .day, value: -1, to: today) ?? today
        } else {
            // Check yesterday
            let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today
            if contributionAmount(on: yesterday, calendar: calendar) > 0 {
                streak += 1
                checkDate = calendar.date(byAdding: .day, value: -2, to: today) ?? today
            } else {
                return 0
            }
        }

        while streak < 365 {
            if contributionAmount(on: checkDate, calendar: calendar) > 0 {
                streak += 1
                guard let prev = calendar.date(byAdding: .day, value: -1, to: checkDate) else { break }
                checkDate = prev
            } else {
                break
            }
        }
        return streak
    }
}
