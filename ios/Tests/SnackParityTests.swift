import Foundation
import XCTest
@testable import SnackRecorderCore

final class SnackParityTests: XCTestCase {
    func testAnniversarySamplesUseNearestDaysAndLimitResults() {
        let record = SnackRecord(name: "Snack")
        let archive = SnackArchive(days: [
            "2025-10-29": [record], "2025-10-30": [record],
            "2025-10-31": [record], "2025-11-01": [record],
            "2026-11-01": [record]
        ])
        let target = SnackDates.date(for: "2025-10-31")!
        let latest = SnackDates.date(for: "2026-10-31")!
        XCTAssertEqual(archive.anniversarySamples(around: target, through: latest).map(\.day),
                       ["2025-10-31", "2025-10-30", "2025-11-01"])
        let many = SnackArchive(days: ["2025-10-31": Array(repeating: record, count: 4)])
        XCTAssertEqual(many.anniversarySamples(around: target, through: latest).count, 3)
        XCTAssertEqual(SnackArchive().anniversarySamples(around: target, through: latest).count, 0)
    }
    private var archive: SnackArchive {
        SnackArchive(days: [
            "2025-12-31": [SnackRecord(name: "Cookie", maker: "Bakery")],
            "2026-10-30": [SnackRecord(name: " cookie ", maker: "bakery", otherSnacks: ["Chips"])],
            "2026-10-31": [SnackRecord(name: "Cookie", maker: "Tea House", otherSnacks: ["Chocolate", "Cookie"]), SnackRecord(name: "Apple", maker: "Farm")]
        ])
    }

    func testRankingsMatchAndroidCategoriesCaseFoldingAndYears() {
        XCTAssertEqual(archive.rankings(.names).first?.label, "Cookie")
        XCTAssertEqual(archive.rankings(.names).first?.count, 3)
        XCTAssertEqual(archive.rankings(.overall).first?.count, 4)
        XCTAssertEqual(archive.rankings(.makers).first?.label, "Bakery")
        XCTAssertEqual(archive.rankings(.makers).first?.count, 2)
        XCTAssertEqual(archive.rankings(.names, year: 2026).first?.count, 2)
        XCTAssertEqual(archive.rankings(.overall, year: 2026).first?.count, 3)
        XCTAssertTrue(archive.rankings(.names, year: 2024).isEmpty)
        XCTAssertEqual(archive.rankings(.overall).dropFirst().map(\.label), ["Apple", "Chips", "Chocolate"])
    }

    func testSuggestionsPrioritizeHistoryAcrossAllFieldsAndLimitToThree() {
        XCTAssertEqual(archive.suggestions(" c"), ["Cookie", "Chips", "Chocolate"])
        XCTAssertEqual(archive.suggestions("ba"), ["Bakery", "Banana"])
        XCTAssertEqual(archive.suggestions("t"), ["Tea House", "Trail mix"])
        XCTAssertEqual(archive.suggestions("y"), ["Yogurt"])
        XCTAssertTrue(archive.suggestions(" ").isEmpty)
        XCTAssertEqual(archive.suggestions("cookie").count, 1)
    }

    func testSearchMatchesAllFieldsAndOrdersNewestFirst() {
        XCTAssertEqual(archive.search("COOKIE").map(\.day), ["2026-10-31", "2026-10-30", "2025-12-31"])
        XCTAssertEqual(archive.search("house").first?.record.name, "Cookie")
        XCTAssertEqual(archive.search("Chips").first?.day, "2026-10-30")
        XCTAssertEqual(archive.search("2026-10-31").map(\.record.name), ["Apple", "Cookie"])
        XCTAssertTrue(archive.search("  ").isEmpty)
    }

