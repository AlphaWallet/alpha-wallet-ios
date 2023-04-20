import Foundation
import AlphaWalletLogger
import BigInt
import RealmSwift
import Combine

open class TransactionDataStore {
    //TODO if we move this to instance-side, we have to be careful it's the same instance we are accessing, otherwise we wouldn't find the pending transaction information when we need it
    public static var pendingTransactionsInformation: [String: (server: RPCServer, data: Data, transactionType: TransactionType, gasPrice: GasPrice)] = .init()

    private let store: RealmStore

    public init(store: RealmStore) {
        self.store = store
    }

    public func transactionCount(forServer server: RPCServer) -> Int {
        return transactions(forServer: server).count
    }

    public func transactions(forServer server: RPCServer, sortedDateAscending: Bool = false) -> [Transaction] {
        var results: [Transaction] = []
        store.performSync { realm in
            results = realm.objects(TransactionObject.self)
                .filter(TransactionDataStore.functional.nonEmptyIdTransactionPredicate(server: server))
                .sorted(byKeyPath: "date", ascending: sortedDateAscending)
                .map { Transaction(transaction: $0) }
        }

        return results
    }

    public func transactionsChangeset(filter: TransactionsFilterStrategy, servers: [RPCServer]) -> AnyPublisher<ChangeSet<[Transaction]>, Never> {
        var publisher: AnyPublisher<ChangeSet<[Transaction]>, Never>!
        store.performSync { realm in
            publisher = realm.objects(TransactionObject.self)
                .filter(filter.predicate(servers: servers))
                .sorted(byKeyPath: "date", ascending: false)
                .changesetPublisher
                .freeze()
                .receive(on: DispatchQueue.global())
                .map { change in
                    switch change {
                    case .initial(let transactions):
                        return .initial(Array(transactions.map { Transaction(transaction: $0) }))
                    case .update(let transactions, let deletions, let insertions, let modifications):
                        return .update(Array(transactions.map { Transaction(transaction: $0) }), deletions: deletions, insertions: insertions, modifications: modifications)
                    case .error(let error):
                        return .error(error)
                    }
                }.eraseToAnyPublisher()
        }

        return publisher
    }

    public func transactionPublisher(for transactionId: String, server: RPCServer) -> AnyPublisher<Transaction?, DataStoreError> {
        let publisher: CurrentValueSubject<Transaction?, DataStoreError> = .init(nil)
        var notificationToken: NotificationToken?

        store.performSync { realm in
            let primaryKey = TransactionObject.generatePrimaryKey(for: transactionId, server: server)
            guard let transaction = realm.object(ofType: TransactionObject.self, forPrimaryKey: primaryKey) else {
                publisher.send(completion: .failure(DataStoreError.objectNotFound))
                return
            }

            publisher.send(Transaction(transaction: transaction))

            notificationToken = transaction.observe { change in
                switch change {
                case .change(let object, _):
                    guard let token = object as? TransactionObject else { return }
                    publisher.send(Transaction(transaction: transaction))
                case .deleted:
                    publisher.send(completion: .failure(.objectDeleted))
                case .error(let e):
                    publisher.send(completion: .failure(.general(error: e)))
                }
            }
        }

        return publisher
            .handleEvents(receiveCancel: {
                notificationToken?.invalidate()
            }).eraseToAnyPublisher()
    }

    public func transactions(forFilter filter: TransactionsFilterStrategy, servers: [RPCServer], oldestBlockNumber: Int? = nil) -> [Transaction] {
        let predicate: NSPredicate = filter.predicate(servers: servers, oldestBlockNumber: oldestBlockNumber)
        var transactions: [Transaction] = []

        store.performSync { realm in
            transactions = realm.objects(TransactionObject.self)
                .filter(predicate)
                .sorted(byKeyPath: "date", ascending: false)
                .map { Transaction(transaction: $0) }

        }

        return transactions
    }

    public func transactions(forServer server: RPCServer, withTransactionState transactionState: TransactionState) -> [Transaction] {
        var transactions: [Transaction] = []
        store.performSync { realm in
            transactions = realm.objects(TransactionObject.self)
                .filter(TransactionDataStore.functional.transactionPredicate(server: server, transactionState: transactionState))
                .sorted(byKeyPath: "date", ascending: false)
                .map { Transaction(transaction: $0) }
        }

        return transactions
    }

