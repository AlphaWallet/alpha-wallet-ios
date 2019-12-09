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

    private func addTokensWithContractAddresses(fromTransactions transactions: [Transaction]) {
        let tokens = self.tokens(from: transactions)
        if !tokens.isEmpty {
            TokensDataStore.update(in: realm, tokens: tokens)
        }
    }

    @discardableResult
    func add(transactions: [Transaction], transactionsToPullContractsFrom: [Transaction]) -> [Transaction] {
        guard !transactions.isEmpty else { return [] }
        let transactionsToCommit = filterTransactionsToNotOverrideERC20Transactions(transactions)
        realm.beginWrite()
        realm.add(transactionsToCommit, update: true)
        try! realm.commitWrite()
        addTokensWithContractAddresses(fromTransactions: transactionsToPullContractsFrom)
        return transactions
    }

    //We pull transactions data from the normal transactions API as well as ERC20 event log. For the same transaction, we only want data from the latter. Otherwise the UI will show the cell display switching between data from the 2 source as we fetch (or re-fetch)
    private func filterTransactionsToNotOverrideERC20Transactions(_ transactions: [Transaction]) -> [Transaction] {
        return transactions.filter { each in
            if each.isERC20Interaction {
                return true
            } else {
                let erc20TransactionExists = realm.objects(Transaction.self).filter("isERC20Interaction == true").contains { each.id == $0.id }
                return !erc20TransactionExists
            }
        }
    }

    @discardableResult
    func add(_ items: [Transaction]) -> [Transaction] {
        guard !items.isEmpty else { return [] }
        realm.beginWrite()
        realm.add(items, update: true)
        try! realm.commitWrite()
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
            realm.delete(realm.objects(LocalizedOperationObject.self))
            realm.delete(realm.objects(Transaction.self))
        }
    }
}
