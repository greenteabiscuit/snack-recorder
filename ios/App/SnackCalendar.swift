import SwiftUI

struct MonthControls: View {
    @Binding var month: Date
    var now = LaunchSettings.today

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                shiftButton("Previous year", icon: "chevron.left.2", amount: -12)
                shiftButton("Previous month", icon: "chevron.left", amount: -1)
                Spacer(minLength: 0)
                Menu {
                    ForEach(1...12, id: \.self) { number in
                        Button(SnackDates.calendar.monthSymbols[number - 1]) { set(month: number) }
                    }
                } label: { Text(SnackDates.label(month, format: "MMMM")).font(.headline) }
                    .accessibilityLabel("Month").accessibilityValue(SnackDates.label(month, format: "MMMM"))
                    .accessibilityIdentifier("month-picker")
                Menu {
                    ForEach(SnackDates.yearOptions(now: now), id: \.self) { year in
                        Button(String(year)) { set(year: year) }
                    }
                } label: { Text(SnackDates.label(month, format: "yyyy")).monospacedDigit().font(.headline) }
                    .accessibilityLabel("Year").accessibilityValue(SnackDates.label(month, format: "yyyy"))
                    .accessibilityIdentifier("year-picker")
                Spacer(minLength: 0)
                shiftButton("Next month", icon: "chevron.right", amount: 1)
                shiftButton("Next year", icon: "chevron.right.2", amount: 12)
            }
            Text(SnackDates.label(month, format: "MMMM yyyy")).font(.subheadline).foregroundStyle(.secondary)
                .accessibilityIdentifier("visible-month")
        }.padding(.horizontal).padding(.vertical, 10)
    }

    private func shiftButton(_ title: String, icon: String, amount: Int) -> some View {
        Button { shift(amount) } label: { Image(systemName: icon).frame(minWidth: 32, minHeight: 40) }
            .accessibilityLabel(title)
    }
    private func shift(_ amount: Int) {
        withAnimation(.easeInOut(duration: 0.18)) { month = SnackDates.shifted(month, by: amount, component: .month) }
    }
    private func set(year: Int? = nil, month number: Int? = nil) {
        var parts = SnackDates.calendar.dateComponents([.year, .month], from: month)
        if let year { parts.year = year }
        if let number { parts.month = number }
        parts.day = 1; parts.hour = 12
        if let date = SnackDates.calendar.date(from: parts) { withAnimation { month = date } }
    }
}

struct SnackCalendar: View {
    @ObservedObject var model: SnackViewModel
    let select: (Date) -> Void
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 5), count: 7)
    private var dates: [Date] { SnackDates.days(in: model.visibleMonth) }
    private var offset: Int { SnackDates.calendar.component(.weekday, from: model.visibleMonth) - 1 }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                MonthControls(month: $model.visibleMonth)
                LazyVGrid(columns: columns, spacing: 7) {
                    ForEach(Array(["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"].enumerated()), id: \.offset) { index, label in
                        Text(label).font(.caption.bold()).foregroundStyle(index == 0 ? Color.red : index == 6 ? Color.blue : Color.secondary)
                    }
                    ForEach(0..<offset, id: \.self) { _ in Color.clear.frame(height: 62).accessibilityHidden(true) }
                    ForEach(dates, id: \.self) { date in cell(date) }
                }.padding(.horizontal, 12)
                Text("Select a day to view its snacks. Swipe to change months.")
                    .font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center).padding()
            }
        }
        .background(SnackTheme.background)
        .accessibilityIdentifier("calendar-content")
        .snackSwipe { delta in
            withAnimation(.easeInOut(duration: 0.18)) { model.visibleMonth = SnackDates.shifted(model.visibleMonth, by: delta, component: .month) }
        }
    }

    private func cell(_ date: Date) -> some View {
        let key = SnackDates.key(for: date)
        let count = model.archive.days[key, default: []].count
        let selected = key == SnackDates.key(for: model.selectedDay)
        let today = key == SnackDates.key(for: LaunchSettings.today)
        return Button { select(date) } label: {
            VStack(spacing: 4) {
                Text(String(SnackDates.calendar.component(.day, from: date))).font(.body.weight(selected || count > 0 ? .bold : .regular))
                Text(count > 0 ? "\(count)" : " ").font(.caption2.bold())
            }
            .frame(maxWidth: .infinity, minHeight: 62)
            .foregroundStyle(selected ? Color.white : Color.primary)
            .background(selected ? SnackTheme.orange : count > 0 ? SnackTheme.lightOrange : Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
            .overlay { RoundedRectangle(cornerRadius: 12).stroke(today ? SnackTheme.orange : .clear, lineWidth: 2) }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(SnackDates.label(date, format: "MMMM d, yyyy")), \(count) snacks\(today ? ", today" : "")")
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier("calendar-day-\(key)")
    }
}
