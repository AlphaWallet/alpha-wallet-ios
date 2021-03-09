import Foundation
import RealmSwift
import PromiseKit

protocol TransactionsStorageDelegate: class {
    func didAddTokensWith(contracts: [AlphaWallet.Address], inTransactionsStorage: TransactionsStorage)
}

class TransactionsStorage {
    private let realm: Realm
    weak private var delegate: TransactionsStorageDelegate?

    let server: RPCServer

    init(realm: Realm, server: RPCServer, delegate: TransactionsStorageDelegate?) {
        self.realm = realm
        self.server = server
        self.delegate = delegate
    }

    var count: Int {
        return objects.count
    }

    var objects: Results<Transaction> {
        realm.threadSafe.objects(Transaction.self)
            .sorted(byKeyPath: "date", ascending: false)
            .filter("chainId = \(self.server.chainID)")
            .filter("id != ''")
    }

    var completedObjects: [Transaction] {
        objects.filter { $0.state == .completed }
    }

    var pendingObjects: [TransactionInstance] {
        objects.filter { $0.state == TransactionState.pending }.map { TransactionInstance(transaction: $0) }
    }

    func transaction(withTransactionId transactionId: String) -> TransactionInstance? {
        realm.threadSafe.objects(Transaction.self)
            .filter("id = '\(transactionId)'")
            .filter("chainId = \(server.chainID)")
            .map { TransactionInstance(transaction: $0) }
            .first
    }

    private func addTokensWithContractAddresses(fromTransactions transactions: [Transaction], contractsAndTokenTypes: [AlphaWallet.Address: TokenType], realm: Realm) {
        let tokens = self.tokens(from: transactions, contractsAndTokenTypes: contractsAndTokenTypes)
        delegate?.didAddTokensWith(contracts: Array(Set(tokens.map { $0.address })), inTransactionsStorage: self)
        if !tokens.isEmpty {
            TokensDataStore.update(in: realm, tokens: tokens)
        }
    }

    private func addTokensWithContractAddresses(fromTransactions transactions: [Transaction], contractsAndTokenTypes: [AlphaWallet.Address: TokenType]) {
        let tokens = self.tokens(from: transactions, contractsAndTokenTypes: contractsAndTokenTypes)
        delegate?.didAddTokensWith(contracts: Array(Set(tokens.map { $0.address })), inTransactionsStorage: self)
        if !tokens.isEmpty {
            TokensDataStore.update(in: realm, tokens: tokens)
        }
    }

    func add(transactions: [Transaction], transactionsToPullContractsFrom: [Transaction], contractsAndTokenTypes: [AlphaWallet.Address: TokenType]) {
        guard !transactions.isEmpty else { return }
        let transactionsToCommit = filterTransactionsToNotOverrideERC20Transactions(transactions, realm: realm)
        realm.beginWrite()
        realm.add(transactionsToCommit, update: .all)

        try! realm.commitWrite()
        addTokensWithContractAddresses(fromTransactions: transactionsToPullContractsFrom, contractsAndTokenTypes: contractsAndTokenTypes)
    }

    func transactionObjectsThatDoNotComeFromEventLogs() -> TransactionInstance? {
        return realm.threadSafe.objects(Transaction.self)
            .sorted(byKeyPath: "date", ascending: false)
            .filter("chainId = \(self.server.chainID)")
            .filter("id != ''")
            .filter("internalState == \(TransactionState.completed.rawValue)")
            .filter("isERC20Interaction == false")
            .map { TransactionInstance(transaction: $0) }
            .first
    }

    var transactions: [TransactionInstance] {
        realm.threadSafe.objects(Transaction.self)
            .sorted(byKeyPath: "date", ascending: false)
            .filter("chainId = \(self.server.chainID)")
            .filter("id != ''")
            .map { TransactionInstance(transaction: $0) }
    }

