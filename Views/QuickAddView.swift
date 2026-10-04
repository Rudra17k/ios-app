import SwiftUI

struct QuickAddView: View {
    @ObservedObject var store: ExpenseStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var amountString: String = ""
    @State private var selectedCategory: ExpenseCategory = .food
    @State private var note: String = ""
    @State private var date: Date = Date()
    @State private var showErrorAlert = false
    @State private var errorMessage = ""

    @FocusState private var isAmountFocused: Bool

    private var parsedAmount: Decimal? {
        guard let decimal = CurrencyHelper.shared.parseDecimal(from: amountString), decimal > 0 else {
            return nil
        }
        return decimal
    }

    private var isFormValid: Bool {
        parsedAmount != nil
    }

    private let quickPresets: [Decimal] = [50, 100, 200, 500, 1000]

    private let columns = [
        GridItem(.adaptive(minimum: 84, maximum: 120), spacing: 10)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Large Amount Input Display
                    amountInputCard

                    // Quick Increment Presets
                    quickPresetChips

                    // Category Selection Grid
                    categorySelectionSection

                    // Optional Note & Date Section
                    detailsSection

                    // Primary Save Action
                    saveButton
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            }
            .navigationTitle("Quick Capture")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                isAmountFocused = true
            }
            .alert("Invalid Amount", isPresented: $showErrorAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }

    // MARK: - Amount Input Card
    private var amountInputCard: some View {
        VStack(spacing: 8) {
            Text("Amount Spent")
                .font(.subheadline)
                .foregroundColor(.secondary)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("₹")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)

                TextField("0", text: $amountString)
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .keyboardType(.decimalPad)
                    .focused($isAmountFocused)
                    .multilineTextAlignment(.leading)
                    .minimumScaleFactor(0.6)
                    .accessibilityLabel("Expense amount in rupees")
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(16)
        }
    }

    // MARK: - Quick Presets
    private var quickPresetChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(quickPresets, id: \.self) { preset in
                    Button {
                        let current = parsedAmount ?? 0
                        let updated = current + preset
                        amountString = NSDecimalNumber(decimal: updated).stringValue
                        HapticsManager.shared.lightFeedback()
                    } label: {
                        Text("+₹\(NSDecimalNumber(decimal: preset).intValue)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Color(.tertiarySystemBackground))
                            .foregroundColor(.primary)
                            .clipShape(Capsule())
                    }
                    .accessibilityLabel("Add \(NSDecimalNumber(decimal: preset).intValue) rupees")
                }
            }
            .padding(.horizontal, 2)
        }
    }

    // MARK: - Category Grid
    private var categorySelectionSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Select Category")
                .font(.headline)
                .foregroundColor(.primary)

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(ExpenseCategory.allCases) { category in
                    Button {
                        selectedCategory = category
                        HapticsManager.shared.lightFeedback()
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: category.iconName)
                                .font(.system(size: 20, weight: .semibold))
                            Text(category.rawValue)
                                .font(.caption)
                                .fontWeight(.medium)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 6)
                        .background(
                            selectedCategory == category
                                ? category.color.opacity(0.18)
                                : Color(.secondarySystemBackground)
                        )
                        .foregroundColor(
                            selectedCategory == category
                                ? category.color
                                : .primary
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(
                                    selectedCategory == category ? category.color : Color.clear,
                                    lineWidth: 2
                                )
                        )
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(category.rawValue)
                    .accessibilityAddTraits(selectedCategory == category ? .isSelected : [])
                }
            }
        }
    }

    // MARK: - Note and Date
    private var detailsSection: some View {
        VStack(spacing: 10) {
            HStack {
                Image(systemName: "note.text")
                    .foregroundColor(.secondary)
                TextField("Note (optional, e.g. Metro, Chai, Veggies)", text: $note)
                    .font(.body)
            }
            .padding(14)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)

            DatePicker("Date & Time", selection: $date, displayedComponents: [.date, .hourAndMinute])
                .datePickerStyle(.compact)
                .padding(12)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
        }
    }

    // MARK: - Save Action
    private var saveButton: some View {
        Button(action: saveExpense) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                Text("Save Expense")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(isFormValid ? Color.blue : Color.gray.opacity(0.3))
            .foregroundColor(.white)
            .cornerRadius(14)
        }
        .disabled(!isFormValid)
        .padding(.top, 4)
    }

    private func saveExpense() {
        guard let amount = parsedAmount else {
            errorMessage = "Please enter a valid amount greater than ₹0."
            showErrorAlert = true
            return
        }

        HapticsManager.shared.successFeedback()
        let added = store.addExpense(amount: amount, category: selectedCategory, date: date, note: note)

        // Notification if configured & app inactive
        NotificationManager.shared.postExpenseLoggedNotification(
            amount: added.amount,
            category: added.category,
            isAppActive: true // user is active in app, so avoid disruptive system notification
        )

        dismiss()
    }
}