    func testCalendarLeapDayMonthYearRolloverAndYearChoices() throws {
        let leap = try XCTUnwrap(SnackDates.date(for: "2024-02-29"))
        XCTAssertEqual(SnackDates.days(in: leap).count, 29)
        XCTAssertNil(SnackDates.date(for: "2025-02-29"))
        XCTAssertNil(SnackDates.date(for: "2026-13-01"))
        XCTAssertNil(SnackDates.date(for: "2026-1-01"))
        let december = try XCTUnwrap(SnackDates.date(for: "2026-12-31"))
        XCTAssertEqual(SnackDates.key(for: SnackDates.shifted(december, by: 1, component: .day)), "2027-01-01")
        XCTAssertEqual(SnackDates.key(for: SnackDates.shifted(SnackDates.monthStart(december), by: 1, component: .month)), "2027-01-01")
        XCTAssertEqual(SnackDates.yearOptions(now: december).first, 2026)
        XCTAssertEqual(SnackDates.yearOptions(now: december).last, 1986)
        XCTAssertEqual(SnackDates.yearOptions(now: december).count, 41)
        XCTAssertEqual(SnackDates.calendar.monthSymbols[1], "February")
    }

    func testAndroidCSVRoundTripsUnicodeQuotesNewlinesAndCRLF() throws {
        let original = SnackArchive(days: ["2026-10-31": [SnackRecord(name: "せんべい, \"large\"", maker: "Tea\r\nHouse", otherSnacks: ["Chips", "Almonds"]) ]])
        let csv = "\u{feff}" + original.csv()
        let imported = try SnackImport(data: Data(csv.utf8), isCSV: true)
        XCTAssertEqual(imported.archive.days, original.days)
        XCTAssertTrue(imported.usesCSV)
        XCTAssertTrue(imported.hasOtherSnacks)
        let crlf = "date,snack,maker,other_snacks\r\n2026-10-31,Cookie,,\r\n"
        XCTAssertEqual(try SnackImport(data: Data(crlf.utf8), isCSV: true).archive.events.count, 1)
    }

    func testCSVRejectsInvalidHeadersDatesRowsNamesAndQuotes() {
        let header = "date,snack,maker,other_snacks\n"
        for text in ["snack,date\nCookie,2026-10-31\n", header + "2026-02-30,Cookie,,\n", header + "2026-10-31,Cookie\n", header + "2026-10-31,  ,,\n", header + "2026-10-31,\"Cookie,,\n", header + "2026-10-31,\"Cookie\"x,,\n"] {
            XCTAssertThrowsError(try SnackImport(data: Data(text.utf8), isCSV: true), text)
        }
    }

    func testJSONImportPreservesAmbiguousCSVSeparatorsAndValidatesDays() throws {
        let original = SnackArchive(days: ["2026-10-31": [SnackRecord(name: "Cookie", otherSnacks: ["Tea; biscuit", "Cake"]) ]])
        let imported = try SnackImport(data: original.encoded(), isCSV: false)
        XCTAssertEqual(imported.archive.days, original.days)
        XCTAssertFalse(imported.usesCSV)
        XCTAssertThrowsError(try SnackImport(data: Data(#"{"bad-date":["Cookie"]}"#.utf8), isCSV: false))
        XCTAssertThrowsError(try SnackImport(data: Data(#"{"2026-10-31":[{"name":" "}]}"#.utf8), isCSV: false))
    }

    func testImportPreviewIsNonMutatingAndMergePreservesDuplicateOccurrences() throws {
        let cookie = SnackRecord(name: "Cookie")
        let existing = SnackArchive(days: ["2026-10-31": [cookie]])
        let source = SnackArchive(days: ["2026-10-31": [cookie, cookie, SnackRecord(name: "Apple")]])
        let imported = try SnackImport(data: source.encoded(), isCSV: false)
        let preview = try imported.merged(into: existing)
        XCTAssertEqual(existing.events.count, 1)
        XCTAssertEqual(preview.added, 2)
        XCTAssertEqual(preview.skipped, 1)
        XCTAssertEqual(preview.archive.events.count, 3)
        let repeated = try imported.merged(into: preview.archive)
        XCTAssertEqual(repeated.added, 0)
        XCTAssertEqual(repeated.skipped, 3)
        XCTAssertEqual(repeated.archive.days, preview.archive.days)
    }
}
