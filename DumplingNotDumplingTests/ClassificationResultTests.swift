import XCTest
@testable import DumplingNotDumpling

final class ClassificationResultTests: XCTestCase {
    func testIsDumpling() {
        let result = ClassificationResult(
            label: "gyoza",
            confidence: 0.95,
            allResults: [("gyoza", 0.95), ("not_dumpling", 0.05)]
        )
        XCTAssertTrue(result.isDumpling)
        XCTAssertEqual(result.displayLabel, "dumpling.")
        XCTAssertEqual(result.dumplingType, "gyoza")
    }

    func testIsNotDumpling() {
        let result = ClassificationResult(
            label: "not_dumpling",
            confidence: 0.99,
            allResults: [("not_dumpling", 0.99), ("gyoza", 0.01)]
        )
        XCTAssertFalse(result.isDumpling)
        XCTAssertEqual(result.displayLabel, "not dumpling.")
        XCTAssertNil(result.dumplingType)
    }

    func testPartyConfidence() {
        let result = ClassificationResult(
            label: "gyoza",
            confidence: 0.70,
            allResults: [("gyoza", 0.70), ("momo", 0.20), ("not_dumpling", 0.10)]
        )
        XCTAssertEqual(result.partyConfidence, 0.90, accuracy: 0.001)
    }

    func testSecondaryMatches() {
        let result = ClassificationResult(
            label: "xiaolongbao",
            confidence: 0.80,
            allResults: [
                ("xiaolongbao", 0.80),
                ("gyoza", 0.10),
                ("momo", 0.05),
                ("not_dumpling", 0.05)
            ]
        )
        let secondary = result.secondaryMatches(limit: 2)
        XCTAssertEqual(secondary.count, 2)
        XCTAssertEqual(secondary[0].label, "gyoza")
        XCTAssertEqual(secondary[1].label, "momo")
    }

    func testEmptyAllResults() {
        let result = ClassificationResult(
            label: "unknown",
            confidence: 0,
            allResults: []
        )
        XCTAssertEqual(result.partyConfidence, 0)
        XCTAssertTrue(result.secondaryMatches().isEmpty)
    }

    func testSingleResultNoSecondary() {
        let result = ClassificationResult(
            label: "gyoza",
            confidence: 1.0,
            allResults: [("gyoza", 1.0)]
        )
        XCTAssertTrue(result.secondaryMatches().isEmpty)
        XCTAssertEqual(result.partyConfidence, 1.0, accuracy: 0.001)
    }

    func testDisplayLabelFormat() {
        let dumpling = ClassificationResult(label: "momo", confidence: 0.8, allResults: [("momo", 0.8)])
        XCTAssertEqual(dumpling.displayLabel, "dumpling.")

        let notDumpling = ClassificationResult(label: "not_dumpling", confidence: 0.9, allResults: [("not_dumpling", 0.9)])
        XCTAssertEqual(notDumpling.displayLabel, "not dumpling.")
    }

    func testAppModeAllCases() {
        XCTAssertEqual(AppMode.allCases.count, 2)
        XCTAssertEqual(AppMode.party.rawValue, "party")
        XCTAssertEqual(AppMode.full.rawValue, "full")
    }
}
