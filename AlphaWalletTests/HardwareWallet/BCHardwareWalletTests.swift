// Copyright © 2023 Stormbird PTE. LTD.

@testable import AlphaWallet
import XCTest

class BCHardwareWalletTests: XCTestCase {
    func testBcHardwareWalletDisabledInTests() {
        XCTAssertFalse(BCHardwareWallet.isEnabled)
    }
}