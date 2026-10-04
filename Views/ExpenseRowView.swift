import SwiftUI

struct ExpenseRowView: View {
    let expense: Expense
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "en_IN")
        return formatter
    }()

    private var formattedAmount: String {
        CurrencyHelper.shared.format(expense.amount)
    }

    private var formattedDate: String {
        Self.dateFormatter.string(from: expense.date)
    }

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                // Stack vertically on accessibility sizes so text never clips
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 12) {
                        categoryBadge
                        VStack(alignment: .leading, spacing: 2) {
                            Text(expense.category.rawValue)
                                .font(.headline)
                                .foregroundColor(.primary)
                            Text(formattedDate)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    if let note = expense.note, !note.isEmpty {
                        Text(note)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }

                    Text(formattedAmount)
                        .font(.system(.headline, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                }
                .padding(.vertical, 8)
            } else {
                // Standard horizontal row
                HStack(spacing: 14) {
                    categoryBadge

                    VStack(alignment: .leading, spacing: 4) {
                        Text(expense.category.rawValue)
                            .font(.headline)
                            .foregroundColor(.primary)

                        if let note = expense.note, !note.isEmpty {
                            Text(note)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }

                        Text(formattedDate)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer(minLength: 8)

                    Text(formattedAmount)
                        .font(.system(.headline, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .layoutPriority(1)
                }
                .padding(.vertical, 6)
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(expense.category.rawValue), \(formattedAmount), \(formattedDate)\(expense.note.map { ", \($0)" } ?? "")")
    }

    private var categoryBadge: some View {
        ZStack {
            Circle()
                .fill(expense.category.color.opacity(0.16))
                .frame(width: 44, height: 44)
            Image(systemName: expense.category.iconName)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(expense.category.color)
        }
        .accessibilityHidden(true)
    }
}
