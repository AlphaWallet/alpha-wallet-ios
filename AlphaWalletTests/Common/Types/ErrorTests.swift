// Copyright © 2022 Stormbird PTE. LTD.

@testable import AlphaWallet
import AlphaWalletFoundation
import XCTest

class ErrorTests: XCTestCase {
    func testMakeSureErrorMessageDefinedInExtensionAvailableCorrectlyAcrossFrameworks() {
        //Must be stored as `Error` for test
        let e: Error = KeystoreError.duplicateAccount
        XCTAssertEqual(e.localizedDescription, "You already added this address to wallets")
    }
}
