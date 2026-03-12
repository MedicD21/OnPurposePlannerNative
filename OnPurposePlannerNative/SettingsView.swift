import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settings: AppSettings
    @ObservedObject     var store:   PlannerStore
    @Environment(\.dismiss) var dismiss

    @State private var showExportSheet  = false
    @State private var showImportPicker = false
    @State private var exportURL:     URL?
    @State private var alertMessage = ""
    @State private var showAlert    = false

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

                // MARK: Info
                Section {
                    Text("Export bundles all drawings, sticky notes, and attachments into a single JSON file. Share it via AirDrop, Files, or email and import it on another device to restore your planner.")
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
            DocumentPickerView { data, _ in
                importData(data)
                showImportPicker = false
            }
        }
        .alert("Data Backup", isPresented: $showAlert) {
            Button("OK") {}
        } message: {
            Text(alertMessage)
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
}

// MARK: - UIActivityViewController wrapper

struct ActivityView: UIViewControllerRepresentable {
    var items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
