// Copyright SIX DAY LLC. All rights reserved.

import XCTest
@testable import AlphaWallet

class BackupViewModelTests: XCTestCase {
    
    func testHeadlineText() {
        let config: Config = .make(defaults: .test)
        let viewModel = BackupViewModel(config: config)

        LiveLocaleSwitcherBundle.switchLocale(to: "en")
        XCTAssertEqual("No backup, no \(config.server.name).", viewModel.headlineText)
    }
}
