// Copyright © 2021 Stormbird PTE. LTD.

import Foundation
import XCTest
@testable import AlphaWallet

class IntExtensionsTests: XCTestCase {
    func testChainId0xString() {
        XCTAssertEqual(Int(chainId0xString: "12"), 12)
        XCTAssertEqual(Int(chainId0xString: "0x80"), 128)
        XCTAssertNil(Int(chainId0xString: "1xy"))
    }
}