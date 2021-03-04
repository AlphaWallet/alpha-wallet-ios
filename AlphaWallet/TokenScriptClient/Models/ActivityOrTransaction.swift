// Copyright © 2020 Stormbird PTE. LTD.

import Foundation

enum ActivityOrTransaction {
    case activity(Activity)
    case transaction(TransactionInstance)

    var activityName: String? {
        switch self {
        case .activity(let activity):
            return activity.name
        case .transaction:
            return nil
        }
    }

    var date: Date {
        switch self {
        case .activity(let activity):
            return activity.date
        case .transaction(let transaction):
            return transaction.date
        }
    }

    var blockNumber: Int {
        switch self {
        case .activity(let activity):
            return activity.blockNumber
        case .transaction(let transaction):
            return transaction.blockNumber
        }
    }

    var transactionIndex: Int {
        switch self {
        case .activity(let activity):
            return activity.transactionIndex
        case .transaction(let transaction):
            return transaction.transactionIndex
        }
    }

    func getTokenSymbol(fromTokensStorages tokensStorages: ServerDictionary<TokensDataStore>) -> String? {
        switch self {
        case .activity(let activity):
            return activity.tokenObject.symbol
        case .transaction(let transaction):
            return getSymbol(fromTransaction: transaction, tokensStorages: tokensStorages)
        }
    }

    private func getSymbol(fromTransaction transaction: TransactionInstance, tokensStorages: ServerDictionary<TokensDataStore>) -> String? {
        if transaction.operation == nil {
            let token = TokensDataStore.etherToken(forServer: transaction.server)
            return token.symbol
        } else {
            switch (transaction.state, transaction.operation?.operationType) {
            case (.pending, .erc20TokenTransfer), (.pending, .erc721TokenTransfer), (.pending, .erc875TokenTransfer):
                let token = transaction.operation?.contractAddress.flatMap { tokensStorages[transaction.server].tokenThreadSafe(forContract: $0) }
                return token?.symbol
            //Explicitly listing out combinations so future changes to enums will be caught by compiler
            case (.pending, .nativeCurrencyTokenTransfer), (.pending, .unknown), (.pending, nil):
                return nil
            case (.unknown, _), (.error, _), (.failed, _), (.completed, _):
                return nil
            }
        }
    }
}
