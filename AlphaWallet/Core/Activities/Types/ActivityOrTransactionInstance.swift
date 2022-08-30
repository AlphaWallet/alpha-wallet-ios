//
//  ActivityOrTransactionInstance.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 18.02.2022.
//

import Foundation

enum ActivityOrTransactionInstance {
    case activity(Activity)
    case transaction(TransactionInstance)

    var blockNumber: Int {
        switch self {
        case .activity(let activity):
            return activity.blockNumber
        case .transaction(let transaction):
            return transaction.blockNumber
        }
    }

    var transaction: TransactionInstance? {
        switch self {
        case .activity:
            return nil
        case .transaction(let transaction):
            return transaction
        }
    }
    var activity: Activity? {
        switch self {
        case .activity(let activity):
            return activity
        case .transaction:
            return nil
        }
    }
}
