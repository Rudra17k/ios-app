import SwiftUI
import UniformTypeIdentifiers

// MARK: - File Exporter Documents
struct CSVDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.commaSeparatedText, .plainText] }
    var text: String = ""

    init(text: String = "") {
        self.text = text
    }

    init(configuration: ReadConfiguration) throws {
        if let data = configuration.file.regularFileContents {
            text = String(decoding: data, as: UTF8.self)
        }
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = Data(text.utf8)
        return FileWrapper(regularFileWithContents: data)
    }
}

struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data = Data()

    init(data: Data = Data()) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        if let data = configuration.file.regularFileContents {
            self.data = data
        }
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        return FileWrapper(regularFileWithContents: data)
    }
}

struct SettingsPrivacyView: View {
    @ObservedObject var expenseStore: ExpenseStore
    @ObservedObject var haptics = HapticsManager.shared
    @ObservedObject var notifications = NotificationManager.shared

    @State private var showingCSVExporter = false
    @State private var showingCSVImporter = false
    @State private var showingBackupExporter = false
    @State private var showingBackupImporter = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var showAlert = false

    @State private var exportedCSVText: String = ""
    @State private var exportedBackupData: Data = Data()

    var body: some View {
        NavigationStack {
            Form {
                // Section: Haptics & Feel
                Section {
                    Toggle(isOn: $haptics.isHapticsEnabled) {
                        settingsRowLabel(
                            title: "Haptic Feedback",
                            icon: "hand.tap.fill",
                            color: .orange
                        )
                    }
                } header: {
                    Text("Interactions")
                } footer: {
                    Text("Provides tactile clicks on category buttons, quick presets, save confirmations, and goal milestones.")
                }

                // Section: Notifications (Stage 6)
                Section {
                    Toggle(isOn: $notifications.notifyOnExpenseLogged) {
                        settingsRowLabel(
                            title: "Log Confirmation Alert",
                            icon: "bell.badge.fill",
                            color: .red
                        )
                    }

                    Toggle(isOn: $notifications.dailySavingsReminder) {
                        settingsRowLabel(
                            title: "Daily Savings Check-in",
                            icon: "clock.fill",
                            color: .indigo
                        )
                    }

                    if notifications.dailySavingsReminder {
                        DatePicker(
                            "Reminder Time",
                            selection: reminderBinding,
                            displayedComponents: .hourAndMinute
                        )
                    }
                } header: {
                    Text("Notifications & Reminders")
                } footer: {
                    Text("Log confirmations are automatically silenced when the app is active in the foreground.")
                }

                // Section: Shortcuts & Back Tap (Stage 6)
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 12) {
                            settingsIcon(icon: "iphone.radiowaves.left.and.right", color: .purple)
                            Text("Fast Capture via Back Tap")
                                .font(.system(.body, design: .rounded))
                                .fontWeight(.semibold)
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            stepRow(number: "1", text: "Open iOS Settings > Accessibility > Touch > Back Tap.")
                            stepRow(number: "2", text: "Choose Double Tap or Triple Tap.")
                            stepRow(number: "3", text: "Scroll down to Shortcuts and select 'Log Expense'.")
                        }
                        .padding(.top, 2)

                        Text("Double-tapping the back of your iPhone instantly triggers expense capture.")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Hardware Shortcuts")
                }

                // Section: Data & Backup (Stage 7)
                Section {
                    Button {
                        exportedCSVText = expenseStore.exportCSV()
                        showingCSVExporter = true
                        HapticsManager.shared.lightFeedback()
                    } label: {
                        settingsRowLabel(title: "Export Expenses to CSV", icon: "square.and.arrow.up.fill", color: .blue)
                    }

                    Button {
                        showingCSVImporter = true
                        HapticsManager.shared.lightFeedback()
                    } label: {
                        settingsRowLabel(title: "Import Expenses from CSV", icon: "square.and.arrow.down.fill", color: .teal)
                    }

                    Button {
                        do {
                            exportedBackupData = try expenseStore.createBackupData()
                            showingBackupExporter = true
                            HapticsManager.shared.lightFeedback()
                        } catch {
                            alertTitle = "Backup Failed"
                            alertMessage = error.localizedDescription
                            showAlert = true
                        }
                    } label: {
                        settingsRowLabel(title: "Create Full JSON Backup", icon: "archivebox.fill", color: .cyan)
                    }

                    Button {
                        showingBackupImporter = true
                        HapticsManager.shared.lightFeedback()
                    } label: {
                        settingsRowLabel(title: "Restore from JSON Backup", icon: "arrow.clockwise.circle.fill", color: .blue)
                    }
                } header: {
                    Text("Data & Backup")
                }

                // Section: Privacy & Security (Stage 7)
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 10) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Color.green.opacity(0.18))
                                    .frame(width: 32, height: 32)
                                Image(systemName: "lock.shield.fill")
                                    .foregroundColor(.green)
                                    .font(.system(size: 16, weight: .bold))
                            }

                            Text("100% On-Device & Private")
                                .font(.system(.body, design: .rounded))
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                        }

                        Text("Your financial data never leaves your device. No third-party tracking, no ads, no cloud telemetry, and no account requirements. Everything stays encrypted in your iPhone's local sandbox.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineSpacing(2)
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Privacy Architecture")
                }

                // Section: About & Identity
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("2.0.0 (Apple Design Award Edition)")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Architecture")
                        Spacer()
                        Text("Native SwiftUI • iOS 16+")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Settings & Tools")
            .fileExporter(
                isPresented: $showingCSVExporter,
                document: CSVDocument(text: exportedCSVText),
                contentType: .commaSeparatedText,
                defaultFilename: "expenses-\(dateSuffix()).csv"
            ) { result in
                switch result {
                case .success:
                    HapticsManager.shared.successFeedback()
                    alertTitle = "Export Complete"
                    alertMessage = "Expenses successfully exported to CSV."
                    showAlert = true
                case .failure(let error):
                    HapticsManager.shared.warningFeedback()
                    alertTitle = "Export Failed"
                    alertMessage = error.localizedDescription
                    showAlert = true
                }
            }
            .fileImporter(
                isPresented: $showingCSVImporter,
                allowedContentTypes: [.commaSeparatedText, .plainText],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    guard let url = urls.first else { return }
                    importCSV(from: url)
                case .failure(let error):
                    HapticsManager.shared.warningFeedback()
                    alertTitle = "Import Failed"
                    alertMessage = error.localizedDescription
                    showAlert = true
                }
            }
            .fileExporter(
                isPresented: $showingBackupExporter,
                document: BackupDocument(data: exportedBackupData),
                contentType: .json,
                defaultFilename: "expenses-backup-\(dateSuffix()).json"
            ) { result in
                if case .success = result {
                    HapticsManager.shared.successFeedback()
                    alertTitle = "Backup Complete"
                    alertMessage = "Local JSON backup saved."
                    showAlert = true
                }
            }
            .fileImporter(
                isPresented: $showingBackupImporter,
                allowedContentTypes: [.json],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    guard let url = urls.first else { return }
                    restoreBackup(from: url)
                case .failure(let error):
                    HapticsManager.shared.warningFeedback()
                    alertTitle = "Restore Failed"
                    alertMessage = error.localizedDescription
                    showAlert = true
                }
            }
            .alert(alertTitle, isPresented: $showAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
        }
    }

    // MARK: - Row Helpers
    private func settingsRowLabel(title: String, icon: String, color: Color) -> some View {
        HStack(spacing: 12) {
            settingsIcon(icon: icon, color: color)
            Text(title)
                .font(.system(.body, design: .rounded))
                .foregroundColor(.primary)
        }
    }

    private func settingsIcon(icon: String, color: Color) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(color)
                .frame(width: 28, height: 28)
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
        }
    }

    private func stepRow(number: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(number)
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 16, height: 16)
                .background(Color.purple)
                .clipShape(Circle())
            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var reminderBinding: Binding<Date> {
        Binding<Date>(
            get: {
                var comps = DateComponents()
                comps.hour = notifications.reminderHour
                comps.minute = notifications.reminderMinute
                return Calendar.current.date(from: comps) ?? Date()
            },
            set: { newDate in
                let comps = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                notifications.reminderHour = comps.hour ?? 20
                notifications.reminderMinute = comps.minute ?? 0
            }
        )
    }

    private func dateSuffix() -> String {
        let df = DateFormatter()
        df.dateFormat = "yyyyMMdd-HHmm"
        return df.string(from: Date())
    }

    private func importCSV(from url: URL) {
        guard url.startAccessingSecurityScopedResource() else {
            alertTitle = "Permission Error"
            alertMessage = "Cannot access the selected CSV file."
            showAlert = true
            return
        }
        defer { url.stopAccessingSecurityScopedResource() }

        do {
            let content = try String(contentsOf: url, encoding: .utf8)
            let result = try expenseStore.importCSV(content)
            HapticsManager.shared.successFeedback()
            alertTitle = "CSV Import Succeeded"
            alertMessage = "Imported \(result.imported) expenses (\(result.skipped) skipped)."
            showAlert = true
        } catch {
            HapticsManager.shared.warningFeedback()
            alertTitle = "CSV Import Failed"
            alertMessage = error.localizedDescription
            showAlert = true
        }
    }

    private func restoreBackup(from url: URL) {
        guard url.startAccessingSecurityScopedResource() else {
            alertTitle = "Permission Error"
            alertMessage = "Cannot access the selected backup file."
            showAlert = true
            return
        }
        defer { url.stopAccessingSecurityScopedResource() }

        do {
            let data = try Data(contentsOf: url)
            let count = try expenseStore.restoreFromBackup(data: data)
            HapticsManager.shared.successFeedback()
            alertTitle = "Backup Restored"
            alertMessage = "Successfully restored \(count) records from backup."
            showAlert = true
        } catch {
            HapticsManager.shared.warningFeedback()
            alertTitle = "Restore Failed"
            alertMessage = error.localizedDescription
            showAlert = true
        }
    }
}
