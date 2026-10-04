import SwiftUI
import UniformTypeIdentifiers

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
                Section("Feedback & Interactions") {
                    Toggle("Haptic Feedback", isOn: $haptics.isHapticsEnabled)
                    Text("Controls tactile clicks on categories, save confirmations, and goal milestones.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                // Section: Notifications (Stage 6)
                Section("Notifications & Reminders") {
                    Toggle("Log Confirmation Alert", isOn: $notifications.notifyOnExpenseLogged)
                    Text("Sends a background confirmation when an expense is logged via Shortcuts or Back Tap. Suppressed when app is active in the foreground.")
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    Toggle("Daily Savings Check-in", isOn: $notifications.dailySavingsReminder)

                    if notifications.dailySavingsReminder {
                        DatePicker(
                            "Reminder Time",
                            selection: reminderBinding,
                            displayedComponents: .hourAndMinute
                        )
                    }
                }

                // Section: Shortcuts & Back Tap (Stage 6)
                Section("Back Tap & iPhone Shortcuts") {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Fast Capture via Back Tap")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Text("1. Open iOS Settings > Accessibility > Touch > Back Tap.\n2. Choose Double Tap or Triple Tap.\n3. Scroll down to Shortcuts and select 'Log Expense'.\n\nNow, double-tapping the back of your iPhone instantly triggers expense capture.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                // Section: Data & Backup (Stage 7)
                Section("Data Management") {
                    Button {
                        exportedCSVText = expenseStore.exportCSV()
                        showingCSVExporter = true
                    } label: {
                        Label("Export Expenses to CSV", systemImage: "square.and.arrow.up")
                    }

                    Button {
                        showingCSVImporter = true
                    } label: {
                        Label("Import Expenses from CSV", systemImage: "square.and.arrow.down")
                    }

                    Button {
                        do {
                            exportedBackupData = try expenseStore.createBackupData()
                            showingBackupExporter = true
                        } catch {
                            alertTitle = "Backup Failed"
                            alertMessage = error.localizedDescription
                            showAlert = true
                        }
                    } label: {
                        Label("Create JSON Backup", systemImage: "archivebox")
                    }

                    Button {
                        showingBackupImporter = true
                    } label: {
                        Label("Restore from JSON Backup", systemImage: "arrow.clockwise")
                    }
                }

                // Section: Privacy & Security (Stage 7)
                Section("Privacy & Zero Cloud Storage") {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("100% On-Device & Offline", systemImage: "lock.shield.fill")
                            .font(.headline)
                            .foregroundColor(.green)

                        Text("Your finances are private. This app does not use third-party tracking, ads, bank connections, cloud sync, or external analytics. All data is kept securely in your iPhone's local sandbox.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                // Section: About & Identity
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("2.0.0 (Local Build)")
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
                case .success(let url):
                    alertTitle = "Export Complete"
                    alertMessage = "Expenses successfully exported to CSV."
                    showAlert = true
                case .failure(let error):
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
            alertTitle = "CSV Import Succeeded"
            alertMessage = "Imported \(result.imported) expenses (\(result.skipped) skipped)."
            showAlert = true
        } catch {
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
            alertTitle = "Backup Restored"
            alertMessage = "Successfully restored \(count) records from backup."
            showAlert = true
        } catch {
            alertTitle = "Restore Failed"
            alertMessage = error.localizedDescription
            showAlert = true
        }
    }
}

// MARK: - File Document Wrappers
struct CSVDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.commaSeparatedText, .plainText] }
    var text: String

    init(text: String) {
        self.text = text
    }

    init(configuration: ReadConfiguration) throws {
        if let data = configuration.file.regularFileContents {
            text = String(decoding: data, as: UTF8.self)
        } else {
            text = ""
        }
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = Data(text.utf8)
        return FileWrapper(regularFileWithContents: data)
    }
}

struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
