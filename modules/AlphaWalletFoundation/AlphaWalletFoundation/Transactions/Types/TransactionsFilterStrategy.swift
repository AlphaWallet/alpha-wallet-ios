//Copyright © 2022 Stormbird PTE. LTD.

import Foundation 

public enum TransactionsFilterStrategy {
    case all
    case predicate(NSPredicate)
    case filter(strategy: ActivitiesFilterStrategy, token: Token)

    func predicate(servers: [RPCServer]) -> NSPredicate {
        let predicate: NSPredicate
        switch self {
        case .filter(let filter, let token):
            predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                TransactionDataStore.functional.nonEmptyIdTransactionPredicate(server: token.server),
                filter.predicate
            ])
        case .predicate(let p):
            predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                TransactionDataStore.functional.nonEmptyIdTransactionPredicate(servers: servers),
                p
            ])
        case .all:
            predicate = TransactionDataStore.functional.nonEmptyIdTransactionPredicate(servers: servers)
        }
        return predicate
    }

    func predicate(servers: [RPCServer], oldestBlockNumber: Int?) -> NSPredicate {
        let isPendingTransction = NSPredicate(format: "blockNumber == 0")
        let oldestBlockNumberPredicate = oldestBlockNumber.flatMap {[
            NSCompoundPredicate(orPredicateWithSubpredicates: [
                TransactionDataStore.functional.blockNumberPredicate(blockNumber: $0),
                isPendingTransction
            ])]
        } ?? []

        let predicate: NSPredicate
        switch self {
        case .filter(let filter, let token):
            predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                TransactionDataStore.functional.nonEmptyIdTransactionPredicate(server: token.server),
                filter.predicate
            ] + oldestBlockNumberPredicate)
        case .all:
            predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                TransactionDataStore.functional.nonEmptyIdTransactionPredicate(servers: servers)
            ] + oldestBlockNumberPredicate)
        case .predicate(let p):
            predicate = p
        }

        return predicate
    }
}
