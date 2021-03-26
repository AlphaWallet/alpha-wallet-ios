//Copyright © 2018 Stormbird PTE. LTD.

import Foundation

///This contains transactions across multiple-chains
class TransactionCollection {
    //TODO make private
    let transactionsStorages: [TransactionsStorage]

    init(transactionsStorages: [TransactionsStorage]) {
        self.transactionsStorages = transactionsStorages
    }

    @discardableResult
    func add(_ items: [Transaction]) -> [Transaction] {
        guard let server = items.first?.server else { return [] }
        guard let storage = transactionsStorages.first(where: { $0.server == server }) else { return [] }
        return storage.add(items)
    }

    var objects: [TransactionInstance] {
        //Concatenate arrays of hundreds/thousands of elements. Room for speed improvement, but it seems good enough so far. It'll be much more efficient if we do a single read from Realm directly

        return transactionsStorages.flatMap {
            return $0.objects.map { TransactionInstance(transaction: $0) }
        }
    }

    func transaction(withTransactionId transactionId: String, server: RPCServer) -> TransactionInstance? {
        guard let storage = transactionsStorages.first(where: { $0.server == server }) else { return nil }
        return storage.transaction(withTransactionId: transactionId)
    }
}
