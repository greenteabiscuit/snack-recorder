import SwiftUI
import UniformTypeIdentifiers

enum SnackMode: String, CaseIterable, Identifiable {
    case suggestions = "Suggestions", month = "Month", rankings = "Rankings", search = "Search"
    var id: Self { self }
    var icon: String {
        switch self { case .suggestions: "lightbulb"; case .month: "list.bullet"; case .rankings: "star"; case .search: "magnifyingglass" }
    }
}

@MainActor
final class SnackViewModel: ObservableObject {
    @Published private(set) var archive = SnackArchive()
    @Published var error: String?
    @Published private(set) var loaded = false
    @Published var selectedDay = LaunchSettings.today
    @Published var visibleMonth = SnackDates.monthStart(LaunchSettings.today)
    @Published var mode = SnackMode.suggestions
    @Published var rankingYear = SnackDates.calendar.component(.year, from: LaunchSettings.today)
    @Published var query = ""
    @Published var allTimeExpanded = false
    @Published var yearlyExpanded = false
    private let repository: SnackRepository

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let directory = base.appendingPathComponent(LaunchSettings.uiTesting ? "SnackRecorderUITests" : "SnackRecorder", isDirectory: true)
        repository = SnackRepository(url: directory.appendingPathComponent("days.json"))
        #if DEBUG
        if LaunchSettings.uiTesting && ProcessInfo.processInfo.arguments.contains("--reset-data") {
            try? FileManager.default.removeItem(at: directory)
            if ProcessInfo.processInfo.arguments.contains("--seed-data") {
                let seed = SnackArchive(days: [
                    "2025-12-31": [SnackRecord(name: "Cookie", maker: "Bakery")],
                    "2026-10-30": [SnackRecord(name: "cookie", maker: "Bakery", otherSnacks: ["Chips"])],
                    "2026-10-31": [SnackRecord(name: "Cookie", maker: "Tea House", otherSnacks: ["Chocolate", "Cookie"]),
                                   SnackRecord(name: "Apple", maker: "Farm")]
                ])
                try? repository.save(seed)
            } else if ProcessInfo.processInfo.arguments.contains("--tag-layout-fixture") {
                let seed = SnackArchive(days: [
                    "2026-10-30": [SnackRecord(name: "Sample snack", otherSnacks: ["First long tag", "Second long tag", "Third long tag", "Fourth long tag"])],
                    "2026-10-31": [SnackRecord(name: "Next day snack")]
                ])
                try? repository.save(seed)
            }
        }
        #endif
        reload()
    }

    func reload() {
        do { archive = try repository.load(); loaded = true }
        catch {
            loaded = false
            self.error = "Your records could not be loaded. The original file has been kept. \(error.localizedDescription)"
        }
    }

    @discardableResult
    func update(_ change: (inout SnackArchive) throws -> Void) -> Bool {
        guard loaded else { return false }
        do {
            var candidate = archive
            try change(&candidate)
            try repository.save(candidate)
            archive = candidate
            return true
        } catch { self.error = error.localizedDescription; return false }
    }

    func select(_ date: Date) { selectedDay = date; visibleMonth = SnackDates.monthStart(date) }
    func jump(to date: Date) { select(date); mode = .month }
    func today() { withAnimation(.easeInOut(duration: 0.18)) { jump(to: LaunchSettings.today) } }
    func shift(_ amount: Int) {
        withAnimation(.easeInOut(duration: 0.18)) {
            if mode == .month { visibleMonth = SnackDates.shifted(visibleMonth, by: amount, component: .month) }
            else { select(SnackDates.shifted(selectedDay, by: amount, component: .day)) }
        }
    }
    func defaultAddDate() -> Date {
        SnackDates.monthStart(selectedDay) == visibleMonth ? selectedDay : visibleMonth
    }
}

struct SnackEdit: Identifiable {
    let id = UUID()
    var date: Date
    let index: Int?
    let allowsDateChange: Bool
    var record: SnackRecord
    var day: String { SnackDates.key(for: date) }
}

struct SnackListView: View {
    @ObservedObject var model: SnackViewModel
    @Environment(\.scenePhase) private var scenePhase
    @State private var edit: SnackEdit?
    @State private var calendarPresented = false
    @State private var transferPresented = false
    @State private var exporting = false
    @State private var export = SnackDocument(data: Data(), contentType: .commaSeparatedText)
    @State private var exportName = "snack-recorder"

