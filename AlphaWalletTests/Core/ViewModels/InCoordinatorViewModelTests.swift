// Copyright SIX DAY LLC. All rights reserved.

import XCTest
@testable import AlphaWallet

class InCoordinatorViewModelTests: XCTestCase {
    
    func testInitialTab() {
        let viewModel = InCoordinatorViewModel()
        XCTAssertEqual(.wallet, viewModel.initialTab)
    }
}
