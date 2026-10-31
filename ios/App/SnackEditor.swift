import SwiftUI

struct SnackEditor: View {
    @Environment(\.dismiss) private var dismiss
    let item: SnackEdit
    let archive: SnackArchive
    let save: (SnackRecord, String) -> Bool
    @State private var date: Date
    @State private var name: String
    @State private var maker: String
    @State private var others: [OtherEntry]
    @State private var saveFailed = false

    init(item: SnackEdit, archive: SnackArchive, save: @escaping (SnackRecord, String) -> Bool) {
        self.item = item; self.archive = archive; self.save = save
        _date = State(initialValue: item.date)
        _name = State(initialValue: item.record.name)
        _maker = State(initialValue: item.record.maker)
        _others = State(initialValue: item.record.otherSnacks.map { OtherEntry(name: $0) })
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if item.allowsDateChange {
                        DatePicker("Day", selection: $date, displayedComponents: .date).accessibilityIdentifier("entry-date")
                    } else {
                        Text(item.day).accessibilityIdentifier("fixed-entry-date")
                    }
                }
                Section("Snack") {
                    SuggestionField(title: "Snack name", value: $name, archive: archive, identifier: "snack-name")
                    SuggestionField(title: "Maker (optional)", value: $maker, archive: archive, identifier: "snack-maker")
                }
                Section {
                    ForEach($others) { $entry in
                        SuggestionField(title: "Other snack", value: $entry.name, archive: archive,
                                        identifier: "other-snack-\(others.firstIndex { $0.id == entry.id } ?? 0)")
                    }.onDelete { others.remove(atOffsets: $0) }
                    Button("Add another snack") { others.append(OtherEntry(name: "")) }
                        .accessibilityIdentifier("add-other")
                } header: { Text("Other snacks") } footer: { Text("Each line is a separate snack eaten during this event.") }
                if saveFailed {
                    Text("Couldn’t save. Your changes are still here; please retry.").foregroundStyle(.red)
                }
            }
            .navigationTitle(item.index == nil ? "Add snack" : "Edit snack").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.accessibilityIdentifier("cancel-snack") }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let clean: (String) -> String = { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                        let record = SnackRecord(name: clean(name), maker: clean(maker), otherSnacks: others.map { clean($0.name) }.filter { !$0.isEmpty })
                        if save(record, SnackDates.key(for: date)) { dismiss() } else { saveFailed = true }
                    }.disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .accessibilityIdentifier("save-snack")
                }
            }
        }
    }
}

private struct OtherEntry: Identifiable { let id = UUID(); var name: String }

private struct SuggestionField: View {
    let title: String
    @Binding var value: String
    let archive: SnackArchive
    let identifier: String
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            if focused {
                ForEach(archive.suggestions(value), id: \.self) { suggestion in
                    Button {
                        value = suggestion
                        focused = false
                    } label: { Label(suggestion, systemImage: "arrow.up.left").font(.subheadline).frame(maxWidth: .infinity, alignment: .leading) }
                    .buttonStyle(.borderless).accessibilityIdentifier("suggestion-\(suggestion)")
                }
            }
            TextField(title, text: $value).focused($focused).autocorrectionDisabled()
                .accessibilityIdentifier(identifier)
        }.padding(.vertical, 2)
    }
}
