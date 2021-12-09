//
//  StringValidatorRuleTestCases.swift
//  AlphaWalletTests
//
//  Created by Jerome Chan on 2/12/21.
//

import XCTest
@testable import AlphaWallet

class StringValidatorRuleTestCases: XCTestCase {
    func testLess() throws {
        let less = StringValidator.Rule.lengthLessThan(5)
        let lessOrEqual = StringValidator.Rule.lengthLessThanOrEqualTo(5)
        var testString = "1234"
        XCTAssert(less.validate(testString))
        XCTAssert(lessOrEqual.validate(testString))
        testString = "12345"
        XCTAssertFalse(less.validate(testString))
        XCTAssert(lessOrEqual.validate(testString))
        testString = "123456"
        XCTAssertFalse(less.validate(testString))
        XCTAssertFalse(lessOrEqual.validate(testString))
    }

    func testMore() throws {
        let more = StringValidator.Rule.lengthMoreThan(5)
        let moreOrEqual = StringValidator.Rule.lengthMoreThanOrEqualTo(5)
        var testString = "1234"
        XCTAssertFalse(more.validate(testString))
        XCTAssertFalse(moreOrEqual.validate(testString))
        testString = "12345"
        XCTAssertFalse(more.validate(testString))
        XCTAssert(moreOrEqual.validate(testString))
        testString = "123456"
        XCTAssert(more.validate(testString))
        XCTAssert(moreOrEqual.validate(testString))
    }

    func testContains() throws {
        let cs1 = CharacterSet(charactersIn: "0123456789")
        let cs2 = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz")
        let can = StringValidator.Rule.canOnlyContain(cs1)
        let cannot = StringValidator.Rule.doesNotContain(cs2)
        var testString = "     "
        XCTAssertFalse(can.validate(testString))
        XCTAssert(cannot.validate(testString))
        testString = "12345"
        XCTAssert(can.validate(testString))
        XCTAssert(cannot.validate(testString))
        testString = "abcde"
        XCTAssertFalse(can.validate(testString))
        XCTAssertFalse(cannot.validate(testString))
        testString = "12345abcde"
        XCTAssertFalse(can.validate(testString))
        XCTAssertFalse(cannot.validate(testString))
        testString = ""
        XCTAssert(can.validate(testString))
        XCTAssert(cannot.validate(testString))
    }
}
