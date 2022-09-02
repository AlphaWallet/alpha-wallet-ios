// Copyright SIX DAY LLC. All rights reserved.

import XCTest
@testable import AlphaWallet
import AlphaWalletFoundation

class RequestViewModelTests: XCTestCase {

    func testMyAddressText() {
        let account: Wallet = .make()
        let viewModel = RequestViewModel(account: account)

        XCTAssertEqual(account.address.eip55String, viewModel.myAddressText)
    }
}
