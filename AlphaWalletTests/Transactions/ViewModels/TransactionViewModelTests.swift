// Copyright SIX DAY LLC. All rights reserved.

import XCTest
@testable import AlphaWallet
import AlphaWalletFoundation

class TransactionViewModelTests: XCTestCase {

    func testErrorState() {
        let _ = TransactionViewModel(transactionRow: .standalone(.make(state: .error)), blockNumberProvider: .make(), wallet: .make())
    }

    func testPendingState() {
        let blockNumber = 1
        let blockNumberProvider: BlockNumberProvider = .make()
        blockNumberProvider.latestBlock = blockNumber

        let viewModel = TransactionViewModel(transactionRow: .standalone(.make(blockNumber: blockNumber)), blockNumberProvider: blockNumberProvider, wallet: .make())

        XCTAssertEqual(.none, viewModel.confirmations)
    }

    func testCompleteStateWhenLatestBlockBehind() {
        let blockNumber = 3
        let blockNumberProvider: BlockNumberProvider = .make()
        blockNumberProvider.latestBlock = blockNumber - 1

        let viewModel = TransactionViewModel(transactionRow: .standalone(.make(blockNumber: blockNumber)), blockNumberProvider: blockNumberProvider, wallet: .make())

        XCTAssertNil(viewModel.confirmations)
    }

    func testCompleteState() {
        let blockNumber = 3
        let blockNumberProvider: BlockNumberProvider = .make()
        blockNumberProvider.latestBlock = blockNumber

        let viewModel = TransactionViewModel(transactionRow: .standalone(.make(blockNumber: 1)), blockNumberProvider: blockNumberProvider, wallet: .make())

        XCTAssertEqual(2, viewModel.confirmations)
    }
}
