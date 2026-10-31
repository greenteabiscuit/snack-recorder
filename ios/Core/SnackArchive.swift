import Foundation

public struct SnackArchive: Sendable {
    public private(set) var days: [String: [SnackRecord]]

    public init(days: [String: [SnackRecord]] = [:]) { self.days = days }

    public init(data: Data) throws {
        days = try JSONDecoder().decode([String: [SnackRecord]].self, from: data)
    }

    public func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(days)
    }

    public mutating func save(_ record: SnackRecord, day: String, index: Int? = nil) throws {
        guard !record.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ArchiveError.emptyName
        }
        var records = days[day, default: []]
        if let index {
            guard records.indices.contains(index) else { throw ArchiveError.missingRecord }
            records[index] = record
        } else {
            records.append(record)
        }
        days[day] = records
    }

    public mutating func remove(day: String, index: Int) throws {
        guard var records = days[day], records.indices.contains(index) else {
            throw ArchiveError.missingRecord
        }
        records.remove(at: index)
        if records.isEmpty { days.removeValue(forKey: day) } else { days[day] = records }
    }

    public func csv() -> String {
        var result = "date,snack,maker,other_snacks\n"
        for day in days.keys.sorted() {
            for record in days[day, default: []] {
                result += [day, record.name, record.maker, record.otherSnacks.joined(separator: "; ")]
                    .map(Self.csvField).joined(separator: ",") + "\n"
            }
        }
        return result
    }

    private static func csvField(_ value: String) -> String {
        guard value.contains(where: { ",\"\n\r".contains($0) }) else { return value }
        return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}

public enum ArchiveError: LocalizedError {
    case emptyName, missingRecord

    public var errorDescription: String? {
        switch self {
        case .emptyName: "Enter a snack name."
        case .missingRecord: "This snack could not be found."
        }
    }
}

public struct SnackRepository {
    public let url: URL
    public init(url: URL) { self.url = url }

    public func load() throws -> SnackArchive {
        guard FileManager.default.fileExists(atPath: url.path) else { return SnackArchive() }
        return try SnackArchive(data: Data(contentsOf: url))
    }

    public func save(_ archive: SnackArchive) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try archive.encoded().write(to: url, options: .atomic)
    }
}
