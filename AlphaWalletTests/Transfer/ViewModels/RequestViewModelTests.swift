// Copyright SIX DAY LLC. All rights reserved.

import XCTest
@testable import AlphaWallet

class RequestViewModelTests: XCTestCase {
    
    func testMyAddressText() {
        let account: Wallet = .make()
        let server: RPCServer = .main
        let viewModel = RequestViewModel(account: account, server: server)

        XCTAssertEqual(account.address.eip55String, viewModel.myAddressText)
    }

    func testShareMyAddressText() {
        let account: Wallet = .make()
        let server: RPCServer = .main
        let viewModel = RequestViewModel(account: account, server: server)

        LiveLocaleSwitcherBundle.switchLocale(to: "en")
        XCTAssertEqual("My \(server.name) address is: \(account.address.eip55String)", viewModel.shareMyAddressText)
    }
}
