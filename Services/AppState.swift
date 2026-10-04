import SwiftUI
import Combine

final class AppState: ObservableObject {
    static let shared = AppState()

    @Published var shouldShowQuickAdd: Bool = false

    func handle(url: URL) {
        guard let scheme = url.scheme?.lowercased(), scheme == "expensetracker" else {
            return
        }

        // Handles expensetracker://add or expensetracker://quick-add or expensetracker:///add
        let host = url.host?.lowercased() ?? ""
        let path = url.path.lowercased()

        if host == "add" || host == "quick-add" || path.contains("add") || host.isEmpty {
            DispatchQueue.main.async {
                self.shouldShowQuickAdd = true
            }
        }
    }
}
