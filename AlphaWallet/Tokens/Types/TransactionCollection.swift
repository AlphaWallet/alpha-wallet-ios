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

    var objects: [Transaction] {
        var transactions = [Transaction]()
        //Concatenate arrays of hundreds/thousands of elements and then sort them. Room for speed improvement, but it seems good enough so far. It'll be much more efficient if we do a single read from Realm directly and sort with Realm
        for each in transactionsStorages {
            transactions.append(contentsOf: Array(each.objects))
        }
        transactions.sort { $0.date < $1.date }
        return transactions
    }
}
