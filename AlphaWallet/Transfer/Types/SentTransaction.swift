// Copyright SIX DAY LLC. All rights reserved.

import Foundation

struct SentTransaction {
    let id: String
    let original: UnsignedTransaction
}

extension SentTransaction {
    static func from(from: AlphaWallet.Address, transaction: SentTransaction) -> Transaction {
        return Transaction(
            id: transaction.id,
            server: transaction.original.server,
            blockNumber: 0,
            transactionIndex: 0,
            from: from.eip55String,
            to: transaction.original.to?.eip55String ?? "",
            value: transaction.original.value.description,
            gas: transaction.original.gasLimit.description,
            gasPrice: transaction.original.gasPrice.description,
            gasUsed: "",
            nonce: String(transaction.original.nonce),
            date: Date(),
            //TODO we should know what type of transaction (transfer) here and create accordingly if it's ERC20, ERC721, ERC875
            localizedOperations: [],
            state: .pending,
            isErc20Interaction: false
        )
    }
}