    public func lastTransaction(forServer server: RPCServer) -> Transaction? {
        var transaction: Transaction?
        store.performSync { realm in
            transaction = realm.objects(TransactionObject.self)
                .filter(TransactionDataStore.functional.nonEmptyIdTransactionPredicate(server: server))
                .sorted(byKeyPath: "date", ascending: false)
                .map { Transaction(transaction: $0) }
                .last
        }

        return transaction
    }

    public func hasCompletedTransaction(withNonce nonce: String, forServer server: RPCServer) -> Bool {
        let predicate = TransactionDataStore
            .functional
            .transactionPredicate(server: server, transactionState: .completed, nonce: nonce)
        var hasCompletedTransaction: Bool = false

        store.performSync { realm in
            hasCompletedTransaction = !realm.objects(TransactionObject.self)
                .filter(predicate)
                .isEmpty
        }
        return hasCompletedTransaction
    }

    public func transactionObjectsThatDoNotComeFromEventLogs(forServer server: RPCServer) -> Transaction? {
        let predicate = TransactionDataStore
            .functional
            .nonERC20InteractionTransactionPredicate(server: server, transactionState: .completed)

        var transaction: Transaction?

        store.performSync { realm in
            transaction = realm.objects(TransactionObject.self)
                .filter(predicate)
                .sorted(byKeyPath: "date", ascending: false)
                .map { Transaction(transaction: $0) }
                .first
        }

        return transaction
    }

    public func transaction(withTransactionId transactionId: String, forServer server: RPCServer) -> Transaction? {
        let predicate = TransactionDataStore
            .functional
            .transactionPredicate(withTransactionId: transactionId, server: server)
        var transaction: Transaction?
        store.performSync { realm in
            transaction = realm.objects(TransactionObject.self)
                .filter(predicate)
                .sorted(byKeyPath: "date", ascending: false)
                .map { Transaction(transaction: $0) }
                .first
        }
        return transaction
    }

    public func deleteAll() {
        store.performSync { realm in
            let objects = realm.objects(TransactionObject.self)
            try? realm.safeWrite {
                realm.delete(objects)
            }
        }
    }

    public func delete(transactions: [Transaction]) {
        guard !transactions.isEmpty else { return }

        store.performSync { realm in
            let objects = transactions.compactMap { realm.object(ofType: TransactionObject.self, forPrimaryKey: $0.primaryKey) }
            guard !objects.isEmpty else { return }

            try? realm.safeWrite {
                realm.delete(objects)
            }
        }
    }

    public func update(state: TransactionState, for primaryKey: String, pendingTransaction: EthereumTransaction) {
        store.performSync { realm in
            guard let value = realm.object(ofType: TransactionObject.self, forPrimaryKey: primaryKey) else { return }
            try? realm.safeWrite {
                value.gas = pendingTransaction.gas
                if let value = value.gasPrice {
                    realm.delete(value)
                }

                value.gasPrice = pendingTransaction.gasPrice.flatMap { GasPriceObject(gasPrice: $0, primaryKey: primaryKey) }
                value.nonce = pendingTransaction.nonce
                //We assume that by the time we get here, the block number is valid
                value.blockNumber = Int(pendingTransaction.blockNumber)!

                value.internalState = state.rawValue
            }
        }
    }

    @discardableResult func addOrUpdate(transactions: [Transaction]) -> [Transaction] {
        guard !transactions.isEmpty else { return [] }

        var transactionsToReturn: [Transaction] = []

        store.performSync { realm in
            transactionsToReturn = self.filterTransactionsToNotOverrideErc20Transactions(transactions, realm: realm)
            guard !transactionsToReturn.isEmpty else { return }

            let transactionsToCommit = transactionsToReturn.map { TransactionObject(transaction: $0) }
            try? realm.safeWrite {
                for each in transactionsToCommit {
                    if let tx = realm.object(ofType: TransactionObject.self, forPrimaryKey: each.primaryKey) {
                        realm.delete(tx.localizedOperations)
                    }
                    realm.add(each, update: .all)
                }
            }
        }
        return transactionsToReturn
    }

