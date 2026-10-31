import SwiftUI

struct DailySnacksView: View {
    @ObservedObject var model: SnackViewModel
    @Binding var edit: SnackEdit?
    private var key: String { SnackDates.key(for: model.selectedDay) }
    private var records: [SnackRecord] { model.archive.days[key, default: []] }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Previous day", systemImage: "chevron.left") { model.shift(-1) }.labelStyle(.iconOnly).frame(width: 44, height: 44)
                Spacer(minLength: 0)
                VStack(spacing: 4) {
                    Text(SnackDates.label(model.selectedDay, format: "EEE, MMM d, yyyy")).font(.headline).multilineTextAlignment(.center)
                    Text(key).font(.caption).foregroundStyle(.secondary).accessibilityIdentifier("selected-day")
                }
                Spacer(minLength: 0)
                Button("Next day", systemImage: "chevron.right") { model.shift(1) }.labelStyle(.iconOnly).frame(width: 44, height: 44)
            }.padding(.horizontal)
            List {
                Section("\(records.count) snack\(records.count == 1 ? "" : "s") recorded") {
                    if records.isEmpty { Text("No snacks recorded for this day.").foregroundStyle(.secondary) }
                    ForEach(Array(records.enumerated()), id: \.offset) { index, record in
                        SnackEventRow(day: key, index: index, record: record, model: model, edit: $edit)
                    }
                }
                Section {
                    Button {
                        edit = SnackEdit(date: model.selectedDay, index: nil, allowsDateChange: false, record: SnackRecord(name: ""))
                    } label: { Label("Add snack", systemImage: "plus.circle.fill").font(.headline) }
                    .accessibilityIdentifier("day-add")
                }
            }.accessibilityIdentifier("day-content")
                .snackSwipe { model.shift($0) }
        }.background(SnackTheme.background)
    }
}

struct MonthlySnacksView: View {
    @ObservedObject var model: SnackViewModel
    @Binding var edit: SnackEdit?
    private var dates: [Date] { SnackDates.days(in: model.visibleMonth) }
    private var monthRecords: [[SnackRecord]] { dates.map { model.archive.days[SnackDates.key(for: $0), default: []] } }

    var body: some View {
        VStack(spacing: 0) {
            MonthControls(month: $model.visibleMonth)
            HStack {
                Text("\(monthRecords.reduce(0) { $0 + $1.count }) snack events · \(monthRecords.filter { !$0.isEmpty }.count) snack days")
                    .font(.caption).foregroundStyle(.secondary).accessibilityIdentifier("month-summary")
                Spacer()
                Button("Add snack", systemImage: "plus") {
                    edit = SnackEdit(date: model.defaultAddDate(), index: nil, allowsDateChange: true, record: SnackRecord(name: ""))
                }.font(.subheadline.bold()).accessibilityIdentifier("month-add")
            }.padding(.horizontal).padding(.bottom, 8)
            List {
                ForEach(dates, id: \.self) { date in
                    let key = SnackDates.key(for: date)
                    let records = model.archive.days[key, default: []]
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(SnackDates.label(date, format: "MMM d")).font(.subheadline).foregroundStyle(.primary)
                            Text(SnackDates.label(date, format: "EEE")).font(.caption)
                                .foregroundStyle(weekdayColor(date))
                        }.frame(width: 62, alignment: .leading).padding(.top, 5)
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(Array(records.enumerated()), id: \.offset) { index, record in
                                SnackEventRow(day: key, index: index, record: record, model: model, edit: $edit)
                            }
                            Button {
                                edit = SnackEdit(date: date, index: nil, allowsDateChange: false, record: SnackRecord(name: ""))
                            } label: { Label("Add snack", systemImage: "plus").font(.subheadline) }
                            .accessibilityLabel("Add snack for \(key)").accessibilityIdentifier("month-add-\(key)")
                        }
                    }.padding(.vertical, 3).accessibilityElement(children: .contain).accessibilityIdentifier("month-day-\(key)")
                }
            }.listStyle(.plain).accessibilityIdentifier("month-content")
                .snackSwipe { model.shift($0) }
                .id(SnackDates.key(for: model.visibleMonth))
        }.background(SnackTheme.background)
    }

    private func weekdayColor(_ date: Date) -> Color {
        switch SnackDates.calendar.component(.weekday, from: date) { case 1: .red; case 7: .blue; default: .secondary }
    }
}

