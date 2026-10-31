import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class SnackViewModel: ObservableObject {
    @Published private(set) var archive = SnackArchive()
    @Published var error: String?
    @Published private(set) var loaded = false
    private let repository: SnackRepository

    init() {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("SnackRecorder", isDirectory: true)
        repository = SnackRepository(url: directory.appendingPathComponent("days.json"))
        do {
            archive = try repository.load()
            loaded = true
        } catch {
            self.error = "Your records could not be loaded. The original file has been kept. \(error.localizedDescription)"
        }
    }

    func update(_ change: (inout SnackArchive) throws -> Void) -> Bool {
        guard loaded else { return false }
        do {
            var candidate = archive
            try change(&candidate)
            try repository.save(candidate)
            archive = candidate
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }
}

private struct SnackEdit: Identifiable {
    let id = UUID()
    let day: String
    let index: Int?
    var record: SnackRecord
}

struct SnackListView: View {
    @StateObject private var model = SnackViewModel()
    @State private var date = Date()
    @State private var edit: SnackEdit?
    @State private var exporting = false
    @State private var export = CSVDocument(text: "")

    private var day: String { SnackDates.key(for: date) }
    private var records: [SnackRecord] { model.archive.days[day, default: []] }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    DatePicker("Day", selection: $date, displayedComponents: .date)
                    Button("Today") { date = Date() }
                }
                Section("\(records.count) snacks") {
                    if records.isEmpty {
                        Text("No snacks recorded for this day.").foregroundStyle(.secondary)
                    }
                    ForEach(Array(records.enumerated()), id: \.offset) { index, record in
                        Button {
                            edit = SnackEdit(day: day, index: index, record: record)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(record.name).foregroundStyle(.primary)
                                if !record.maker.isEmpty { Text(record.maker).font(.subheadline).foregroundStyle(.secondary) }
                                if !record.otherSnacks.isEmpty {
                                    Text("Other: " + record.otherSnacks.joined(separator: "; "))
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                        .accessibilityHint("Edit snack")
                    }
                    .onDelete { offsets in
                        _ = model.update { archive in
                            for index in offsets.sorted(by: >) { try archive.remove(day: day, index: index) }
                        }
                    }
                }
            }
            .navigationTitle("Snack Recorder")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Export CSV", systemImage: "square.and.arrow.up") {
                        export = CSVDocument(text: model.archive.csv())
                        exporting = true
                    }.disabled(!model.loaded)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add snack", systemImage: "plus") {
                        edit = SnackEdit(day: day, index: nil, record: SnackRecord(name: ""))
                    }.disabled(!model.loaded)
                }
            }
            .sheet(item: $edit) { item in
                SnackEditor(item: item) { record in
                    model.update { try $0.save(record, day: item.day, index: item.index) }
                }
            }
            .fileExporter(isPresented: $exporting, document: export, contentType: .commaSeparatedText,
                          defaultFilename: "snack-recorder") { result in
                if case .failure(let error) = result { model.error = error.localizedDescription }
            }
            .alert("Couldn’t complete that", isPresented: Binding(
                get: { model.error != nil }, set: { if !$0 { model.error = nil } }
            )) { Button("OK") { model.error = nil } } message: { Text(model.error ?? "") }
        }
    }
}

private struct SnackEditor: View {
    @Environment(\.dismiss) private var dismiss
    let item: SnackEdit
    let save: (SnackRecord) -> Bool
    @State private var name: String
    @State private var maker: String
    @State private var others: [String]
    @State private var saveFailed = false

    init(item: SnackEdit, save: @escaping (SnackRecord) -> Bool) {
        self.item = item
        self.save = save
        _name = State(initialValue: item.record.name)
        _maker = State(initialValue: item.record.maker)
        _others = State(initialValue: item.record.otherSnacks)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(item.day) {
                    TextField("Snack name", text: $name)
                    TextField("Maker (optional)", text: $maker)
                }
                Section("Other snacks") {
                    ForEach(others.indices, id: \.self) { index in
                        TextField("Snack", text: $others[index])
                    }.onDelete { others.remove(atOffsets: $0) }
                    Button("Add another snack") { others.append("") }
                }
                if saveFailed { Text("Couldn’t save. Your changes are still here; please retry.").foregroundStyle(.red) }
            }
            .navigationTitle(item.index == nil ? "Add snack" : "Edit snack")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let record = SnackRecord(name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                                                 maker: maker, otherSnacks: others.filter { !$0.isEmpty })
                        if save(record) { dismiss() } else { saveFailed = true }
                    }.disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

struct CSVDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.commaSeparatedText] }
    var text: String
    init(text: String) { self.text = text }
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents, let text = String(data: data, encoding: .utf8) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.text = text
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}
