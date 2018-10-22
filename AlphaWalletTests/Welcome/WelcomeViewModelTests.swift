// Copyright SIX DAY LLC. All rights reserved.

import XCTest
@testable import AlphaWallet

class WelcomeViewModelTests: XCTestCase {
    
    func testTitle() {
        let viewModel = WelcomeViewModel()

        LiveLocaleSwitcherBundle.switchLocale(to: "en")
        XCTAssertEqual("Welcome", viewModel.title)
    }
}
