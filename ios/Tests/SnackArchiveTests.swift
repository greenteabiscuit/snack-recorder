import Foundation
import XCTest
@testable import SnackRecorderCore

final class SnackArchiveTests: XCTestCase {
    func testAndroidCurrentAndLegacyRecordsRoundTrip() throws {
        let data = Data(#"{"2026-10-31":["Chocolate",{"name":"せんべい","maker":"Maker","otherSnacks":["Tea; biscuit","Cookie"]}]}"#.utf8)
        let archive = try SnackArchive(data: data)
        XCTAssertEqual(archive.days["2026-10-31"]?.first, SnackRecord(name: "Chocolate"))
        XCTAssertEqual(try SnackArchive(data: archive.encoded()).days, archive.days)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: archive.encoded()) as? [String: [[String: Any]]])
        XCTAssertEqual(json["2026-10-31"]?[1]["otherSnacks"] as? [String], ["Tea; biscuit", "Cookie"])
    }

    func testCSVMatchesAndroidEscapingOrderingAndHeader() {
        let archive = SnackArchive(days: [
            "2026-10-31": [SnackRecord(name: "Cookie, \"big\"", maker: "A\nB", otherSnacks: ["Tea", "Cake"])],
            "2026-10-01": [SnackRecord(name: "Apple")]
        ])
        XCTAssertEqual(archive.csv(), "date,snack,maker,other_snacks\n2026-10-01,Apple,,\n2026-10-31,\"Cookie, \"\"big\"\"\",\"A\nB\",Tea; Cake\n")
    }

    func testCRUDKeepsDuplicateSnacksAndRemovesEmptyDay() throws {
        var archive = SnackArchive()
        try archive.save(SnackRecord(name: "Cookie"), day: "2026-10-31")
        try archive.save(SnackRecord(name: "Cookie"), day: "2026-10-31")
        try archive.save(SnackRecord(name: "Cake", maker: "Bakery"), day: "2026-10-31", index: 1)
        XCTAssertEqual(archive.days["2026-10-31"]?.map(\.name), ["Cookie", "Cake"])
        try archive.remove(day: "2026-10-31", index: 0)
        try archive.remove(day: "2026-10-31", index: 0)
        XCTAssertNil(archive.days["2026-10-31"])
        XCTAssertThrowsError(try archive.save(SnackRecord(name: "  \n"), day: "2026-10-31"))
        XCTAssertThrowsError(try archive.remove(day: "2026-10-31", index: 0))
    }

    func testRepositoryPersistsAcrossInstances() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("nested/days.json")
        let repository = SnackRepository(url: url)
        XCTAssertTrue(try repository.load().days.isEmpty)
        let archive = SnackArchive(days: ["2026-10-31": [SnackRecord(name: "Cookie")]])
        try repository.save(archive)
        XCTAssertEqual(try SnackRepository(url: url).load().days, archive.days)
    }

    func testCorruptStorageIsReportedAndPreserved() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("days.json")
        let original = Data("broken json".utf8)
        try original.write(to: url)
        XCTAssertThrowsError(try SnackRepository(url: url).load())
        XCTAssertEqual(try Data(contentsOf: url), original)
    }

    func testLocalDayDoesNotShiftToUTCOrUserCalendar() {
        let date = Date(timeIntervalSince1970: 1793374200) // 2026-10-30 15:30 UTC
        XCTAssertEqual(SnackDates.key(for: date, timeZone: TimeZone(secondsFromGMT: 9 * 3600)!), "2026-10-31")
        XCTAssertEqual(SnackDates.key(for: date, timeZone: TimeZone(secondsFromGMT: 0)!), "2026-10-30")
    }
}
