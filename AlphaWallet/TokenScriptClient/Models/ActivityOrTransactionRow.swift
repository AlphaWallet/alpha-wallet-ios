// Copyright © 2020 Stormbird PTE. LTD.

import Foundation

enum ActivityOrTransactionRow {
    case activity(Activity)
    case transactionRow(TransactionRow)

    var activityName: String? {
        switch self {
        case .activity(let activity):
            return activity.name
        case .transactionRow:
            return nil
        }
    }

    var date: Date {
        switch self {
        case .activity(let activity):
            return activity.date
        case .transactionRow(let transactionRow):
            return transactionRow.date
        }
    }

    var blockNumber: Int {
        switch self {
        case .activity(let activity):
            return activity.blockNumber
        case .transactionRow(let transactionRow):
            return transactionRow.blockNumber
        }
    }

    var transactionIndex: Int {
        switch self {
        case .activity(let activity):
            return activity.transactionIndex
        case .transactionRow(let transactionRow):
            return transactionRow.transactionIndex
        }
    }

    func getTokenSymbol() -> String? {
        switch self {
        case .activity(let activity):
            return activity.tokenObject.symbol
        case .transactionRow(let transactionRow):
            return getSymbol(fromTransactionRow: transactionRow)
        }
    }

    private func getSymbol(fromTransactionRow transactionRow: TransactionRow) -> String? {
        switch transactionRow {
        case .standalone(let transaction):
            if let operation = transaction.operation {
                return operation.symbol ?? transaction.server.symbol
            } else {
                return transaction.server.symbol
            }
        case .group(let transaction):
            return transaction.server.symbol
        case .item(transaction: let transaction, operation: let operation):
            if let symbol = operation.symbol {
                return symbol
            } else {
                return transaction.server.symbol
            }
        }
    }
}
