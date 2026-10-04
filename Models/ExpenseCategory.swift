import SwiftUI

enum ExpenseCategory: String, CaseIterable, Identifiable, Codable {
    case food = "Food"
    case transport = "Transport"
    case groceries = "Groceries"
    case bills = "Bills"
    case health = "Health"
    case shopping = "Shopping"
    case other = "Other"

    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .food: return "fork.knife"
        case .transport: return "car.fill"
        case .groceries: return "cart.fill"
        case .bills: return "doc.text.fill"
        case .health: return "heart.fill"
        case .shopping: return "bag.fill"
        case .other: return "ellipsis.circle.fill"
        }
    }

    var colorName: String {
        switch self {
        case .food: return "orange"
        case .transport: return "blue"
        case .groceries: return "green"
        case .bills: return "purple"
        case .health: return "red"
        case .shopping: return "pink"
        case .other: return "gray"
        }
    }

    var color: Color {
        switch self {
        case .food: return Color.orange
        case .transport: return Color.blue
        case .groceries: return Color.green
        case .bills: return Color.purple
        case .health: return Color.red
        case .shopping: return Color.pink
        case .other: return Color.gray
        }
    }

    var accessibilityDescription: String {
        return "\(rawValue) category"
    }
}
