// Copyright © 2021 Stormbird PTE. LTD.

import Foundation

enum ActivityRowModel {
    case parentTransaction(transaction: TransactionInstance, isSwap: Bool, activities: [Activity])
    case childActivity(transaction: TransactionInstance, activity: Activity)
    case childTransaction(transaction: TransactionInstance, operation: LocalizedOperationObjectInstance)
    case standaloneTransaction(transaction: TransactionInstance)
    case standaloneActivity(activity: Activity)

    var date: Date {
        switch self {
        case .parentTransaction(transaction: let transaction, _, _):
            return transaction.date
        case .childActivity(transaction: let transaction, _):
            return transaction.date
        case .childTransaction(transaction: let transaction, _):
            return transaction.date
        case .standaloneTransaction(transaction: let transaction):
            return transaction.date
        case .standaloneActivity(activity: let activity):
            return activity.date
        }
    }

    var blockNumber: Int {
        switch self {
        case .parentTransaction(transaction: let transaction, _, _):
            return transaction.blockNumber
        case .childActivity(transaction: let transaction, _):
            return transaction.blockNumber
        case .childTransaction(transaction: let transaction, _):
            return transaction.blockNumber
        case .standaloneTransaction(transaction: let transaction):
            return transaction.blockNumber
        case .standaloneActivity(activity: let activity):
            return activity.blockNumber
        }
    }

    var transactionIndex: Int {
        switch self {
        case .parentTransaction(transaction: let transaction, _, _):
            return transaction.transactionIndex
        case .childActivity(transaction: let transaction, _):
            return transaction.transactionIndex
        case .childTransaction(transaction: let transaction, _):
            return transaction.transactionIndex
        case .standaloneTransaction(transaction: let transaction):
            return transaction.transactionIndex
        case .standaloneActivity(activity: let activity):
            return activity.transactionIndex
        }
    }

    var activityName: String? {
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

    func getTokenSymbol(fromTokensStorages tokensStorages: ServerDictionary<TokensDataStore>) -> String? {
        switch self {
        case .parentTransaction:
            return nil
        case .childActivity(_, let activity):
            return activity.tokenObject.symbol
        case .childTransaction(transaction: let transaction, operation: let operation):
            if let symbol = operation.symbol {
                return symbol
            } else {
                return transaction.server.symbol
            }
        case .standaloneTransaction(transaction: let transaction):
            if let operation = transaction.operation {
                return operation.symbol ?? transaction.server.symbol
            } else {
                return transaction.server.symbol
            }
        case .standaloneActivity(activity: let activity):
            return activity.tokenObject.symbol
        }
    }
}
