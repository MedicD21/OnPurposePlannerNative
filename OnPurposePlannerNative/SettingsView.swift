import SwiftUI
import EventKit

struct SettingsView: View {
    @EnvironmentObject var settings: AppSettings
    @ObservedObject     var store:   PlannerStore
    @Environment(\.dismiss) var dismiss

    @State private var showExportSheet  = false
    @State private var showImportPicker = false
    @State private var exportURL:     URL?
    @State private var alertMessage = ""
    @State private var showAlert    = false
    @State private var integrityMessage = ""
    @State private var showIntegrityAlert = false

    var body: some View {
        NavigationView {
            Form {
                // MARK: Appearance
                Section("Appearance") {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Theme")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        HStack(spacing: 0) {
                            ForEach(ThemeMode.allCases, id: \.self) { mode in
                                themeChip(mode)
                            }
                        }
                        .background(Color(.systemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 9))
                    }
                    .padding(.vertical, 4)
                }

                // MARK: Data Backup
                Section("Data Backup") {
                    Button {
                        exportData()
                    } label: {
                        Label("Export All Data", systemImage: "square.and.arrow.up")
                            .foregroundStyle(.primary)
                    }

                    Button {
                        showImportPicker = true
                    } label: {
                        Label("Import Data", systemImage: "square.and.arrow.down")
                            .foregroundStyle(.primary)
                    }
                }

                // MARK: Data Health
                Section("Data Health") {
                    Button {
                        runIntegrityCheck(cleanOrphans: false)
                    } label: {
                        Label("Run Integrity Check", systemImage: "checklist")
                            .foregroundStyle(.primary)
                    }

                    Button {
                        runIntegrityCheck(cleanOrphans: true)
                    } label: {
                        Label("Clean Orphaned Drawings", systemImage: "trash")
                            .foregroundStyle(.primary)
                    }
                }

                // MARK: Planner Style
                Section("Planner Style") {
                    ForEach(PlannerStyle.allCases, id: \.self) { style in
                        HStack {
                            Image(systemName: style.icon)
                                .foregroundStyle(PlannerTheme.accent)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(style.rawValue)
                                Text(style.description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if settings.plannerStyle == style {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(PlannerTheme.accent)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { settings.plannerStyle = style }
                    }
                    Text("More styles coming in a future update.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // MARK: Calendar
                Section("iOS Calendar") {
                    calendarSection
                }

                // MARK: Info
                Section {
                    Text("Export bundles all drawings, sticky notes, tab markers, and attachments into a single JSON file. Share it via AirDrop, Files, or email and import it on another device to restore your planner.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .sheet(isPresented: $showExportSheet) {
            if let url = exportURL {
                ActivityView(items: [url])
            }
        }
        .sheet(isPresented: $showImportPicker) {
            DocumentPickerView(
                allowedContentTypes: [.json, .item],
                allowedFileExtensions: ["json"],
                maxFileSizeBytes: 100 * 1024 * 1024,
                onPick: { data, _ in
                    importData(data)
                    showImportPicker = false
                },
                onError: { message in
                    alertMessage = message
                    showAlert = true
                    showImportPicker = false
                }
            )
        }
        .alert("Data Backup", isPresented: $showAlert) {
            Button("OK") {}
        } message: {
            Text(alertMessage)
        }
        .alert("Data Integrity", isPresented: $showIntegrityAlert) {
            Button("OK") {}
        } message: {
            Text(integrityMessage)
        }
    }

    // MARK: - Calendar section

    @ViewBuilder
    private var calendarSection: some View {
        let status = store.calendarManager.authStatus
        switch status {
        case .fullAccess:
            let calendars = store.calendarManager.availableCalendars()
            if calendars.isEmpty {
                Text("No calendars found on this device.")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            } else {
                ForEach(calendars, id: \.calendarIdentifier) { cal in
                    let id = cal.calendarIdentifier
                    let enabled = store.showAllCalendars || store.enabledCalendarIDs.contains(id)
                    HStack {
                        Circle()
                            .fill(Color(cgColor: cal.cgColor))
                            .frame(width: 12, height: 12)
                        Text(cal.title)
                        Spacer()
                        Image(systemName: enabled ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(enabled ? PlannerTheme.accent : .secondary)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        // If currently in "show all", seed explicit selections first.
                        if store.showAllCalendars {
                            store.enabledCalendarIDs = Set(calendars.map { $0.calendarIdentifier })
                            store.showAllCalendars = false
                        }
                        if store.enabledCalendarIDs.contains(id) {
                            store.enabledCalendarIDs.remove(id)
                        } else {
                            store.enabledCalendarIDs.insert(id)
                        }
                        // Collapse back to "show all" only when everything is selected.
                        if store.enabledCalendarIDs.count == calendars.count {
                            store.showAllCalendars = true
                            store.enabledCalendarIDs = []
                        }
                    }
                }
                Text("Unchecked calendars are hidden from your planner. You can now hide all calendars too.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

        case .denied, .restricted:
            HStack {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
                Text("Calendar access was denied.")
                    .font(.callout)
            }
            Button("Open Settings to Enable") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }

        default:
            Button("Grant Calendar Access") {
                Task { await store.calendarManager.requestAccess() }
            }
            Text("Allows your iOS calendar events to appear on planner pages.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Theme chip

    private func themeChip(_ mode: ThemeMode) -> some View {
        let selected = settings.themeMode == mode
        return Button {
            settings.themeMode = mode
        } label: {
            VStack(spacing: 4) {
                Image(systemName: mode.icon)
                    .font(.system(size: 18))
                Text(mode.rawValue)
                    .font(.system(size: 11, weight: .medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(selected ? Color(.systemBackground) : Color.clear)
                    .shadow(color: selected ? .black.opacity(0.12) : .clear, radius: 3, x: 0, y: 1)
            )
            .foregroundStyle(selected ? .primary : .secondary)
        }
        .buttonStyle(.plain)
        .padding(3)
    }

    // MARK: - Export / Import

    private func exportData() {
        do {
            let url = try store.exportAllData()
            exportURL = url
            showExportSheet = true
        } catch {
            alertMessage = "Export failed: \(error.localizedDescription)"
            showAlert = true
        }
    }

    private func importData(_ data: Data) {
        do {
            try store.importAllData(data)
            alertMessage = "Import successful! All data has been restored."
        } catch {
            alertMessage = "Import failed — the file may be corrupted or from an incompatible version.\n\n\(error.localizedDescription)"
        }
        showAlert = true
    }

    private func runIntegrityCheck(cleanOrphans: Bool) {
        let report = store.runDataIntegrityCheck(cleanOrphans: cleanOrphans)
        integrityMessage = report.summary
        showIntegrityAlert = true
    }
}

// MARK: - UIActivityViewController wrapper

struct ActivityView: UIViewControllerRepresentable {
    var items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
