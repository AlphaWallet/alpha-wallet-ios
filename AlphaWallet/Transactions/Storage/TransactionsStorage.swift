// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import RealmSwift

class TransactionsStorage {
    let realm: Realm
    let server: RPCServer

    init(realm: Realm, server: RPCServer) {
        self.realm = realm
        self.server = server
    }

    var count: Int {
        return objects.count
    }

    var objects: [Transaction] {
        return Array(realm.objects(Transaction.self)
                .sorted(byKeyPath: "date", ascending: false)
                .filter("chainId = \(self.server.chainID)")
                .filter("id != ''"))
    }

    var completedObjects: [Transaction] {
        return objects.filter { $0.state == .completed }
    }

    var transactionObjectsThatDoNotComeFromEventLogs: Results<Transaction> {
        return realm.objects(Transaction.self)
                .sorted(byKeyPath: "date", ascending: false)
                .filter("chainId = \(self.server.chainID)")
                .filter("id != ''")
                .filter("internalState == \(TransactionState.completed.rawValue)")
                .filter("isERC20Interaction == false")
    }

    var pendingObjects: [Transaction] {
        return objects.filter { $0.state == TransactionState.pending }
    }

    @discardableResult
    func add(_ items: [Transaction]) -> [Transaction] {
        guard !items.isEmpty else { return [] }
        realm.beginWrite()
        realm.add(items, update: true)
        try! realm.commitWrite()

        // store contract addresses associated with transactions
        let tokens = self.tokens(from: items)
        if !tokens.isEmpty {
            TokensDataStore.update(in: realm, tokens: tokens)
        }
        return items
    }

    private func tokens(from transactions: [Transaction]) -> [TokenUpdate] {
        let tokens: [TokenUpdate] = transactions.compactMap { transaction in
            guard
                let operation = transaction.localizedOperations.first,
                let contract = operation.contractAddress,
                let name = operation.name,
                let symbol = operation.symbol
                else { return nil }
            return TokenUpdate(
                address: contract,
                server: server,
                name: name,
                symbol: symbol,
                decimals: operation.decimals
            )
        }
        return tokens
    }

    func delete(_ items: [Transaction]) {
        try! realm.write {
            realm.delete(items)
        }
    }

    @discardableResult
    func update(state: TransactionState, for transaction: Transaction) -> Transaction {
        realm.beginWrite()
        transaction.internalState = state.rawValue
        try! realm.commitWrite()
        return transaction
    }

    func removeTransactions(for states: [TransactionState]) {
        //TODO improve filtering/matching performance
        let objects = realm.objects(Transaction.self)
                .filter("chainId = \(self.server.chainID)")
                .filter { states.contains($0.state) }
        try! realm.write {
            realm.delete(objects)
        }
    }

    func deleteAll() {
        try! realm.write {
            realm.delete(realm.objects(Transaction.self))
        }
    }
}
