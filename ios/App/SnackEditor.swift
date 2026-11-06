import SwiftUI

struct SnackEditor: View {
    @Environment(\.dismiss) private var dismiss
    let item: SnackEdit
    let archive: SnackArchive
    let save: (SnackRecord, String) -> Bool
    @State private var date: Date
    @State private var name: String
    @State private var maker: String
    @State private var tags: [String]
    @State private var pendingTag = ""
    @State private var saveFailed = false

    init(item: SnackEdit, archive: SnackArchive, save: @escaping (SnackRecord, String) -> Bool) {
        self.item = item; self.archive = archive; self.save = save
        _date = State(initialValue: item.date)
        _name = State(initialValue: item.record.name)
        _maker = State(initialValue: item.record.maker)
        _tags = State(initialValue: item.record.otherSnacks)
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
                    TagsInput(tags: $tags, pending: $pendingTag, archive: archive)
                } header: { Text("Optional tags") } footer: { Text("Start typing to reuse a tag · Return adds a new one") }
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
                        let record = SnackRecord(name: clean(name), maker: clean(maker), otherSnacks: (tags + [pendingTag]).map(clean).filter { !$0.isEmpty })
                        if save(record, SnackDates.key(for: date)) { dismiss() } else { saveFailed = true }
                    }.disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .accessibilityIdentifier("save-snack")
                }
            }
        }
    }
}

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

private struct TagsInput: View {
    @Binding var tags: [String]
    @Binding var pending: String
    let archive: SnackArchive
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            if focused {
                ForEach(archive.suggestions(pending), id: \.self) { suggestion in
                    Button { add(suggestion) } label: {
                        Label(suggestion, systemImage: "arrow.up.left").font(.subheadline).frame(maxWidth: .infinity, alignment: .leading)
                    }.buttonStyle(.borderless).accessibilityIdentifier("suggestion-\(suggestion)")
                }
            }
            TagFlow {
                ForEach(Array(tags.enumerated()), id: \.offset) { index, tag in
                    SnackTag(text: tag) {
                        Button { tags.remove(at: index) } label: {
                            Image(systemName: "xmark").font(.caption.bold()).frame(width: 28, height: 28)
                        }.buttonStyle(.borderless).accessibilityLabel("Remove \(tag)").accessibilityIdentifier("remove-tag-\(index)")
                    }
                }
                TextField("Add tag", text: $pending).focused($focused).autocorrectionDisabled()
                    .onSubmit { add(pending) }
                    .frame(minWidth: 120, minHeight: 32).accessibilityIdentifier("tag-input")
            }
        }.padding(.vertical, 2)
    }

    private func add(_ value: String) {
        let value = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        tags.append(value)
        pending = ""
        focused = true
    }
}

struct SnackTag<Accessory: View>: View {
    let text: String
    @ViewBuilder var accessory: Accessory

    var body: some View {
        HStack(spacing: 0) {
            Text(text).font(.subheadline).foregroundStyle(.primary).padding(.vertical, 5)
            accessory
        }
        .padding(.leading, 10).padding(.trailing, Accessory.self == EmptyView.self ? 10 : 2)
        .background(SnackTheme.lightOrange, in: Capsule())
        .overlay { Capsule().stroke(SnackTheme.orange) }
    }
}

extension SnackTag where Accessory == EmptyView {
    init(text: String) { self.init(text: text) { EmptyView() } }
}

/// Wraps tags onto new lines when the row is full.
struct TagFlow: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(width: proposal.width ?? .infinity, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let arrangement = arrange(width: bounds.width, subviews: subviews)
        for (subview, frame) in zip(subviews, arrangement.frames) {
            subview.place(at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY), proposal: ProposedViewSize(frame.size))
        }
    }

    private func arrange(width: CGFloat, subviews: Subviews) -> (frames: [CGRect], size: CGSize) {
        var frames: [CGRect] = []
        var x: CGFloat = 0, y: CGFloat = 0, lineHeight: CGFloat = 0, usedWidth: CGFloat = 0
        for subview in subviews {
            var size = subview.sizeThatFits(.unspecified)
            if size.width > width { size = subview.sizeThatFits(ProposedViewSize(width: width, height: nil)) }
            if x > 0 && x + size.width > width {
                x = 0; y += lineHeight + spacing; lineHeight = 0
            }
            frames.append(CGRect(origin: CGPoint(x: x, y: y), size: size))
            x += size.width + spacing
            usedWidth = max(usedWidth, x - spacing)
            lineHeight = max(lineHeight, size.height)
        }
        return (frames, CGSize(width: width.isFinite ? width : usedWidth, height: y + lineHeight))
    }
}
