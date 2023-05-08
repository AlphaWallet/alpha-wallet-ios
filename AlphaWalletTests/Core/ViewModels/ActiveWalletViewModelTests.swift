// Copyright SIX DAY LLC. All rights reserved.

@testable import AlphaWallet
import XCTest

class ActiveWalletViewModelTests: XCTestCase {

    func testInitialTab() {
        let viewModel = ActiveWalletViewModel()
        XCTAssertEqual(.tokens, viewModel.initialTab)
    }
}
