import Foundation

public struct SnackRecord: Codable, Hashable, Sendable {
    public var name: String
    public var maker: String
    public var otherSnacks: [String]

    public init(name: String, maker: String = "", otherSnacks: [String] = []) {
        self.name = name
        self.maker = maker
        self.otherSnacks = otherSnacks
    }

    enum CodingKeys: String, CodingKey { case name, maker, otherSnacks }

    public init(from decoder: Decoder) throws {
        // Android's original storage used plain strings before records gained metadata.
        if let legacy = try? decoder.singleValueContainer().decode(String.self) {
            self.init(name: legacy)
            return
        }
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            name: try values.decode(String.self, forKey: .name),
            maker: try values.decodeIfPresent(String.self, forKey: .maker) ?? "",
            otherSnacks: try values.decodeIfPresent([String].self, forKey: .otherSnacks) ?? []
        )
    }
}

public enum SnackDates {
    // A day is a Gregorian local date, never a UTC timestamp.
    public static func key(for date: Date, timeZone: TimeZone = .current) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", locale: Locale(identifier: "en_US_POSIX"), parts.year!, parts.month!, parts.day!)
    }

    public static var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.locale = Locale(identifier: "en_US_POSIX")
        value.firstWeekday = 1
        return value
    }

    public static func date(for key: String) -> Date? {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3, key.count == 10,
              let date = calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2], hour: 12)),
              Self.key(for: date) == key else { return nil }
        return date
    }

    public static func monthStart(_ date: Date) -> Date {
        let parts = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: DateComponents(year: parts.year, month: parts.month, day: 1, hour: 12))!
    }

    public static func days(in month: Date) -> [Date] {
        let start = monthStart(month)
        return calendar.range(of: .day, in: .month, for: start)!.map {
            calendar.date(byAdding: .day, value: $0 - 1, to: start)!
        }
    }

    public static func shifted(_ date: Date, by amount: Int, component: Calendar.Component) -> Date {
        calendar.date(byAdding: component, value: amount, to: date)!
    }

    public static func yearOptions(now: Date = Date()) -> [Int] {
        let current = calendar.component(.year, from: now)
        return Array(stride(from: current, through: current - 40, by: -1))
    }

    public static func label(_ date: Date, format: String) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = format
        return formatter.string(from: date)
    }
}
