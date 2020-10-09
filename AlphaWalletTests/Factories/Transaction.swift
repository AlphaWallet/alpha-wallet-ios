// Copyright SIX DAY LLC. All rights reserved.

import Foundation
@testable import AlphaWallet

extension Transaction {
    static func make(
        id: String = "0x1",
        blockNumber: Int = 1,
        transactionIndex: Int = 0,
        from: String = "0x1",
        to: String = "0x1",
        value: String = "1",
        gas: String = "0x1",
        gasPrice: String = "0x1",
        gasUsed: String = "0x1",
        nonce: String = "0",
        date: Date = Date(),
        localizedOperations: [LocalizedOperationObject] = [],
        state: TransactionState = .completed
    ) -> Transaction {
        return Transaction(
            id: id,
            server: .main,
            blockNumber: blockNumber,
            transactionIndex: transactionIndex,
            from: from,
            to: to,
            value: value,
            gas: gas,
            gasPrice: gasPrice,
            gasUsed: gasUsed,
            nonce: nonce,
            date: date,
            localizedOperations: localizedOperations,
            state: state,
            isErc20Interaction: false
        )
    }
}
