// Copyright © 2021 Stormbird PTE. LTD.
import Foundation

public enum TransactionRow {
    case standalone(Transaction)
    //TODO this seems to overlap with the `ActivityRowModel.parentTransaction`
    case group(Transaction)
    case item(transaction: Transaction, operation: LocalizedOperation)

    public var transaction: Transaction {
        switch self {
        case .standalone(let transaction), .group(let transaction), .item(transaction: let transaction, _):
            return transaction
        }
    }

    public var id: String { transaction.id }
    public var blockNumber: Int { transaction.blockNumber }
    public var transactionIndex: Int { transaction.transactionIndex }

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

    public var gas: String { transaction.gas }
    public var gasPrice: String { transaction.gasPrice.flatMap { String(describing: $0.max) } ?? "" }
    public var gasUsed: String { transaction.gasUsed }
    public var nonce: String { transaction.nonce }
    public var date: Date { transaction.date }
    public var state: TransactionState { transaction.state }
    public var server: RPCServer { transaction.server }

    public var operation: LocalizedOperation? {
        switch self {
        case .standalone(let transaction):
            return transaction.operation
        case .group:
            return nil
        case .item(_, let operation):
            return operation
        }
    }
}

extension TransactionRow: Hashable {
    public static func == (lhs: TransactionRow, rhs: TransactionRow) -> Bool {
        switch (lhs, rhs) {
        case (.standalone(let t1), .standalone(let t2)):
            return t1 == t2
        case (.group(let t1), .group(let t2)):
            return t1 == t2
        case (.item(let t1, let op1), .item(let t2, let op2)):
            return t1 == t2 && op1 == op2
        case (.standalone, .item), (.standalone, .group), (.item, .standalone), (.item, .group), (.group, .standalone), (.group, .item):
            return false
        }
    }
}
