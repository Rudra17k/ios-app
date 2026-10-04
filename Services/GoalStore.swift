import Foundation
import Combine

final class GoalStore: ObservableObject {
    @Published var goals: [SavingsGoal] = []
    @Published var selectedGoalId: UUID? = nil
    @Published var errorMessage: String? = nil

    private let filename = "goals.json"

    init() {
        loadGoals()
    }

    private var fileURL: URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0].appendingPathComponent(filename)
    }

    func loadGoals() {
        let url = fileURL
        guard FileManager.default.fileExists(atPath: url.path) else {
            self.goals = []
            return
        }

        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let decoded = try decoder.decode([SavingsGoal].self, from: data)
            self.goals = decoded.sorted { $0.createdDate > $1.createdDate }
        } catch {
            print("Failed to load goals: \(error.localizedDescription)")
            self.errorMessage = "Failed to load goals: \(error.localizedDescription)"
            self.goals = []
        }
    }

    func saveGoals() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(goals)
            try data.write(to: fileURL, options: [.atomicWrite, .completeFileProtection])
        } catch {
            print("Failed to save goals: \(error.localizedDescription)")
            self.errorMessage = "Failed to save goals: \(error.localizedDescription)"
        }
    }

    @discardableResult
    func addGoal(
        title: String,
        destination: String?,
        targetAmount: Decimal,
        targetDate: Date,
        costBreakdown: [CostBreakdownItem] = []
    ) -> SavingsGoal {
        let newGoal = SavingsGoal(
            title: title,
            destination: destination,
            targetAmount: targetAmount,
            targetDate: targetDate,
            costBreakdown: costBreakdown
        )
        goals.insert(newGoal, at: 0)
        saveGoals()
        return newGoal
    }

    func updateGoal(_ updated: SavingsGoal) {
        if let idx = goals.firstIndex(where: { $0.id == updated.id }) {
            goals[idx] = updated
            saveGoals()
        }
    }

    func deleteGoal(id: UUID) {
        goals.removeAll { $0.id == id }
        saveGoals()
    }

    @discardableResult
    func addContribution(
        to goalId: UUID,
        amount: Decimal,
        date: Date = Date(),
        note: String? = nil
    ) -> Bool {
        guard let idx = goals.firstIndex(where: { $0.id == goalId }), amount > 0 else {
            return false
        }

        var goal = goals[idx]
        let priorProgress = goal.progressFraction

        // 1. Snapshot today's target before recording the contribution so past & today's truth is preserved
        goal.snapshotTodayTarget()

        // 2. Add contribution
        let contribution = GoalContribution(date: date, amount: amount, note: note)
        goal.contributions.append(contribution)

        // 3. Update store
        goals[idx] = goal
        saveGoals()

        // 4. Milestone feedback
        let newProgress = goal.progressFraction
        if newProgress >= 1.0 && priorProgress < 1.0 {
            HapticsManager.shared.milestoneCelebration()
        } else if (newProgress >= 0.75 && priorProgress < 0.75) ||
                  (newProgress >= 0.50 && priorProgress < 0.50) ||
                  (newProgress >= 0.25 && priorProgress < 0.25) {
            HapticsManager.shared.successFeedback()
        } else {
            HapticsManager.shared.lightFeedback()
        }

        return true
    }

    func deleteContribution(contributionId: UUID, from goalId: UUID) {
        guard let idx = goals.firstIndex(where: { $0.id == goalId }) else { return }
        goals[idx].contributions.removeAll { $0.id == contributionId }
        saveGoals()
    }
}
