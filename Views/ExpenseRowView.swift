import SwiftUI

struct ExpenseRowView: View {
    let expense: Expense
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorScheme) private var colorScheme

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
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 12) {
                        categoryBadge
                        VStack(alignment: .leading, spacing: 3) {
                            Text(expense.category.rawValue)
                                .font(.headline)
                                .foregroundColor(.primary)
                            Text(formattedDate)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    if let note = expense.note, !note.isEmpty {
                        noteBadge(note)
                    }

                    Text(formattedAmount)
                        .font(.system(.title3, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                }
                .padding(.vertical, 8)
            } else {
                // Standard horizontal row
                HStack(spacing: 14) {
                    categoryBadge

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text(expense.category.rawValue)
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundColor(.primary)

                            if let note = expense.note, !note.isEmpty {
                                noteBadge(note)
                            }
                        }

                        Text(formattedDate)
                            .font(.system(size: 12, weight: .regular, design: .rounded))
                            .foregroundColor(.secondary)
                    }

                    Spacer(minLength: 8)

                    Text(formattedAmount)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                        .contentTransition(.numericText())
                        .lineLimit(1)
                        .layoutPriority(1)
                }
                .padding(.vertical, 2)
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(expense.category.rawValue), \(formattedAmount), \(formattedDate)\(expense.note.map { ", \($0)" } ?? "")")
    }

    // MARK: - Category Badge
    private var categoryBadge: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            expense.category.color.opacity(colorScheme == .dark ? 0.28 : 0.15),
                            expense.category.color.opacity(colorScheme == .dark ? 0.14 : 0.06)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .strokeBorder(expense.category.color.opacity(colorScheme == .dark ? 0.3 : 0.15), lineWidth: 1)
                )
                .frame(width: 42, height: 42)

            Image(systemName: expense.category.iconName)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(expense.category.color)
        }
        .accessibilityHidden(true)
    }

    // MARK: - Note Badge
    private func noteBadge(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .medium, design: .rounded))
            .foregroundColor(.secondary)
            .lineLimit(1)
            .truncationMode(.tail)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(Color(uiColor: .tertiarySystemFill))
            )
    }
}