    var body: some View {
        NavigationStack {
            TabView(selection: $model.mode) {
                ForEach(SnackMode.allCases) { mode in
                    screen(mode)
                        .tabItem { Label(mode.rawValue, systemImage: mode.icon) }
                        .tag(mode)
                }
            }
            .navigationTitle("Snack Recorder")
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: scenePhase) { _, phase in
                if phase == .background { edit = nil; calendarPresented = false; transferPresented = false }
            }
            .toolbar {
                ToolbarItemGroup(placement: .topBarLeading) {
                    Button("Today", systemImage: "scope") { model.today() }
                        .accessibilityIdentifier("go-today")
                    Button("Choose snack day", systemImage: "calendar") { calendarPresented = true }
                        .accessibilityIdentifier("show-calendar")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Export CSV", systemImage: "tablecells") {
                            export = SnackDocument(data: Data(model.archive.csv().utf8), contentType: .commaSeparatedText)
                            exportName = "snack-recorder"; exporting = true
                        }.accessibilityIdentifier("export-csv")
                        Button("Back up as JSON", systemImage: "externaldrive") {
                            do {
                                export = SnackDocument(data: try model.archive.encoded(), contentType: .json)
                                exportName = "snack-recorder-backup"; exporting = true
                            } catch { model.error = error.localizedDescription }
                        }
                        Button("Import records", systemImage: "square.and.arrow.down") { transferPresented = true }
                            .accessibilityIdentifier("import-records")
                    } label: { Label("Files", systemImage: "square.and.arrow.up") }
                    .accessibilityIdentifier("files-menu").disabled(!model.loaded)
                }
            }
            .sheet(item: $edit) { item in
                SnackEditor(item: item, archive: model.archive) { record, day in
                    model.update { try $0.save(record, day: day, index: item.index) }
                }.privacyProtected()
            }
            .sheet(isPresented: $calendarPresented) {
                NavigationStack {
                    SnackCalendar(model: model) { date in model.jump(to: date); calendarPresented = false }
                        .navigationTitle("Choose snack day").navigationBarTitleDisplayMode(.inline)
                        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { calendarPresented = false } } }
                }.presentationDetents([.large]).privacyProtected()
            }
            .sheet(isPresented: $transferPresented) { SnackTransferView(model: model).privacyProtected() }
            .fileExporter(isPresented: $exporting, document: export, contentType: export.contentType, defaultFilename: exportName) { result in
                if case .failure(let error) = result { model.error = error.localizedDescription }
            }
            .alert("Couldn’t complete that", isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })) {
                Button("OK") { model.error = nil }
            } message: { Text(model.error ?? "") }
        }
    }

    @ViewBuilder private func screen(_ mode: SnackMode) -> some View {
        if !model.loaded {
            ContentUnavailableView {
                Label("Records unavailable", systemImage: "exclamationmark.triangle")
            } description: {
                Text("Your stored file has been kept. Try loading it again before editing or importing.")
            } actions: { Button("Try again") { model.reload() } }
        } else {
            switch mode {
            case .suggestions: SnackSuggestionsView(model: model, edit: $edit)
            case .month: MonthlySnacksView(model: model, edit: $edit)
            case .rankings: SnackRankingsView(model: model)
            case .search: SnackSearchView(model: model, edit: $edit)
            }
        }
    }
}

struct SnackDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.commaSeparatedText, .json] }
    var data: Data
    var contentType: UTType
    init(data: Data, contentType: UTType) { self.data = data; self.contentType = contentType }
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else { throw CocoaError(.fileReadCorruptFile) }
        self.data = data; contentType = configuration.contentType
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}

struct SnackSlidingPage<Content: View>: View {
    let date: Date
    private let content: (Date) -> Content
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var displayedDate: Date
    @State private var movingForward = true

    init(date: Date, @ViewBuilder content: @escaping (Date) -> Content) {
        self.date = date
        self.content = content
        _displayedDate = State(initialValue: date)
    }

    var body: some View {
        ZStack(alignment: .top) {
            // A fixed date keeps the departing page's records intact during the slide.
            content(displayedDate)
                .id(displayedDate)
                .transition(reduceMotion ? .opacity : .asymmetric(
                    insertion: .move(edge: movingForward ? .trailing : .leading),
                    removal: .move(edge: movingForward ? .leading : .trailing)
                ))
        }
        .clipped()
        .onChange(of: date) { oldDate, newDate in
            movingForward = newDate > oldDate
            withAnimation(.easeInOut(duration: reduceMotion ? 0.15 : 0.28)) {
                displayedDate = newDate
            }
        }
    }
}

extension View {
    func privacyProtected() -> some View { modifier(PrivacyProtection()) }

    func snackSwipe(_ action: @escaping (Int) -> Void) -> some View {
        simultaneousGesture(DragGesture(minimumDistance: 30).onEnded { value in
            let x = value.translation.width, y = value.translation.height
            if abs(x) >= 72 && abs(x) > abs(y) * 1.5 { action(x < 0 ? 1 : -1) }
        })
    }
}

private struct PrivacyProtection: ViewModifier {
    @Environment(\.scenePhase) private var phase
    func body(content: Content) -> some View {
        content.overlay {
            if phase != .active {
                ZStack {
                    SnackTheme.background.ignoresSafeArea()
                    Label("Snack Recorder", systemImage: "lock.fill").font(.title2.bold())
                }
            }
        }
    }
}
