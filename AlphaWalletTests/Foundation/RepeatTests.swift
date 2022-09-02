//
//  RepeatTests.swift
//  AlphaWalletTests
//
//  Created by Jerome Chan on 14/3/22.
//

import XCTest
@testable import AlphaWallet
import AlphaWalletFoundation

class RepeatTests: XCTestCase {

    func testRepeat() throws {
        let repeatLoop = Int.random(in: 100...500)
        var times = 0
        repeatTimes(repeatLoop) {
            times+=1
        }
        XCTAssertEqual(times, repeatLoop)
    }

}
