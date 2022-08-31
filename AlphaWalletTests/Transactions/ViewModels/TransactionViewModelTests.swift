// Copyright SIX DAY LLC. All rights reserved.

import XCTest
@testable import AlphaWallet
import AlphaWalletFoundation

class TransactionViewModelTests: XCTestCase {

    func testErrorState() {
        let _ = TransactionViewModel(transactionRow: .standalone(.make(state: .error)), chainState: .make(), wallet: .make())
    }

    func testPendingState() {
        let blockNumber = 1
        let chainState: ChainState = .make()
        chainState.latestBlock = blockNumber

        let viewModel = TransactionViewModel(transactionRow: .standalone(.make(blockNumber: blockNumber)), chainState: chainState, wallet: .make())

        XCTAssertEqual(.none, viewModel.confirmations)
    }

    func testCompleteStateWhenLatestBlockBehind() {
        let blockNumber = 3
        let chainState: ChainState = .make()
        chainState.latestBlock = blockNumber - 1

        let viewModel = TransactionViewModel(transactionRow: .standalone(.make(blockNumber: blockNumber)), chainState: chainState, wallet: .make())

        XCTAssertNil(viewModel.confirmations)
    }

    func testCompleteState() {
        let blockNumber = 3
        let chainState: ChainState = .make()
        chainState.latestBlock = blockNumber

        let viewModel = TransactionViewModel(transactionRow: .standalone(.make(blockNumber: 1)), chainState: chainState, wallet: .make())

        XCTAssertEqual(2, viewModel.confirmations)
    }
}
