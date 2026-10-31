import Foundation

public struct SnackEvent: Identifiable, Equatable, Sendable {
    public let day: String
    public let index: Int
    public let record: SnackRecord
    public var id: String { "\(day)-\(index)" }
}

public struct SnackRanking: Identifiable, Equatable, Sendable {
    public let label: String
    public let count: Int
    public var id: String { label.lowercased() }
}

public enum RankingCategory: String, CaseIterable, Sendable {
    case names = "Most eaten snack names"
    case overall = "Overall snacks"
    case makers = "Most eaten makers"
}

extension SnackArchive {
    public var events: [SnackEvent] {
        days.keys.sorted().flatMap { day in
            days[day, default: []].enumerated().map { SnackEvent(day: day, index: $0.offset, record: $0.element) }
        }
    }

    public func search(_ query: String) -> [SnackEvent] {
        let query = Self.normalized(query)
        guard !query.isEmpty else { return [] }
        return events.reversed().filter { event in
            ([event.day, event.record.name, event.record.maker] + event.record.otherSnacks)
                .contains { Self.normalized($0).contains(query) }
        }
    }

    public func rankings(_ category: RankingCategory, year: Int? = nil) -> [SnackRanking] {
        let values = events.filter { year == nil || $0.day.hasPrefix(String(format: "%04d-", year!)) }
            .flatMap { event -> [String] in
                switch category {
                case .names: [event.record.name]
                case .overall: [event.record.name] + event.record.otherSnacks
                case .makers: [event.record.maker]
                }
            }
        return Self.counted(values)
    }

    public func suggestions(_ prefix: String) -> [String] {
        let prefix = Self.normalized(prefix)
        guard !prefix.isEmpty else { return [] }
        let values = events.flatMap { [$0.record.name, $0.record.maker] + $0.record.otherSnacks }
        let candidates = Self.counted(values).map(\.label) + Self.commonSnacks
        var seen = Set<String>()
        return Array(candidates.filter {
            let key = Self.normalized($0)
            return key.hasPrefix(prefix) && seen.insert(key).inserted
        }.prefix(3))
    }

    private static func counted(_ values: [String]) -> [SnackRanking] {
        var counts: [String: Int] = [:]
        var labels: [String: String] = [:]
        for raw in values {
            let label = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            let key = normalized(label)
            guard !key.isEmpty else { continue }
            counts[key, default: 0] += 1
            if labels[key] == nil { labels[key] = label }
        }
        return labels.map { SnackRanking(label: $0.value, count: counts[$0.key, default: 0]) }
            .sorted {
                if $0.count != $1.count { return $0.count > $1.count }
                let left = normalized($0.label), right = normalized($1.label)
                return left == right ? $0.label < $1.label : left < right
            }
    }

    private static func normalized(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(with: Locale(identifier: "en_US"))
    }

    private static let commonSnacks = [
        "Almonds", "Apple", "Banana", "Carrot sticks", "Cheese", "Chips", "Chocolate", "Cookie",
        "Crackers", "Granola bar", "Grapes", "Nuts", "Orange", "Popcorn", "Pretzels", "Protein bar",
        "Rice crackers", "Trail mix", "Yogurt"
    ]
}