    //We pull transactions data from the normal transactions API as well as ERC20 event log. For the same transaction, we only want data from the latter. Otherwise the UI will show the cell display switching between data from the 2 source as we fetch (or re-fetch)
    private func filterTransactionsToNotOverrideErc20Transactions(_ transactions: [Transaction], realm: Realm) -> [Transaction] {
        return transactions.filter { each in
            if each.isERC20Interaction {
                return true
            } else {
                if let tx = realm.object(ofType: TransactionObject.self, forPrimaryKey: each.primaryKey) {
                    return each.blockNumber != tx.blockNumber && each.blockNumber != 0
                } else {
                    return true
                }
            }
        }
    }

    @discardableResult public func add(transactions: [Transaction]) -> [Transaction] {
        guard !transactions.isEmpty else { return [] }

        let transactionsToCommit = transactions.map { TransactionObject(transaction: $0) }
        store.performSync { realm in
            try? realm.safeWrite {
                for each in transactionsToCommit {
                    if let tx = realm.object(ofType: TransactionObject.self, forPrimaryKey: each.primaryKey) {
                        realm.delete(tx.localizedOperations)
                    }
                    realm.add(each, update: .all)
                }
            }
        }

        return transactions
    }

    public func removeTransactions(for states: [TransactionState], servers: [RPCServer]) {
        store.performSync { realm in
            let objects = realm.objects(TransactionObject.self)
                .filter("chainId IN %@", servers.map { $0.chainID })
                .filter { states.contains($0.state) }

            try? realm.safeWrite {
                realm.delete(objects)
            }
        }
    }

    public func deleteAllForTestsOnly() {
        store.performSync { realm in
            try? realm.safeWrite {
                realm.delete(realm.objects(LocalizedOperationObject.self))
                realm.delete(realm.objects(TransactionObject.self))
            }
        }
    }

    public func writeJsonForTransactions(toUrl url: URL, server: RPCServer) {
        do {
            let data = try functional.generateJsonForTransactions(transactionStorage: self, server: server, toUrl: url)
            try data.write(to: url)
            verboseLog("Written transactions for \(server) to JSON to: \(url.absoluteString)")
        } catch {
            warnLog("Error writing transactions for \(server) to JSON: \(url.absoluteString) error: \(error)")
        }
    }
}

extension TransactionDataStore: Erc721TokenIdsFetcher {
    public func tokenIdsForErc721Token(contract: AlphaWallet.Address, forServer server: RPCServer, inAccount account: AlphaWallet.Address) -> AnyPublisher<[String], Never> {
        Future { [store] seal in
            //Important to sort ascending to figure out ownership from transfers in and out
            //TODO is this really slow? getting all transactions, right?
            //TODO why are some isERC20Interaction = false
            var tokenIds: Set<String> = .init()
            store.performSync { realm in
                let transactions = realm.objects(TransactionObject.self)
                    .filter(TransactionDataStore.functional.transactionPredicate(server: server, operationContract: contract))
                    .sorted(byKeyPath: "date", ascending: true)

                let operations: [LocalizedOperationObject] = transactions
                    .flatMap { $0.localizedOperations.filter { $0.contractAddress == contract } }

                for each in operations {
                    let tokenId = each.tokenId
                    guard !tokenId.isEmpty else { continue }
                    if account.sameContract(as: each.from) && account.sameContract(as: each.to) {
                        //no-op
                    } else if account.sameContract(as: each.from) {
                        tokenIds.remove(tokenId)
                    } else if account.sameContract(as: each.to) {
                        tokenIds.insert(tokenId)
                    } else {
                        //no-op
                    }
                }
            }

            seal(.success(Array(tokenIds)))
        }.eraseToAnyPublisher()
    }
}

extension TransactionDataStore {
    public enum functional {}
}

extension TransactionDataStore.functional {

    public static func transactionsFilter(for strategy: ActivitiesFilterStrategy, token: Token) -> TransactionsFilterStrategy {
        return .filter(strategy: strategy, token: token)
    }

