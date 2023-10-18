// Copyright SIX DAY LLC. All rights reserved.

import XCTest
@testable import AlphaWallet
import AlphaWalletFoundation
import Combine

class RequestViewModelTests: XCTestCase {
    private var cancelable = Set<AnyCancellable>()

    func testMyAddressText() {
        let account: Wallet = .make()
        let viewModel = RequestViewModel(account: account, domainResolutionService: FakeDomainResolutionService())
        let expectation = self.expectation(description: "View model state has resolved")
        let output = viewModel.transform(input: .init(copyEns: .empty(), copyAddress: .empty()))

        output.viewState
            .sink { viewState in
                XCTAssertEqual(account.address.eip55String, viewState.address, "matches address value")
                //XCTAssertNotNil(viewState.qrCode, "has qr code")
                if viewState.qrCode != nil {
                    expectation.fulfill()
                }
            }.store(in: &cancelable)

        wait(for: [expectation], timeout: 4)
    }
}
