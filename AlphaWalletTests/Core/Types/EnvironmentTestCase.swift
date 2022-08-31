//
//  EnvironmentTestCase.swift
//  AlphaWalletTests
//
//  Created by Jerome Chan on 25/4/22.
//

import XCTest
@testable import AlphaWallet
import AlphaWalletFoundation

class EnvironmentTestCase: XCTestCase {

    func testIsDebug() throws {
        XCTAssertTrue(Environment.isDebug)
    }

}
