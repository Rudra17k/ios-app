import SwiftUI

struct QuickAddView: View {
    @ObservedObject var store: ExpenseStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
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
        GridItem(.adaptive(minimum: 76, maximum: 110), spacing: 10)
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Color(uiColor: .systemGroupedBackground)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Hero Amount Input Display
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
            }
            .navigationTitle("Quick Capture")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.secondary)
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

    // MARK: - Hero Amount Input Card
    private var amountInputCard: some View {
        VStack(spacing: 8) {
            HStack {
                Text("AMOUNT SPENT")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(.secondary)
                Spacer()
                if !amountString.isEmpty {
                    Button {
                        amountString = ""
                        HapticsManager.shared.lightFeedback()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary.opacity(0.7))
                            .font(.system(size: 18))
                    }
                }
            }

            HStack(alignment: .center, spacing: 6) {
                Text("₹")
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .foregroundColor(selectedCategory.color)
                    .animation(.easeInOut(duration: 0.2), value: selectedCategory)

                TextField("0", text: $amountString)
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .keyboardType(.decimalPad)
                    .focused($isAmountFocused)
                    .multilineTextAlignment(.leading)
                    .minimumScaleFactor(0.5)
                    .accessibilityLabel("Expense amount in rupees")
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .glassCard(cornerRadius: 22, strokeOpacity: 0.12, shadowRadius: 10)
    }

    // MARK: - Quick Presets
    private var quickPresetChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(quickPresets, id: \.self) { preset in
                    Button {
                        let current = parsedAmount ?? 0
                        let updated = current + preset
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                            amountString = NSDecimalNumber(decimal: updated).stringValue
                        }
                        HapticsManager.shared.lightFeedback()
                    } label: {
                        HStack(spacing: 2) {
                            Text("+₹")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                            Text("\(NSDecimalNumber(decimal: preset).intValue)")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color(uiColor: .secondarySystemGroupedBackground))
                        .foregroundColor(.primary)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                        )
                    }
                    .buttonStyle(BouncyButtonStyle(scaleAmount: 0.92))
                    .accessibilityLabel("Add \(NSDecimalNumber(decimal: preset).intValue) rupees")
                }
            }
            .padding(.horizontal, 2)
        }
    }

    // MARK: - Category Grid
    private var categorySelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("CATEGORY")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(.secondary)
                .padding(.leading, 4)

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(ExpenseCategory.allCases) { category in
                    let isSelected = selectedCategory == category
                    Button {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.7)) {
                            selectedCategory = category
                        }
                        HapticsManager.shared.lightFeedback()
                    } label: {
                        VStack(spacing: 8) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(
                                        isSelected
                                            ? Color.white.opacity(0.25)
                                            : category.color.opacity(colorScheme == .dark ? 0.25 : 0.14)
                                    )
                                    .frame(width: 40, height: 40)

                                Image(systemName: category.iconName)
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(isSelected ? .white : category.color)
                                    .symbolRenderingMode(.hierarchical)
                            }

                            Text(category.rawValue)
                                .font(.system(size: 12, weight: isSelected ? .bold : .medium, design: .rounded))
                                .foregroundColor(isSelected ? .white : .primary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(
                                    isSelected
                                        ? AnyShapeStyle(
                                            LinearGradient(
                                                colors: [category.color, category.color.opacity(0.85)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                          )
                                        : AnyShapeStyle(Color(uiColor: .secondarySystemGroupedBackground))
                                )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .strokeBorder(
                                    isSelected
                                        ? Color.white.opacity(0.3)
                                        : Color.primary.opacity(0.06),
                                    lineWidth: 1
                                )
                        )
                        .shadow(
                            color: isSelected ? category.color.opacity(0.35) : Color.black.opacity(0.03),
                            radius: isSelected ? 8 : 4,
                            x: 0,
                            y: isSelected ? 4 : 2
                        )
                    }
                    .buttonStyle(SubtlePressStyle(scaleAmount: 0.94))
                    .accessibilityLabel(category.rawValue)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
        }
    }

    // MARK: - Note and Date Details
    private var detailsSection: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: "note.text")
                    .foregroundColor(selectedCategory.color)
                    .font(.system(size: 16, weight: .semibold))
                TextField("Note (optional, e.g. Metro, Chai, Veggies)", text: $note)
                    .font(.system(.body, design: .rounded))
            }
            .padding(14)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
            )

            HStack {
                Label("Date & Time", systemImage: "calendar")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundColor(.secondary)
                Spacer()
                DatePicker("", selection: $date, displayedComponents: [.date, .hourAndMinute])
                    .datePickerStyle(.compact)
                    .labelsHidden()
            }
            .padding(12)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
            )
        }
    }

    // MARK: - Save Action
    private var saveButton: some View {
        Button(action: saveExpense) {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 20, weight: .bold))
                Text("Save Expense")
                    .font(.system(.headline, design: .rounded))
                    .fontWeight(.bold)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(
                isFormValid
                    ? LinearGradient(
                        colors: [Color.blue, Color.blue.opacity(0.85)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    : LinearGradient(
                        colors: [Color.gray.opacity(0.3), Color.gray.opacity(0.2)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
            )
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(
                color: isFormValid ? Color.blue.opacity(0.35) : Color.clear,
                radius: 10,
                x: 0,
                y: 4
            )
        }
        .disabled(!isFormValid)
        .buttonStyle(BouncyButtonStyle(scaleAmount: 0.96))
        .padding(.top, 6)
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
            isAppActive: true
        )

        dismiss()
    }
}
