//
//  EnvironmentTestCase.swift
//  AlphaWalletTests
//
//  Created by Jerome Chan on 25/4/22.
//

@testable import AlphaWallet
import AlphaWalletFoundation
import XCTest

class EnvironmentTestCase: XCTestCase {

    func testIsDebug() throws {
        XCTAssertTrue(Environment.isDebug)
    }

}
