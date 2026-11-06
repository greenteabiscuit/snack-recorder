import Foundation

public struct SnackImport: Sendable {
    public let archive: SnackArchive
    public let usesCSV: Bool
    public let hasOtherSnacks: Bool

    public init(data: Data, isCSV: Bool) throws {
        usesCSV = isCSV
        if isCSV {
            guard var text = String(data: data, encoding: .utf8) else { throw TransferError.invalid("Use a UTF-8 CSV file.") }
            if text.hasPrefix("\u{feff}") { text.removeFirst() }
            let rows = try CSVReader.read(text)
            guard rows.first == ["date", "snack", "maker", "other_snacks"] else {
                throw TransferError.invalid("Expected CSV columns: date,snack,maker,other_snacks.")
            }
            var imported = SnackArchive()
            for (offset, row) in rows.dropFirst().enumerated() {
                guard row.count == 4 else { throw TransferError.invalid("CSV row \(offset + 2) must contain four columns.") }
                guard SnackDates.date(for: row[0]) != nil else {
                    throw TransferError.invalid("CSV row \(offset + 2) has an invalid date. Use yyyy-MM-dd.")
                }
                let others = row[3].isEmpty ? [] : row[3].components(separatedBy: "; ")
                try imported.save(SnackRecord(name: row[1], maker: row[2], otherSnacks: others), day: row[0])
            }
            archive = imported
        } else {
            let imported = try SnackArchive(data: data)
            for (day, records) in imported.days {
                guard SnackDates.date(for: day) != nil else { throw TransferError.invalid("The backup contains an invalid day: \(day).") }
                guard records.allSatisfy({ !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
                    throw TransferError.invalid("Every snack must have a name.")
                }
            }
            archive = imported
        }
        hasOtherSnacks = archive.events.contains { !$0.record.otherSnacks.isEmpty }
    }

    // Match occurrences, not just values: two identical snack events must remain two events.
    // Importing the same file again is idempotent without collapsing genuine duplicates.
    public func merged(into existing: SnackArchive) throws -> (archive: SnackArchive, added: Int, skipped: Int) {
        var merged = existing
        var added = 0, skipped = 0
        for day in archive.days.keys.sorted() {
            var remaining: [SnackRecord: Int] = [:]
            for record in existing.days[day, default: []] { remaining[record, default: 0] += 1 }
            for record in archive.days[day, default: []] {
                if remaining[record, default: 0] > 0 {
                    remaining[record, default: 0] -= 1
                    skipped += 1
                } else {
                    try merged.save(record, day: day)
                    added += 1
                }
            }
        }
        return (merged, added, skipped)
    }
}

public enum TransferError: LocalizedError {
    case invalid(String)
    public var errorDescription: String? { switch self { case .invalid(let reason): reason } }
}

private enum CSVReader {
    static func read(_ text: String) throws -> [[String]] {
        // Work with Unicode scalars so CRLF remains two separators, not one Swift Character.
        let chars = Array(text.unicodeScalars)
        var rows: [[String]] = [], row: [String] = [], field = ""
        var quoted = false, closedQuote = false, index = 0
        func finishField() { row.append(field); field = ""; closedQuote = false }
        func finishRow() { finishField(); rows.append(row); row = [] }
        while index < chars.count {
            let char = chars[index]
            if quoted {
                if char == "\"" {
                    if index + 1 < chars.count && chars[index + 1] == "\"" {
                        field.append("\""); index += 1
                    } else { quoted = false; closedQuote = true }
                } else { field.unicodeScalars.append(char) }
            } else if char == "," {
                finishField()
            } else if char == "\r" || char == "\n" {
                finishRow()
                if char == "\r" && index + 1 < chars.count && chars[index + 1] == "\n" { index += 1 }
            } else if char == "\"" && field.isEmpty && !closedQuote {
                quoted = true
            } else {
                guard !closedQuote && char != "\"" else { throw TransferError.invalid("The CSV contains a malformed quoted field.") }
                field.unicodeScalars.append(char)
            }
            index += 1
        }
        guard !quoted else { throw TransferError.invalid("The CSV contains an unclosed quoted field.") }
        if !field.isEmpty || !row.isEmpty || closedQuote { finishRow() }
        return rows
    }
}
