// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import BigInt

struct SentTransaction {
    let id: String
    let original: UnsignedTransaction
}

extension SentTransaction {
    static func from(from: AlphaWallet.Address, transaction: SentTransaction, tokensDataStore: TokensDataStore) -> Transaction {
        let (operations: operations, isErc20Interaction: isErc20Interaction)  = decodeOperations(fromData: transaction.original.data, from: transaction.original.account.address, contractOrRecipient: transaction.original.to, tokensDataStore: tokensDataStore)
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
            localizedOperations: operations,
            state: .pending,
            isErc20Interaction: isErc20Interaction
        )
    }

    //TODO add support for more types of pending transactions. Probably can be supported via TokenScript in the future
    //TODO add support for more types of pending transactions. Use a more general decoder at some point
    private static func decodeOperations(fromData data: Data, from: AlphaWallet.Address, contractOrRecipient: AlphaWallet.Address?, tokensDataStore: TokensDataStore) -> (operations: [LocalizedOperationObject], isErc20Interaction: Bool) {
        //transfer(address,uint256)
        let erc20Transfer = (
                interfaceHash: "a9059cbb",
                byteCount: 68
        )
        if data[0..<4].hex() == erc20Transfer.interfaceHash && data.count == erc20Transfer.byteCount, let contract = contractOrRecipient, let value = BigUInt(data[(4 + 32)..<(4 + 32 + 32)].hex(), radix: 16), let token = tokensDataStore.token(forContract: contract) {
            //Compiler thinks it's a `Slice<Data>` if don't explicitly state the type, so we have to split into 2 `if`s
            let recipientData: Data = data[4..<(4 + 32)][4 + 12..<(4 + 32)]
            if let recipient = AlphaWallet.Address(string: recipientData.hexEncoded) {
                return (operations: [LocalizedOperationObject(from: from.eip55String, to: recipient.eip55String, contract: contract, type: "erc20TokenTransfer", value: String(value), symbol: token.symbol, name: token.name, decimals: token.decimals)], isErc20Interaction: true)
            }
        }
        return (operations: .init(), isErc20Interaction: false)
    }
}
