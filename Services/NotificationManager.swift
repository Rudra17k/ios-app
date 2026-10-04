import Foundation
import UserNotifications
import Combine

final class NotificationManager: ObservableObject {
    static let shared = NotificationManager()

    @Published var isAuthorized: Bool = false
    @Published var notifyOnExpenseLogged: Bool {
        didSet {
            UserDefaults.standard.set(notifyOnExpenseLogged, forKey: "notifyOnExpenseLogged")
            if notifyOnExpenseLogged {
                requestPermissionIfNeeded()
            }
        }
    }

    @Published var dailySavingsReminder: Bool {
        didSet {
            UserDefaults.standard.set(dailySavingsReminder, forKey: "dailySavingsReminder")
            if dailySavingsReminder {
                requestPermissionIfNeeded { [weak self] granted in
                    if granted { self?.scheduleDailyReminder() }
                }
            } else {
                cancelDailyReminder()
            }
        }
    }

    @Published var reminderHour: Int {
        didSet {
            UserDefaults.standard.set(reminderHour, forKey: "reminderHour")
            if dailySavingsReminder {
                scheduleDailyReminder()
            }
        }
    }

    @Published var reminderMinute: Int {
        didSet {
            UserDefaults.standard.set(reminderMinute, forKey: "reminderMinute")
            if dailySavingsReminder {
                scheduleDailyReminder()
            }
        }
    }

    private init() {
        self.notifyOnExpenseLogged = UserDefaults.standard.bool(forKey: "notifyOnExpenseLogged")
        self.dailySavingsReminder = UserDefaults.standard.bool(forKey: "dailySavingsReminder")
        let savedHour = UserDefaults.standard.integer(forKey: "reminderHour")
        self.reminderHour = savedHour == 0 ? 20 : savedHour // default 8:00 PM
        self.reminderMinute = UserDefaults.standard.integer(forKey: "reminderMinute")

        checkAuthorizationStatus()
    }

    func checkAuthorizationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.isAuthorized = settings.authorizationStatus == .authorized
            }
        }
    }

    func requestPermissionIfNeeded(completion: ((Bool) -> Void)? = nil) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .notDetermined:
                UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
                    DispatchQueue.main.async {
                        self.isAuthorized = granted
                        completion?(granted)
                    }
                }
            case .authorized, .provisional, .ephemeral:
                DispatchQueue.main.async {
                    self.isAuthorized = true
                    completion?(true)
                }
            case .denied:
                DispatchQueue.main.async {
                    self.isAuthorized = false
                    completion?(false)
                }
            @unknown default:
                DispatchQueue.main.async {
                    self.isAuthorized = false
                    completion?(false)
                }
            }
        }
    }

    func postExpenseLoggedNotification(amount: Decimal, category: ExpenseCategory, isAppActive: Bool) {
        // As per requirements: "Do not show a disruptive system notification while the user is already in the app."
        guard notifyOnExpenseLogged && isAuthorized && !isAppActive else { return }

        let content = UNMutableNotificationContent()
        content.title = "Expense Recorded"
        content.body = "\(category.rawValue): \(CurrencyHelper.shared.format(amount)) has been logged."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil // deliver immediately
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to schedule expense notification: \(error.localizedDescription)")
            }
        }
    }

    func scheduleDailyReminder() {
        cancelDailyReminder()
        guard isAuthorized && dailySavingsReminder else { return }

        var dateComponents = DateComponents()
        dateComponents.hour = reminderHour
        dateComponents.minute = reminderMinute

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

        let content = UNMutableNotificationContent()
        content.title = "Daily Savings Check-in"
        content.body = "Take a moment to review today's spending and savings goals."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "daily_savings_checkin",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to schedule daily check-in: \(error.localizedDescription)")
            }
        }
    }

    func cancelDailyReminder() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["daily_savings_checkin"])
    }
}