struct SnackEventRow: View {
    let day: String
    let index: Int
    let record: SnackRecord
    @ObservedObject var model: SnackViewModel
    @Binding var edit: SnackEdit?
    var showDelete = true

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Button {
                edit = SnackEdit(date: SnackDates.date(for: day)!, index: index, allowsDateChange: false, record: record)
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(record.name).foregroundStyle(.primary).font(.body.weight(.medium))
                    if !record.maker.isEmpty { Text(record.maker).font(.subheadline).foregroundStyle(.secondary) }
                    if !record.otherSnacks.isEmpty {
                        Text("Other: " + record.otherSnacks.joined(separator: "; ")).font(.caption).foregroundStyle(.secondary)
                    }
                }.frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
            }.buttonStyle(.plain).accessibilityIdentifier("edit-\(day)-\(index)").accessibilityHint("Edit snack")
            if showDelete {
                Button(role: .destructive) { model.update { try $0.remove(day: day, index: index) } } label: {
                    Image(systemName: "trash").frame(width: 36, height: 40)
                }.buttonStyle(.borderless).accessibilityLabel("Delete \(record.name)")
                    .accessibilityIdentifier("delete-\(day)-\(index)")
            }
        }
    }
}

struct SnackSearchView: View {
    @ObservedObject var model: SnackViewModel
    @Binding var edit: SnackEdit?
    private var results: [SnackEvent] { model.archive.search(model.query) }

    var body: some View {
        VStack(spacing: 0) {
            TextField("Names, makers, other snacks, or dates", text: $model.query)
                .textFieldStyle(.roundedBorder).textInputAutocapitalization(.never).autocorrectionDisabled()
                .accessibilityIdentifier("search-field").padding()
            List {
                if model.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("Enter a search term to find snack events.").foregroundStyle(.secondary)
                } else {
                    Section("\(results.count) matching event\(results.count == 1 ? "" : "s")") {
                        if results.isEmpty { Text("No matching snack events.").foregroundStyle(.secondary) }
                        ForEach(results) { event in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(event.day).font(.caption).foregroundStyle(.secondary)
                                SnackEventRow(day: event.day, index: event.index, record: event.record, model: model, edit: $edit, showDelete: false)
                            }
                        }
                    }
                }
            }.scrollDismissesKeyboard(.interactively).accessibilityIdentifier("search-results")
        }.background(SnackTheme.background)
    }
}

struct SnackRankingsView: View {
    @ObservedObject var model: SnackViewModel

    var body: some View {
        List {
            DisclosureGroup("All-time rankings", isExpanded: $model.allTimeExpanded) { rankings(year: nil) }
                .accessibilityIdentifier("all-time-rankings")
            DisclosureGroup("Yearly rankings", isExpanded: $model.yearlyExpanded) {
                Picker("Year", selection: $model.rankingYear) {
                    ForEach(SnackDates.yearOptions(now: LaunchSettings.today), id: \.self) { Text(String($0)).tag($0) }
                }.accessibilityIdentifier("ranking-year")
                rankings(year: model.rankingYear)
            }.accessibilityIdentifier("yearly-rankings")
        }.listStyle(.insetGrouped).accessibilityIdentifier("rankings-content")
    }

    @ViewBuilder private func rankings(year: Int?) -> some View {
        ForEach(RankingCategory.allCases, id: \.self) { category in
            VStack(alignment: .leading, spacing: 8) {
                Text(category.rawValue + (year.map { " in \($0)" } ?? " of all time")).font(.subheadline.bold()).padding(.top, 8)
                let rows = Array(model.archive.rankings(category, year: year).prefix(10))
                if rows.isEmpty { Text("No data yet").foregroundStyle(.secondary).font(.subheadline) }
                ForEach(Array(rows.enumerated()), id: \.element.id) { offset, row in
                    HStack {
                        Text("\(offset + 1). \(row.label)")
                        Spacer()
                        Text("\(row.count) time\(row.count == 1 ? "" : "s")").foregroundStyle(SnackTheme.orange).monospacedDigit()
                    }.font(.subheadline).accessibilityElement(children: .combine)
                        .accessibilityIdentifier("ranking-\(year.map(String.init) ?? "all")-\(category)-\(offset)")
                }
            }
        }
    }
}
