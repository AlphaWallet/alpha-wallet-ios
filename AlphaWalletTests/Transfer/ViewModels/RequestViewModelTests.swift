// Copyright SIX DAY LLC. All rights reserved.

import XCTest
@testable import AlphaWallet
import TrustKeystore

class RequestViewModelTests: XCTestCase {
    
    func testMyAddressText() {
        let account: Wallet = .make()
        let server: RPCServer = .main
        let viewModel = RequestViewModel(account: account, server: server)

        XCTAssertEqual(account.address.description, viewModel.myAddressText)
    }

    func testShareMyAddressText() {
        let account: Wallet = .make()
        let server: RPCServer = .main
        let viewModel = RequestViewModel(account: account, server: server)

        LiveLocaleSwitcherBundle.switchLocale(to: "en")
        XCTAssertEqual("My \(server.name) address is: \(account.address.description)", viewModel.shareMyAddressText)
    }
}
