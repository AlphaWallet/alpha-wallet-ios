//
//  TokenViewModelTests.swift
//  AlphaWalletTests
//
//  Created by Vladyslav Shepitko on 18.07.2022.
//

@testable import AlphaWallet
import AlphaWalletFoundation
import XCTest

class TokenViewModelTests: XCTestCase {
    func testHashValues() throws {
        let t1 = TokenViewModel(token: Token())
        let t2 = TokenViewModel(token: Token())
        let t3 = TokenViewModel(token: Token(symbol: "XX"))
        XCTAssertEqual(t1.hashValue, t2.hashValue)
        XCTAssertNotEqual(t1.hashValue, t3.hashValue)
        XCTAssertEqual(t1, t3)
        XCTAssertEqual(t2, t3)
    }
}
