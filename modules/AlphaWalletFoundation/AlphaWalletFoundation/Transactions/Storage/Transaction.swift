// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import BigInt
import RealmSwift

class TransactionObject: Object {
    static func generatePrimaryKey(for id: String, server: RPCServer) -> String {
        return "\(id)-\(server.chainID)"
    }
    @objc dynamic var primaryKey: String = ""
    @objc dynamic var chainId: Int = 0
    @objc dynamic var id: String = ""
    @objc dynamic var blockNumber: Int = 0
    @objc dynamic var transactionIndex: Int = 0
    @objc dynamic var from = ""
    @objc dynamic var to = ""
    @objc dynamic var value = ""
    @objc dynamic var gas = ""
    @objc dynamic var gasPrice: GasPriceObject?
    @objc dynamic var gasUsed = ""
    @objc dynamic var nonce: String = ""
    @objc dynamic var date = Date()
    @objc dynamic var internalState: Int = TransactionState.completed.rawValue
    @objc dynamic var isERC20Interaction: Bool = false
    var localizedOperations = List<LocalizedOperationObject>()

    convenience init(transaction: Transaction) {
        self.init()

        self.primaryKey = transaction.primaryKey
        self.id = transaction.id
        self.chainId = transaction.server.chainID
        self.blockNumber = transaction.blockNumber
        self.transactionIndex = transaction.transactionIndex
        self.from = transaction.from
        self.to = transaction.to
        self.value = transaction.value
        self.gas = transaction.gas
        self.gasPrice = transaction.gasPrice.flatMap { GasPriceObject(gasPrice: $0, primaryKey: transaction.primaryKey) }
        self.gasUsed = transaction.gasUsed
        self.nonce = transaction.nonce
        self.date = transaction.date
        self.internalState = transaction.state.rawValue
        self.isERC20Interaction = transaction.isERC20Interaction

        let list = List<LocalizedOperationObject>()
        transaction.localizedOperations.forEach { element in
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

    var server: RPCServer {
        return .init(chainID: chainId)
    }
}

extension Transaction {

    static func from(from: AlphaWallet.Address, transaction: SentTransaction, token: Token?) -> Transaction {
        let (operations: operations, isErc20Interaction: isErc20Interaction) = decodeOperations(
            data: transaction.original.data,
            from: transaction.original.account,
            token: token)

        return Transaction(
                id: transaction.id,
                server: transaction.original.server,
                blockNumber: 0,
                transactionIndex: 0,
                from: from.eip55String,
                to: transaction.original.to?.eip55String ?? "",
                value: transaction.original.value.description,
                gas: transaction.original.gasLimit.description,
                gasPrice: transaction.original.gasPrice,
                gasUsed: "",
                nonce: String(transaction.original.nonce),
                date: Date(),
                localizedOperations: operations,
                state: .pending,
                isErc20Interaction: isErc20Interaction)
    }

    //TODO add support for more types of pending transactions
    fileprivate static func decodeOperations(data: Data, from: AlphaWallet.Address, token: Token?) -> (operations: [LocalizedOperation], isErc20Interaction: Bool) {
        if let functionCallMetaData = DecodedFunctionCall(data: data), let token = token {
            switch functionCallMetaData.type {
            case .erc20Approve(let spender, let value):
                return (operations: [LocalizedOperation(from: from.eip55String, to: spender.eip55String, contract: token.contractAddress, type: OperationType.erc20TokenApprove.rawValue, value: String(value), tokenId: "", symbol: token.symbol, name: token.name, decimals: token.decimals)], isErc20Interaction: true)
            case .erc20Transfer(let recipient, let value):
                return (operations: [LocalizedOperation(from: from.eip55String, to: recipient.eip55String, contract: token.contractAddress, type: OperationType.erc20TokenTransfer.rawValue, value: String(value), tokenId: "", symbol: token.symbol, name: token.name, decimals: token.decimals)], isErc20Interaction: true)
            //TODO support ERC721 setApprovalForAll()
            case .erc721ApproveAll:
                break
            case .nativeCryptoTransfer, .others, .erc1155SafeBatchTransfer, .erc1155SafeTransfer:
                break
            }
        }
        return (operations: .init(), isErc20Interaction: false)
    }
}

public struct Transaction: Equatable, Hashable {
    public let primaryKey: String
    public let chainId: Int
    public let id: String
    public let blockNumber: Int
    public let transactionIndex: Int
    public let from: String
    public let to: String
    public let value: String
    public let gas: String
    public let gasPrice: GasPrice?
    public let gasUsed: String
    public let nonce: String
    public let date: Date
    public let internalState: Int
    public var isERC20Interaction: Bool
    public var localizedOperations: [LocalizedOperation]

    public init(id: String,
                server: RPCServer,
                blockNumber: Int,
                transactionIndex: Int,
                from: String,
                to: String,
                value: String,
                gas: String,
                gasPrice: GasPrice?,
                gasUsed: String,
                nonce: String,
                date: Date,
                localizedOperations: [LocalizedOperation],
                state: TransactionState,
                isErc20Interaction: Bool) {

        self.primaryKey = TransactionObject.generatePrimaryKey(for: id, server: server)
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
        self.localizedOperations = localizedOperations.uniqued()
    }

    public var state: TransactionState {
        return TransactionState(int: internalState)
    }

    public var operation: LocalizedOperation? {
        return localizedOperations.first
    }

    public var server: RPCServer {
        return .init(chainID: chainId)
    }

    public static func == (lhs: Transaction, rhs: Transaction) -> Bool {
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

extension Transaction {
    init(transaction: TransactionObject) {
        self.primaryKey = transaction.primaryKey
        self.id = transaction.id
        self.chainId = transaction.server.chainID
        self.blockNumber = transaction.blockNumber
        self.transactionIndex = transaction.transactionIndex
        self.from = transaction.from
        self.to = transaction.to
        self.value = transaction.value
        self.gas = transaction.gas
        self.gasPrice = transaction.gasPrice.flatMap { GasPrice(object: $0) }
        self.gasUsed = transaction.gasUsed
        self.nonce = transaction.nonce
        self.date = transaction.date
        self.internalState = transaction.state.rawValue
        self.isERC20Interaction = transaction.isERC20Interaction
        //NOTE: removes existing duplications of localized operations, need as `LocalizedOperation` don't have a primaryKey
        self.localizedOperations = transaction.localizedOperations.map { LocalizedOperation(object: $0) }.uniqued()
    }
}