    public static func generateJsonForTransactions(transactionStorage: TransactionDataStore, server: RPCServer, toUrl url: URL) throws -> Data {
        struct Operation: Encodable {
            let from: String
            let to: String
            let contract: String
            let tokenId: String
        }
        struct TransactionObject: Encodable {
            let transactionHash: String
            let operations: [Operation]
        }

        let transactions = transactionStorage.transactions(forServer: server, sortedDateAscending: true)
        let transactionsToWrite: [TransactionObject] = transactions.map { eachTransaction in
            let operations = eachTransaction.localizedOperations
            let operationsToWrite: [Operation] = operations.map { eachOp in
                .init(from: eachOp.from, to: eachOp.to, contract: eachOp.contractAddress?.eip55String ?? "", tokenId: eachOp.tokenId)
            }
            return .init(transactionHash: eachTransaction.id, operations: operationsToWrite)
        }
        return try JSONEncoder().encode(transactionsToWrite)
    }

    static func chainIdPredicate(server: RPCServer) -> NSPredicate {
        return NSPredicate(format: "chainId = \(server.chainID)")
    }

    static func chainIdPredicate(servers: [RPCServer]) -> NSPredicate {
        return NSPredicate(format: "chainId IN %@", servers.map { $0.chainID })
    }

    static func transactionIdPredicate(transactionId: String) -> NSPredicate {
        return NSPredicate(format: "id == '\(transactionId)'")
    }

    static func transactionIdNonEmptyPredicate() -> NSPredicate {
        return NSPredicate(format: "id != ''")
    }

    static func nonERC20InteractionPredicate() -> NSPredicate {
        return NSPredicate(format: "isERC20Interaction == false")
    }

    static func noncePredicate(nonce: String) -> NSPredicate {
        return NSPredicate(format: "nonce == '\(nonce)'")
    }

    public static func blockNumberPredicate(blockNumber: Int) -> NSPredicate {
        return NSPredicate(format: "blockNumber > \(blockNumber)")
    }

    static func nonEmptyIdTransactionPredicate(server: RPCServer) -> NSPredicate {
        return NSCompoundPredicate(andPredicateWithSubpredicates: [
            chainIdPredicate(server: server),
            transactionIdNonEmptyPredicate()
        ])
    }

    static func nonEmptyIdTransactionPredicate(servers: [RPCServer]) -> NSPredicate {
        return NSCompoundPredicate(andPredicateWithSubpredicates: [
            chainIdPredicate(servers: servers),
            transactionIdNonEmptyPredicate()
        ])
    }

    static func transactionPredicate(withTransactionId transactionId: String, server: RPCServer) -> NSPredicate {
        return NSCompoundPredicate(andPredicateWithSubpredicates: [
            chainIdPredicate(server: server),
            transactionIdPredicate(transactionId: transactionId)
        ])
    }

    static func nonERC20InteractionTransactionPredicate(server: RPCServer, transactionState: TransactionState) -> NSPredicate {
        return NSCompoundPredicate(andPredicateWithSubpredicates: [
            nonEmptyIdTransactionPredicate(server: server),
            nonERC20InteractionPredicate(),
            TransactionState.predicate(for: transactionState)
        ])
    }

    static func transactionPredicate(server: RPCServer, transactionState: TransactionState, nonce: String) -> NSPredicate {
        return NSCompoundPredicate(andPredicateWithSubpredicates: [
            nonEmptyIdTransactionPredicate(server: server),
            noncePredicate(nonce: nonce),
            TransactionState.predicate(for: transactionState)
        ])
    }

    static func transactionPredicate(server: RPCServer, transactionState: TransactionState) -> NSPredicate {
        return NSCompoundPredicate(andPredicateWithSubpredicates: [
            nonEmptyIdTransactionPredicate(server: server),
            TransactionState.predicate(for: transactionState)
        ])
    }

    static func transactionPredicate(server: RPCServer, operationContract: AlphaWallet.Address) -> NSPredicate {
        return NSCompoundPredicate(andPredicateWithSubpredicates: [
            chainIdPredicate(server: server),
            transactionIdNonEmptyPredicate(),
            NSPredicate(format: "ANY localizedOperations.contract == '\(operationContract.eip55String)'")
        ])
    }
}

extension TransactionState {
    public static func predicate(state: TransactionState) -> NSPredicate {
        return NSPredicate(format: "internalState == \(state.rawValue)")
    }
}
