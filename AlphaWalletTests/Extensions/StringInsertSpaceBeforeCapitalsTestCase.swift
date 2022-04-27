//
//  StringInsertSpaceBeforeCapitalsTestCase.swift
//  AlphaWalletTests
//
//  Created by Jerome Chan on 25/4/22.
//

import XCTest
@testable import AlphaWallet

class StringInsertSpaceBeforeCapitalsTestCase: XCTestCase {

    func testEmpty() throws {
        let baseString = ""
        let result = baseString.insertSpaceBeforeCapitals()
        XCTAssertEqual(result, baseString)
    }

    func testNoCapitals() throws {
        let baseString = "thequickbrownfoxjumpsoverthelazydog"
        let result = baseString.insertSpaceBeforeCapitals()
        XCTAssertEqual(result, baseString)
    }

    func testCapitals() throws {
        let baseString = "IAmWaitingForTheResult"
        let result = baseString.insertSpaceBeforeCapitals()
        XCTAssertEqual(result, "I Am Waiting For The Result")
    }

    func testCapitalsWithAcronyms() throws {
        let baseString1 = "YMCAIsWhereItsAt"
        let result1 = baseString1.insertSpaceBeforeCapitals()
        XCTAssertEqual(result1, "YMCA Is Where Its At")
        let baseString2 = "ItsFunToStayAtTheYMCA"
        let result2 = baseString2.insertSpaceBeforeCapitals()
        XCTAssertEqual(result2, "Its Fun To Stay At The YMCA")
        let baseString3 = "WhereIsTheYMCALocated"
        let result3 = baseString3.insertSpaceBeforeCapitals()
        XCTAssertEqual(result3, "Where Is The YMCA Located")
    }

    func testLowercaseFirst() throws {
        let baseString = "americanShipsAtSea"
        let result = baseString.insertSpaceBeforeCapitals()
        XCTAssertEqual(result, "american Ships At Sea")
    }
}
