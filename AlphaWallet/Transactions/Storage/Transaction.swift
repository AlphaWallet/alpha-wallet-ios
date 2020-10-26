// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import BigInt
import RealmSwift

class Transaction: Object {
    @objc dynamic var primaryKey: String = ""
    @objc dynamic var chainId: Int = 0
    @objc dynamic var id: String = ""
    @objc dynamic var blockNumber: Int = 0
    @objc dynamic var transactionIndex: Int = 0
    @objc dynamic var from = ""
    @objc dynamic var to = ""
    @objc dynamic var value = ""
    @objc dynamic var gas = ""
    @objc dynamic var gasPrice = ""
    @objc dynamic var gasUsed = ""
    @objc dynamic var nonce: String = ""
    @objc dynamic var date = Date()
    @objc dynamic var internalState: Int = TransactionState.completed.rawValue
    @objc dynamic var isERC20Interaction: Bool = false
    var localizedOperations = List<LocalizedOperationObject>()

    convenience init(
        id: String,
        server: RPCServer,
        blockNumber: Int,
        transactionIndex: Int,
        from: String,
        to: String,
        value: String,
        gas: String,
        gasPrice: String,
        gasUsed: String,
        nonce: String,
        date: Date,
        localizedOperations: [LocalizedOperationObject],
        state: TransactionState,
        isErc20Interaction: Bool
    ) {

        self.init()
        self.primaryKey = "\(id)-\(server.chainID)"
        self.id = id
        self.chainId = server.chainID
        self.blockNumber = blockNumber
        self.transactionIndex = transactionIndex
        self.from = from
        self.to = to
        self.value = value
        self.gas = gas
        self.gasPrice = gasPrice
        self.gasUsed = gasUsed
        self.nonce = nonce
        self.date = date
        self.internalState = state.rawValue
        self.isERC20Interaction = isErc20Interaction

        let list = List<LocalizedOperationObject>()
        localizedOperations.forEach { element in
            list.append(element)
        }

        self.localizedOperations = list
    }

    override static func primaryKey() -> String? {
        return "primaryKey"
    }

    var state: TransactionState {
        return TransactionState(int: internalState)
    }
}

extension Transaction {
    var operation: LocalizedOperationObject? {
        return localizedOperations.first
    }

    var server: RPCServer {
        return .init(chainID: chainId)
    }
}

extension Transaction {
    static func from(from: AlphaWallet.Address, transaction: SentTransaction, tokensDataStore: TokensDataStore) -> Transaction {
        let (operations: operations, isErc20Interaction: isErc20Interaction)  = decodeOperations(fromData: transaction.original.data, from: transaction.original.account, contractOrRecipient: transaction.original.to, tokensDataStore: tokensDataStore)
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
    fileprivate static func decodeOperations(fromData data: Data, from: AlphaWallet.Address, contractOrRecipient: AlphaWallet.Address?, tokensDataStore: TokensDataStore) -> (operations: [LocalizedOperationObject], isErc20Interaction: Bool) {
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