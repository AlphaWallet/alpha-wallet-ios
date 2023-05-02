// Copyright © 2021 Stormbird PTE. LTD.

import Foundation

public enum ActivityRowModel {
    enum PseudoActivityOrTransaction {
        case activity(activity: Activity)
        case childTransaction(transaction: Transaction, operation: LocalizedOperation)
    }

    case parentTransaction(transaction: Transaction, isSwap: Bool, activities: [Activity])
    case childActivity(transaction: Transaction, activity: Activity)
    case childTransaction(transaction: Transaction, operation: LocalizedOperation, activity: Activity?)
    case standaloneTransaction(transaction: Transaction, activity: Activity?)
    case standaloneActivity(activity: Activity)

    public var date: Date {
        switch self {
        case .parentTransaction(transaction: let transaction, _, _):
            return transaction.date
        case .childActivity(transaction: let transaction, _):
            return transaction.date
        case .childTransaction(transaction: let transaction, _, _):
            return transaction.date
        case .standaloneTransaction(transaction: let transaction, _):
            return transaction.date
        case .standaloneActivity(activity: let activity):
            return activity.date
        }
    }

    public var blockNumber: Int {
        switch self {
        case .parentTransaction(transaction: let transaction, _, _):
            return transaction.blockNumber
        case .childActivity(transaction: let transaction, _):
            return transaction.blockNumber
        case .childTransaction(transaction: let transaction, _, _):
            return transaction.blockNumber
        case .standaloneTransaction(transaction: let transaction, _):
            return transaction.blockNumber
        case .standaloneActivity(activity: let activity):
            return activity.blockNumber
        }
    }

    public var transactionIndex: Int {
        switch self {
        case .parentTransaction(transaction: let transaction, _, _):
            return transaction.transactionIndex
        case .childActivity(transaction: let transaction, _):
            return transaction.transactionIndex
        case .childTransaction(transaction: let transaction, _, _):
            return transaction.transactionIndex
        case .standaloneTransaction(transaction: let transaction, _):
            return transaction.transactionIndex
        case .standaloneActivity(activity: let activity):
            return activity.transactionIndex
        }
    }

    public var activityName: String? {
        switch self {
        case .parentTransaction:
            return nil
        case .childActivity(_, let activity):
            return activity.name
        case .childTransaction:
            return nil
        case .standaloneTransaction:
            return nil
        case .standaloneActivity(activity: let activity):
            return activity.name
        }
    }

    public func getTokenSymbol() -> String? {
        switch self {
        case .parentTransaction:
            return nil
        case .childActivity(_, let activity):
            return activity.token.symbol
        case .childTransaction(transaction: let transaction, operation: let operation, _):
            if let symbol = operation.symbol {
                return symbol
            } else {
                return transaction.server.symbol
            }
        case .standaloneTransaction(transaction: let transaction, _):
            if let operation = transaction.operation {
                return operation.symbol ?? transaction.server.symbol
            } else {
                return transaction.server.symbol
            }
        case .standaloneActivity(activity: let activity):
            return activity.token.symbol
        }
    }
}
