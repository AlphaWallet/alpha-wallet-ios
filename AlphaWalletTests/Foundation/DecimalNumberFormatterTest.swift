// Copyright SIX DAY LLC. All rights reserved.

@testable import AlphaWallet
import XCTest

class DecimalFormatterTest: XCTestCase {
    let usDecimalFormatter = DecimalFormatter(locale: Locale(identifier: "en_US"))
    let frDecimalFormatter = DecimalFormatter(locale: Locale(identifier: "fr_FR"))
    func testDecimalPointInUS() {
        XCTAssertEqual(usDecimalFormatter.number(from: "1000.25"), NSNumber(value: 1000.25))
        XCTAssertEqual(usDecimalFormatter.number(from: ".25"), NSNumber(value: 0.25))
    }
    func testDecimalAndThousandsPointsInUS() {
        XCTAssertEqual(usDecimalFormatter.number(from: "1,000.25"), NSNumber(value: 1000.25))
        XCTAssertEqual(usDecimalFormatter.number(from: "1.000,25"), NSNumber(value: 1000.25))
        XCTAssertEqual(usDecimalFormatter.number(from: "1'000,25"), NSNumber(value: 1000.25))
    }
    func testThousandsPointsInUS() {
        XCTAssertEqual(usDecimalFormatter.number(from: ",25"), NSNumber(value: 25))
    }
    func testNumberToStingInUS() {
        XCTAssertEqual(usDecimalFormatter.string(from: NSNumber(value: 1000.25)), "1,000.25")
        XCTAssertEqual(usDecimalFormatter.string(from: NSNumber(value: 0.25)), "0.25")
    }
    func testInvalidStringInUS() {
        XCTAssertEqual(usDecimalFormatter.number(from: "test"), nil)
    }
    func testDecimalPointInFr() {
        XCTAssertEqual(frDecimalFormatter.number(from: "1 000,25"), NSNumber(value: 1000.25))
        XCTAssertEqual(frDecimalFormatter.number(from: ".25"), NSNumber(value: 25))
    }
    func testDecimalAndThousandsPointsInFr() {
        XCTAssertEqual(frDecimalFormatter.number(from: "1,000.25"), NSNumber(value: 1000.25))
        XCTAssertEqual(frDecimalFormatter.number(from: "1.000,25"), NSNumber(value: 1000.25))
        XCTAssertEqual(frDecimalFormatter.number(from: "1'000,25"), NSNumber(value: 1000.25))
    }
    func testThousandsPointsInFr() {
        XCTAssertEqual(frDecimalFormatter.number(from: ",25"), NSNumber(value: 0.25))
    }
    func testNumberToStingInFr() {
        //NOTE: There some cases when for different simulators it uses different characters for space like \u{202F} or \u{00A0}.
        let value: String = "1"+frDecimalFormatter.groupingSeparator+"000,25"

        XCTAssertEqual(frDecimalFormatter.string(from: NSNumber(value: 1000.25))!, value)
        XCTAssertEqual(frDecimalFormatter.string(from: NSNumber(value: 0.25)), "0,25")
    }
    func testInvalidStringInFr() {
        XCTAssertEqual(frDecimalFormatter.number(from: "test"), nil)
    }
}
