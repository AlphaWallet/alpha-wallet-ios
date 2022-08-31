// Copyright © 2021 Stormbird PTE. LTD.
import Foundation

public enum TransactionRow {
    case standalone(TransactionInstance)
    //TODO this seems to overlap with the `ActivityRowModel.parentTransaction`
    case group(TransactionInstance)
    case item(transaction: TransactionInstance, operation: LocalizedOperationObjectInstance)

    public var transaction: TransactionInstance {
        switch self {
        case .standalone(let transaction), .group(let transaction), .item(transaction: let transaction, _):
            return transaction
        }
    }

    public var id: String {
        transaction.id
    }
    public var blockNumber: Int {
        transaction.blockNumber
    }
    public var transactionIndex: Int {
        transaction.transactionIndex
    }
    public var from: String {
        switch self {
        case .standalone(let transaction):
            return transaction.operation?.from ?? transaction.from
        case .group(let transaction):
            return transaction.from
        case .item(_, operation: let operation):
            return operation.from
        }
    }
    public var to: String {
        switch self {
        case .standalone(let transaction):
            return transaction.operation?.to ?? transaction.to
        case .group(let transaction):
            return transaction.to
        case .item(_, operation: let operation):
            return operation.to
        }
    }
    public var value: String {
        switch self {
        case .standalone(let transaction):
            return transaction.operation?.value ?? transaction.value
        case .group(let transaction):
            return transaction.value
        case .item(_, operation: let operation):
            return operation.value
        }
    }
    public var gas: String {
        transaction.gas
    }
    public var gasPrice: String {
        transaction.gasPrice
    }
    public var gasUsed: String {
        transaction.gasUsed
    }
    public var nonce: String {
        transaction.nonce
    }
    public var date: Date {
        transaction.date
    }
    public var state: TransactionState {
        transaction.state
    }
    public var server: RPCServer {
        transaction.server
    }

    public var operation: LocalizedOperationObjectInstance? {
        switch self {
        case .standalone(let transaction):
            return transaction.operation
        case .group:
            return nil
        case .item(_, operation: let operation):
            return operation
        }
    }
}
