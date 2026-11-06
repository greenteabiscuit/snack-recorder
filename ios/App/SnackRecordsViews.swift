import SwiftUI

struct SnackSuggestionsView: View {
    @ObservedObject var model: SnackViewModel
    @Binding var edit: SnackEdit?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                suggestion("1 month ago", component: .month, identifier: "month")
                suggestion("1 year ago", component: .year, identifier: "year")
            }.padding(16)
        }.background(SnackTheme.background).accessibilityIdentifier("suggestions-content")
    }

    private func suggestion(_ title: String, component: Calendar.Component, identifier: String) -> some View {
        let date = SnackDates.shifted(LaunchSettings.today, by: -1, component: component)
        let samples = model.archive.anniversarySamples(around: date, through: LaunchSettings.today)
        return VStack(alignment: .leading, spacing: 0) {
            Button {
                model.jump(to: date)
            } label: {
                HStack {
                    Text(title).font(.headline)
                    Spacer()
                    Text(SnackDates.label(date, format: "MMM d, yyyy"))
                    Image(systemName: "arrow.right")
                }
                .font(.subheadline).frame(minHeight: 44)
            }.accessibilityIdentifier("suggestion-jump-\(identifier)")
            if samples.isEmpty {
                Text("No snack records yet.").foregroundStyle(.secondary).frame(minHeight: 44)
            } else {
                ForEach(samples) { event in
                    HStack(spacing: 8) {
                        Button {
                            if let sampleDate = SnackDates.date(for: event.day) {
                                edit = SnackEdit(date: sampleDate, index: event.index, allowsDateChange: false, record: event.record)
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(event.record.name).font(.subheadline.weight(.medium)).foregroundStyle(.primary).lineLimit(1)
                                if !event.record.maker.isEmpty {
                                    Text(event.record.maker).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                                }
                            }.frame(maxWidth: .infinity, minHeight: 44, alignment: .leading).contentShape(Rectangle())
                        }.buttonStyle(.plain).accessibilityIdentifier("suggestion-record-\(identifier)-\(event.id)")
                        Button(event.day) {
                            if let sampleDate = SnackDates.date(for: event.day) { model.jump(to: sampleDate) }
                        }.font(.caption).frame(minHeight: 44)
                    }.overlay(alignment: .top) { Divider() }
                }
            }
        }.padding(.horizontal, 14)
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    }
}

struct MonthlySnacksView: View {
    @ObservedObject var model: SnackViewModel
    @Binding var edit: SnackEdit?

    var body: some View {
        VStack(spacing: 0) {
            MonthControls(month: $model.visibleMonth)
            SnackSlidingPage(date: model.visibleMonth) { month in
                records(for: month)
            }
            .snackSwipe { model.shift($0) }
        }.background(SnackTheme.background)
    }

    private func records(for month: Date) -> some View {
        let dates = SnackDates.days(in: month)
        let monthRecords = dates.map { model.archive.days[SnackDates.key(for: $0), default: []] }
        return VStack(spacing: 0) {
            HStack {
                Text("\(monthRecords.reduce(0) { $0 + $1.count }) snack events · \(monthRecords.filter { !$0.isEmpty }.count) snack days")
                    .font(.caption).foregroundStyle(.secondary).accessibilityIdentifier("month-summary")
                Spacer()
                Button("Add snack", systemImage: "plus") {
                    edit = SnackEdit(date: model.defaultAddDate(), index: nil, allowsDateChange: true, record: SnackRecord(name: ""))
                }.font(.subheadline.bold()).accessibilityIdentifier("month-add")
            }.padding(.horizontal).padding(.bottom, 8)
            ScrollViewReader { proxy in
            List {
                ForEach(dates, id: \.self) { date in
                    let key = SnackDates.key(for: date)
                    let records = model.archive.days[key, default: []]
                    HStack(alignment: .top, spacing: 12) {
                        if records.isEmpty {
                            HStack(alignment: .top, spacing: 12) {
                                dateLabel(date)
                                Spacer(minLength: 0)
                            }
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .topLeading)
                            .contentShape(Rectangle())
                            .onTapGesture { addSnack(on: date) }
                            .accessibilityElement(children: .ignore)
                            .accessibilityAddTraits(.isButton)
                            .accessibilityAction { addSnack(on: date) }
                            .accessibilityLabel("Add snack for \(key)").accessibilityIdentifier("month-add-\(key)")
                        } else {
                            Button {
                                edit = SnackEdit(date: date, index: nil, allowsDateChange: false, record: SnackRecord(name: ""))
                            } label: { dateLabel(date).contentShape(Rectangle()) }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Add snack for \(key)").accessibilityIdentifier("month-add-\(key)")
                            VStack(alignment: .leading, spacing: 12) {
                                ForEach(Array(records.enumerated()), id: \.offset) { index, record in
                                    SnackEventRow(day: key, index: index, record: record, model: model, edit: $edit)
                                }
                            }
                        }
                    }.padding(.vertical, 3).accessibilityElement(children: .contain).accessibilityIdentifier("month-day-\(key)")
                    .id(key)
                    .listRowBackground(SnackDates.calendar.isDate(date, inSameDayAs: LaunchSettings.today)
                        ? Color(uiColor: .systemGray5)
                        : Color(uiColor: .systemBackground))
                }
            }.listStyle(.plain).accessibilityIdentifier("month-content")
                .onAppear {
                    if SnackDates.monthStart(model.selectedDay) == month {
                        DispatchQueue.main.async { proxy.scrollTo(SnackDates.key(for: model.selectedDay), anchor: .top) }
                    }
                }
                .onChange(of: model.selectedDay) { _, date in
                    if SnackDates.monthStart(date) == month {
                        DispatchQueue.main.async { proxy.scrollTo(SnackDates.key(for: date), anchor: .top) }
                    }
                }
            }
        }
    }

    private func dateLabel(_ date: Date) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(SnackDates.label(date, format: "MMM d")).font(.subheadline).foregroundStyle(.primary)
            Text(SnackDates.label(date, format: "EEE")).font(.caption)
                .foregroundStyle(weekdayColor(date))
        }.frame(width: 62, alignment: .leading).padding(.top, 5)
    }

    private func addSnack(on date: Date) {
        edit = SnackEdit(date: date, index: nil, allowsDateChange: false, record: SnackRecord(name: ""))
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
                        TagFlow { ForEach(Array(record.otherSnacks.enumerated()), id: \.offset) { SnackTag(text: $0.element) } }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }.frame(maxWidth: .infinity, alignment: .leading).fixedSize(horizontal: false, vertical: true).contentShape(Rectangle())
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
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search snacks, makers, or dates", text: $model.query)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .accessibilityLabel("Search snacks, makers, or dates")
                    .accessibilityIdentifier("search-field")
            }
            .padding(.horizontal, 14).frame(minHeight: 56)
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
            .overlay { RoundedRectangle(cornerRadius: 12).stroke(Color.secondary.opacity(0.4)) }
            .padding()
            List {
                if model.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    EmptyView()
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
