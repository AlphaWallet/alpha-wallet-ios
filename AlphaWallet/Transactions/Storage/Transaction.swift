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

    convenience init(object: TransactionInstance) {
        self.init()

        self.primaryKey = object.primaryKey
        self.id = object.id
        self.chainId = object.server.chainID
        self.blockNumber = object.blockNumber
        self.transactionIndex = object.transactionIndex
        self.from = object.from
        self.to = object.to
        self.value = object.value
        self.gas = object.gas
        self.gasPrice = object.gasPrice
        self.gasUsed = object.gasUsed
        self.nonce = object.nonce
        self.date = object.date
        self.internalState = object.state.rawValue
        self.isERC20Interaction = object.isERC20Interaction

        let list = List<LocalizedOperationObject>()
        object.localizedOperations.forEach { element in
            let value = LocalizedOperationObject(object: element)
            list.append(value)
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
        let (operations: operations, isErc20Interaction: isErc20Interaction) = decodeOperations(fromData: transaction.original.data, from: transaction.original.account, contractOrRecipient: transaction.original.to, tokensDataStore: tokensDataStore)

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

    //TODO add support for more types of pending transactions
    fileprivate static func decodeOperations(fromData data: Data, from: AlphaWallet.Address, contractOrRecipient: AlphaWallet.Address?, tokensDataStore: TokensDataStore) -> (operations: [LocalizedOperationObject], isErc20Interaction: Bool) {
        if let functionCallMetaData = DecodedFunctionCall(data: data), let contract = contractOrRecipient, let token = tokensDataStore.tokenThreadSafe(forContract: contract) {
            switch functionCallMetaData.type {
            case .erc20Approve(let spender, let value):
                return (operations: [LocalizedOperationObject(from: from.eip55String, to: spender.eip55String, contract: contract, type: OperationType.erc20TokenApprove.rawValue, value: String(value), tokenId: "", symbol: token.symbol, name: token.name, decimals: token.decimals)], isErc20Interaction: true)
            case .erc20Transfer(let recipient, let value):
                return (operations: [LocalizedOperationObject(from: from.eip55String, to: recipient.eip55String, contract: contract, type: OperationType.erc20TokenTransfer.rawValue, value: String(value), tokenId: "", symbol: token.symbol, name: token.name, decimals: token.decimals)], isErc20Interaction: true)
            case .nativeCryptoTransfer, .others:
                break
            }
        }
        return (operations: .init(), isErc20Interaction: false)
    }
}

struct TransactionInstance: Equatable {
    var primaryKey: String = ""
    var chainId: Int = 0
    var id: String = ""
    var blockNumber: Int = 0
    var transactionIndex: Int = 0
    var from = ""
    var to = ""
    var value = ""
    var gas = ""
    var gasPrice = ""
    var gasUsed = ""
    var nonce: String = ""
    var date = Date()
    var internalState: Int = TransactionState.completed.rawValue
    var isERC20Interaction: Bool = false
    var localizedOperations: [LocalizedOperationObjectInstance] = []

    init(
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
        localizedOperations: [LocalizedOperationObjectInstance],
        state: TransactionState,
        isErc20Interaction: Bool
    ) {

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
        self.localizedOperations = localizedOperations
    }

    init(transaction: Transaction) {
        self.primaryKey = transaction.primaryKey
        self.id = transaction.id
        self.chainId = transaction.server.chainID
        self.blockNumber = transaction.blockNumber
        self.transactionIndex = transaction.transactionIndex
        self.from = transaction.from
        self.to = transaction.to
        self.value = transaction.value
        self.gas = transaction.gas
        self.gasPrice = transaction.gasPrice
        self.gasUsed = transaction.gasUsed
        self.nonce = transaction.nonce
        self.date = transaction.date
        self.internalState = transaction.state.rawValue
        self.isERC20Interaction = transaction.isERC20Interaction
        self.localizedOperations = transaction.localizedOperations.map {
            LocalizedOperationObjectInstance(object: $0)
        }
    }

    var state: TransactionState {
        return TransactionState(int: internalState)
    }

    var operation: LocalizedOperationObjectInstance? {
        return localizedOperations.first
    }

    var server: RPCServer {
        return .init(chainID: chainId)
    }

    static func ==(lhs: TransactionInstance, rhs: TransactionInstance) -> Bool {
        return lhs.primaryKey == rhs.primaryKey &&
            lhs.chainId == rhs.chainId &&
            lhs.id == rhs.id &&
            lhs.blockNumber == rhs.blockNumber &&
            lhs.transactionIndex == rhs.transactionIndex &&
            lhs.from == rhs.from &&
            lhs.to == rhs.to &&
            lhs.value == rhs.value &&
            lhs.gas == rhs.gas &&
            lhs.gasPrice == rhs.gasPrice &&
            lhs.gasUsed == rhs.gasUsed &&
            lhs.nonce == rhs.nonce &&
            lhs.date == rhs.date &&
            lhs.internalState == rhs.internalState &&
            lhs.isERC20Interaction == rhs.isERC20Interaction &&
            lhs.localizedOperations == rhs.localizedOperations
    }

}

