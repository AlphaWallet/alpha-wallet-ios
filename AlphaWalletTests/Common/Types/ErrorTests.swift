// Copyright © 2022 Stormbird PTE. LTD.

import XCTest
@testable import AlphaWallet
import AlphaWalletFoundation

class ErrorTests: XCTestCase {
    func testMakeSureErrorMessageDefinedInExtensionAvailableCorrectlyAcrossFrameworks() {
        //Must be stored as `Error` for test
        let e: Error = KeystoreError.duplicateAccount
        XCTAssertEqual(e.localizedDescription, "You already added this address to wallets")
    }
}
