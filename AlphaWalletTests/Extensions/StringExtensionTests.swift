// Copyright © 2018 Stormbird PTE. LTD.

@testable import AlphaWallet
import Foundation
import XCTest

class StringExtensionTests: XCTestCase {
    func testAdd0x() {
        XCTAssertEqual("001".add0x, "0x001")
        XCTAssertEqual("0x001".add0x, "0x001")
    }

    func testDrop0x() {
        XCTAssertEqual("001".drop0x, "001")
        XCTAssertEqual("0x001".drop0x, "001")
    }
}
