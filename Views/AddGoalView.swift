import SwiftUI

struct AddGoalView: View {
    @ObservedObject var goalStore: GoalStore
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var destination = ""
    @State private var targetAmountString = ""
    @State private var targetDate = Calendar.current.date(byAdding: .month, value: 3, to: Date()) ?? Date()

    // Optional Cost Breakdown
    @State private var breakdownTravel = ""
    @State private var breakdownStay = ""
    @State private var breakdownFood = ""
    @State private var breakdownActivities = ""

    private var parsedTarget: Decimal? {
        guard let dec = CurrencyHelper.shared.parseDecimal(from: targetAmountString), dec > 0 else { return nil }
        return dec
    }

    private var breakdownSum: Decimal {
        var sum: Decimal = .zero
        if let travel = CurrencyHelper.shared.parseDecimal(from: breakdownTravel) { sum += travel }
        if let stay = CurrencyHelper.shared.parseDecimal(from: breakdownStay) { sum += stay }
        if let food = CurrencyHelper.shared.parseDecimal(from: breakdownFood) { sum += food }
        if let act = CurrencyHelper.shared.parseDecimal(from: breakdownActivities) { sum += act }
        return sum
    }

    private var isFormValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty && parsedTarget != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 8) {
                        Text("₹")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundColor(.blue)
                        TextField("Target Amount", text: $targetAmountString)
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .keyboardType(.decimalPad)
                    }
                    .padding(.vertical, 4)

                    DatePicker("Target Date", selection: $targetDate, in: Date()..., displayedComponents: .date)
                } header: {
                    Text("Target")
                }

                Section("Goal Details") {
                    HStack {
                        Image(systemName: "flag.fill")
                            .foregroundColor(.blue)
                            .font(.system(size: 14))
                        TextField("Goal Name (e.g. Goa Trip, MacBook)", text: $title)
                    }
                    HStack {
                        Image(systemName: "mappin.and.ellipse")
                            .foregroundColor(.blue)
                            .font(.system(size: 14))
                        TextField("Destination / Tag (optional)", text: $destination)
                    }
                }

                Section {
                    HStack {
                        Label("Travel / Flights", systemImage: "airplane")
                        Spacer()
                        TextField("₹0", text: $breakdownTravel)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Label("Stay / Hotel", systemImage: "bed.double")
                        Spacer()
                        TextField("₹0", text: $breakdownStay)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Label("Food & Dining", systemImage: "fork.knife")
                        Spacer()
                        TextField("₹0", text: $breakdownFood)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Label("Activities", systemImage: "ticket")
                        Spacer()
                        TextField("₹0", text: $breakdownActivities)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }

                    if breakdownSum > 0 {
                        HStack {
                            Text("Total Estimated Items")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(CurrencyHelper.shared.format(breakdownSum))
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.blue)
                        }
                    }
                } header: {
                    Text("Trip Cost Breakdown (Optional)")
                } footer: {
                    Text("Breaking down your goal makes daily pacing more transparent.")
                }
            }
            .navigationTitle("New Savings Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveGoal()
                    }
                    .disabled(!isFormValid)
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private func saveGoal() {
        guard let target = parsedTarget else { return }

        var items: [CostBreakdownItem] = []
        if let travel = CurrencyHelper.shared.parseDecimal(from: breakdownTravel), travel > 0 {
            items.append(CostBreakdownItem(title: "Travel / Flights", amount: travel))
        }
        if let stay = CurrencyHelper.shared.parseDecimal(from: breakdownStay), stay > 0 {
            items.append(CostBreakdownItem(title: "Stay / Hotel", amount: stay))
        }
        if let food = CurrencyHelper.shared.parseDecimal(from: breakdownFood), food > 0 {
            items.append(CostBreakdownItem(title: "Food & Dining", amount: food))
        }
        if let act = CurrencyHelper.shared.parseDecimal(from: breakdownActivities), act > 0 {
            items.append(CostBreakdownItem(title: "Activities", amount: act))
        }

        goalStore.addGoal(
            title: title.trimmingCharacters(in: .whitespaces),
            destination: destination.isEmpty ? nil : destination.trimmingCharacters(in: .whitespaces),
            targetAmount: target,
            targetDate: targetDate,
            costBreakdown: items
        )

        HapticsManager.shared.successFeedback()
        dismiss()
    }
}
