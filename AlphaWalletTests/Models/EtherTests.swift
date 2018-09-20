// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
@testable import Trust
import XCTest
import BigInt

class EtherTests: XCTestCase {
    func testEtherRepresentation() {
        let e = Ether(string: "1.2")!
        XCTAssertEqual("\(e)", "1.2")
        XCTAssertEqual(e.description, "1.2")
        XCTAssertEqual(String(e.description), "1.2")
        XCTAssertEqual(String(e * 10), "12")
        XCTAssertEqual(String(e / 10), "0.12")
    }

    func testDescriptionShouldNotIncludeFormatting() {
        let e = Ether(string: "1000")!
        XCTAssertEqual(String(e), "1000")
    }
}