    func delete(transactions: [TransactionInstance]) -> Promise<Void> {
        return Promise { seal in
            let realm = self.realm.threadSafe
            let objects = transactions.compactMap {
                realm.object(ofType: Transaction.self, forPrimaryKey: $0.primaryKey)
            }

            do {
                try realm.write {
                    realm.delete(objects)
                }
                seal.fulfill(())
            } catch {
                seal.reject(error)
            }
        }
    }

    func update(state: TransactionState, for primaryKey: String, withPendingTransaction pendingTransaction: PendingTransaction?) -> Promise<TransactionInstance> {
        enum AnyError: Error {
            case invalid
        }

        return Promise { seal in
            let realm = self.realm.threadSafe
            if let value = realm.object(ofType: Transaction.self, forPrimaryKey: primaryKey) {
                realm.beginWrite()

                if let pendingTransaction = pendingTransaction {
                    value.gas = pendingTransaction.gas
                    value.gasPrice = pendingTransaction.gasPrice
                    value.nonce = pendingTransaction.nonce
                    //We assume that by the time we get here, the block number is valid
                    value.blockNumber = Int(pendingTransaction.blockNumber)!
                }
                value.internalState = state.rawValue

                do {
                    try realm.commitWrite()
                    let transaction = TransactionInstance(transaction: value)

                    seal.fulfill(transaction)
                } catch {
                    seal.reject(error)
                }
            } else {
                seal.reject(AnyError.invalid)
            }
        }
    }

    func add(transactions: [TransactionInstance], transactionsToPullContractsFrom: [TransactionInstance], contractsAndTokenTypes: [AlphaWallet.Address: TokenType]) {

        guard !transactions.isEmpty else { return }

        let newTransactions = transactions.map { Transaction(object: $0) }
        let newTransactionsToPullContractsFrom = transactionsToPullContractsFrom.map { Transaction(object: $0) }

        let realm = self.realm.threadSafe

        let transactionsToCommit = self.filterTransactionsToNotOverrideERC20Transactions(newTransactions, realm: realm)
        realm.beginWrite()

        for transaction in transactionsToCommit {
            realm.add(transaction, update: .all)
        }

        try! realm.commitWrite()

        self.addTokensWithContractAddresses(fromTransactions: newTransactionsToPullContractsFrom, contractsAndTokenTypes: contractsAndTokenTypes, realm: realm)
    }

    //We pull transactions data from the normal transactions API as well as ERC20 event log. For the same transaction, we only want data from the latter. Otherwise the UI will show the cell display switching between data from the 2 source as we fetch (or re-fetch)
    private func filterTransactionsToNotOverrideERC20Transactions(_ transactions: [Transaction], realm: Realm) -> [Transaction] {
        return transactions.filter { each in
            if each.isERC20Interaction {
                return true
            } else {
                return realm.object(ofType: Transaction.self, forPrimaryKey: each.primaryKey) == nil
            }
        }
    }

    @discardableResult
    func add(_ items: [Transaction]) -> [Transaction] {
        guard !items.isEmpty else { return [] }
        realm.beginWrite()
        realm.add(items, update: .all)
        try! realm.commitWrite()
        return items
    }

    private func tokens(from transactions: [Transaction], contractsAndTokenTypes: [AlphaWallet.Address: TokenType]) -> [TokenUpdate] {
        let tokens: [TokenUpdate] = transactions.flatMap { transaction -> [TokenUpdate] in
            let tokenUpdates: [TokenUpdate] = transaction.localizedOperations.compactMap { operation in
                guard let contract = operation.contractAddress else { return nil }
                guard let name = operation.name else { return nil }
                guard let symbol = operation.symbol else { return nil }
                return TokenUpdate(
                        address: contract,
                        server: server,
                        name: name,
                        symbol: symbol,
                        decimals: operation.decimals,
                        tokenType: contractsAndTokenTypes[contract] ?? .erc20
                )
            }
            return tokenUpdates
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
