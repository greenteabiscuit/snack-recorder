import SwiftUI
import UniformTypeIdentifiers

struct SnackTransferView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var model: SnackViewModel
    @State private var choosingFile = false
    @State private var pending: SnackImport?
    @State private var filename = ""
    @State private var error: String?
    @State private var completed: String?
    private var preview: (archive: SnackArchive, added: Int, skipped: Int)? {
        guard let pending else { return nil }
        return try? pending.merged(into: model.archive)
    }

    var body: some View {
        NavigationStack {
            List {
                if let completed {
                    Section {
                        Label(completed, systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                            .accessibilityIdentifier("import-success")
                        Button("Done") { dismiss() }
                    }
                } else {
                    Section {
                        Text("Choose an Android Snack Recorder CSV export or a Snack Recorder JSON backup. You can review the records before saving them.")
                        Button("Choose CSV or JSON file", systemImage: "doc") { choosingFile = true }
                            .accessibilityIdentifier("choose-import-file")
                    }
                    if let pending, let preview {
                        Section("Import preview") {
                            Text(filename)
                            Text("\(preview.added) new events · \(preview.skipped) existing events skipped")
                                .accessibilityIdentifier("import-counts")
                            Text("Existing records stay in place. Re-importing the same file does not add the same events twice.")
                                .font(.footnote).foregroundStyle(.secondary)
                            if pending.usesCSV && pending.hasOtherSnacks {
                                Text("Android CSV joins other snacks using ‘; ’. This import splits that separator. Review those entries if a snack name itself contains ‘; ’. JSON backups preserve names exactly.")
                                    .font(.footnote).foregroundStyle(.secondary)
                            }
                            Button("Import \(preview.added) events") {
                                let success = model.update { $0 = preview.archive }
                                if success { completed = "Imported \(preview.added) snack events." }
                                else { error = model.error ?? "Couldn’t save the import."; model.error = nil }
                            }.disabled(preview.added == 0).accessibilityIdentifier("confirm-import")
                            ForEach(Array(pending.archive.events.prefix(20))) { event in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(event.day).font(.caption).foregroundStyle(.secondary)
                                    Text(event.record.name)
                                    if !event.record.maker.isEmpty { Text(event.record.maker).font(.caption) }
                                    if !event.record.otherSnacks.isEmpty {
                                        Text("Other: " + event.record.otherSnacks.joined(separator: "; ")).font(.caption)
                                    }
                                }
                            }
                            if pending.archive.events.count > 20 { Text("Showing the first 20 events.").foregroundStyle(.secondary) }
                        }
                    }
                    if let error { Text(error).foregroundStyle(.red).accessibilityIdentifier("import-error") }
                }
            }
            .navigationTitle("Import records").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
            .fileImporter(isPresented: $choosingFile, allowedContentTypes: [.commaSeparatedText, .json]) { result in
                do {
                    let url = try result.get()
                    let accessed = url.startAccessingSecurityScopedResource()
                    defer { if accessed { url.stopAccessingSecurityScopedResource() } }
                    let data = try Data(contentsOf: url)
                    try prepare(data: data, isCSV: url.pathExtension.lowercased() == "csv", name: url.lastPathComponent)
                } catch { pending = nil; self.error = error.localizedDescription }
            }
            .task {
                #if DEBUG
                // UI tests inject a file at the importer boundary; parsing and merge use production code.
                if LaunchSettings.uiTesting && ProcessInfo.processInfo.arguments.contains("--preview-test-import") {
                    do {
                        let csv = "date,snack,maker,other_snacks\n2026-10-01,Rice crackers,Market,Tea; Almonds\n2026-10-01,Rice crackers,Market,Tea; Almonds\n"
                        try prepare(data: Data(csv.utf8), isCSV: true, name: "android-export.csv")
                    } catch { self.error = error.localizedDescription }
                }
                #endif
            }
        }
    }

    private func prepare(data: Data, isCSV: Bool, name: String) throws {
        pending = try SnackImport(data: data, isCSV: isCSV)
        filename = name; error = nil
    }
}
