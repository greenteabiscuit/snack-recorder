import Foundation

public struct SnackRecord: Codable, Equatable, Sendable {
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
        return String(format: "%04d-%02d-%02d", parts.year!, parts.month!, parts.day!)
    }
}
