// Copyright © 2018 Stormbird PTE. LTD.

@testable import AlphaWallet
import AlphaWalletFoundation
import BigInt
import Foundation
import XCTest

class EtherTests: XCTestCase {
    func testEtherRepresentationEnglishLocale() {
        Config.setLocale(AppLocale.english)
        let e = Ether(string: "1.2")!
        XCTAssertEqual("\(e)", "1.2")
        XCTAssertEqual(e.description, "1.2")
        XCTAssertEqual(String(e.description), "1.2")
        XCTAssertEqual(String(e * 10), "12")
        XCTAssertEqual(String(e / 10), "0.12")
    }

    func testDescriptionShouldNotIncludeFormattingEnglishLocale() {
        Config.setLocale(AppLocale.english)

        let e = Ether(string: "1000")!
        XCTAssertEqual(String(e), "1000")
    }
}
