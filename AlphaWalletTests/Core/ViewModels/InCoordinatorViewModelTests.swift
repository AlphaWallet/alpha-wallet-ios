// Copyright SIX DAY LLC. All rights reserved.

import XCTest
@testable import Trust

class InCoordinatorViewModelTests: XCTestCase {
    
    func testInitialTab() {
        let viewModel = InCoordinatorViewModel(config: .make())

        XCTAssertEqual(.wallet, viewModel.initialTab)
    }
}
