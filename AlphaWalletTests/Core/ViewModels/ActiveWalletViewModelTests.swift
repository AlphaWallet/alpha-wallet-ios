// Copyright SIX DAY LLC. All rights reserved.

import XCTest
@testable import AlphaWallet

class ActiveWalletViewModelTests: XCTestCase {
    
    func testInitialTab() {
        let viewModel = ActiveWalletViewModel()
        XCTAssertEqual(.tokens, viewModel.initialTab)
    }
}
