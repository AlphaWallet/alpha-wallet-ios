import Foundation
import BigInt
import RealmSwift
import PromiseKit
import Combine

open class TransactionDataStore {
    //TODO if we move this to instance-side, we have to be careful it's the same instance we are accessing, otherwise we wouldn't find the pending transaction information when we need it
    public static var pendingTransactionsInformation: [String: (server: RPCServer, data: Data, transactionType: TransactionType, gasPrice: BigInt)] = .init()

    private let store: RealmStore

    public init(store: RealmStore) {
        self.store = store
    }

    public func transactionCount(forServer server: RPCServer) -> Int {
        return transactions(forServer: server).count
    }

    public func transactions(forServer server: RPCServer, sortedDateAscending: Bool = false) -> [TransactionInstance] {
        var results: [TransactionInstance] = []
        store.performSync { realm in
            results = realm.objects(Transaction.self)
                .filter(TransactionDataStore.functional.nonEmptyIdTransactionPredicate(server: server))
                .sorted(byKeyPath: "date", ascending: sortedDateAscending)
                .map { TransactionInstance(transaction: $0) }
        }

        return results
    }

    public func transactionsChangeset(forFilter filter: TransactionsFilterStrategy, servers: [RPCServer]) -> AnyPublisher<ChangeSet<[TransactionInstance]>, Never> {
        let predicate: NSPredicate
        switch filter {
        case .filter(let filter, let tokenObject):
            predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                TransactionDataStore.functional.nonEmptyIdTransactionPredicate(server: tokenObject.server),
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

        var publisher: AnyPublisher<ChangeSet<[TransactionInstance]>, Never>!
        store.performSync { realm in
            publisher = realm.objects(Transaction.self)
                .filter(predicate)
                .sorted(byKeyPath: "date", ascending: false)
                .changesetPublisher
                .freeze()
                .receive(on: DispatchQueue.global())
                .map { change in
                    switch change {
                    case .initial(let transactions):
                        return .initial(Array(transactions.map { TransactionInstance(transaction: $0) }))
                    case .update(let transactions, let deletions, let insertions, let modifications):
                        return .update(Array(transactions.map { TransactionInstance(transaction: $0) }), deletions: deletions, insertions: insertions, modifications: modifications)
                    case .error(let error):
                        return .error(error)
                    }
                }.eraseToAnyPublisher()
        }

        return publisher
    }

    public func transactions(forFilter filter: TransactionsFilterStrategy, servers: [RPCServer], oldestBlockNumber: Int? = nil) -> [TransactionInstance] {
        //NOTE: Allow pending transactions othewise it willn't appear as activity
        let isPendingTransction = NSPredicate(format: "blockNumber == 0")
        let oldestBlockNumberPredicate = oldestBlockNumber.flatMap {
            [
                NSCompoundPredicate(orPredicateWithSubpredicates: [TransactionDataStore.functional.blockNumberPredicate(blockNumber: $0), isPendingTransction])
            ]
        } ?? []

        let predicate: NSPredicate
        switch filter {
        case .filter(let filter, let tokenObject):
            predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                TransactionDataStore.functional.nonEmptyIdTransactionPredicate(server: tokenObject.server),
                filter.predicate
            ] + oldestBlockNumberPredicate)
        case .all:
            predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                TransactionDataStore.functional.nonEmptyIdTransactionPredicate(servers: servers)
            ] + oldestBlockNumberPredicate)
        case .predicate(let p):
            predicate = p
        }

        var transactions: [TransactionInstance] = []
        store.performSync { realm in
            transactions = realm.objects(Transaction.self)
                .filter(predicate)
                .sorted(byKeyPath: "date", ascending: false)
                .map { TransactionInstance(transaction: $0) }

        }

        return transactions
    }

    public func transactions(forServer server: RPCServer, withTransactionState transactionState: TransactionState) -> [TransactionInstance] {
        var transactions: [TransactionInstance] = []
        store.performSync { realm in
            transactions = realm.objects(Transaction.self)
                .filter(TransactionDataStore.functional.transactionPredicate(server: server, transactionState: transactionState))
                .sorted(byKeyPath: "date", ascending: false)
                .map { TransactionInstance(transaction: $0) }
        }

        return transactions
    }

    public func lastTransaction(forServer server: RPCServer, withTransactionState transactionState: TransactionState) -> TransactionInstance? {
        var transaction: TransactionInstance?
        store.performSync { realm in
            transaction = realm.objects(Transaction.self)
                .filter(TransactionDataStore.functional.transactionPredicate(server: server, transactionState: transactionState))
                .sorted(byKeyPath: "date", ascending: false)
                .map { TransactionInstance(transaction: $0) }
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
            hasCompletedTransaction = !realm.objects(Transaction.self)
                .filter(predicate)
                .isEmpty
        }
        return hasCompletedTransaction
    }

    public func transactionObjectsThatDoNotComeFromEventLogs(forServer server: RPCServer) -> TransactionInstance? {
        let predicate = TransactionDataStore
            .functional
            .nonERC20InteractionTransactionPredicate(server: server, transactionState: .completed)

        var transaction: TransactionInstance?

        store.performSync { realm in
            transaction = realm.objects(Transaction.self)
                .filter(predicate)
                .sorted(byKeyPath: "date", ascending: false)
                .map { TransactionInstance(transaction: $0) }
                .first
        }

        return transaction
    }

    public func firstTransactions(forServer server: RPCServer) -> TransactionInstance? {
        let predicate = TransactionDataStore
            .functional
            .nonEmptyIdTransactionPredicate(server: server)

        var transaction: TransactionInstance?

        store.performSync { realm in
            transaction = realm.objects(Transaction.self)
                .filter(predicate)
                .sorted(byKeyPath: "date", ascending: false)
                .map { TransactionInstance(transaction: $0) }
                .first
        }

        return transaction
    }

    public func transaction(withTransactionId transactionId: String, forServer server: RPCServer) -> TransactionInstance? {
        let predicate = TransactionDataStore
            .functional
            .transactionPredicate(withTransactionId: transactionId, server: server)
        var transaction: TransactionInstance?
        store.performSync { realm in
            transaction = realm.objects(Transaction.self)
                .filter(predicate)
                .sorted(byKeyPath: "date", ascending: false)
                .map { TransactionInstance(transaction: $0) }
                .first
        }
        return transaction
    }

    public func delete(transactions: [TransactionInstance]) {
        guard !transactions.isEmpty else { return }

        store.performSync { realm in
            let objects = transactions.compactMap { realm.object(ofType: Transaction.self, forPrimaryKey: $0.primaryKey) }
            try? realm.safeWrite {
                realm.delete(objects)
            }
        }
    }

    public func update(state: TransactionState, for primaryKey: String, withPendingTransaction pendingTransaction: PendingTransaction?) {
        store.performSync { realm in
            guard let value = realm.object(ofType: Transaction.self, forPrimaryKey: primaryKey) else { return }
            try? realm.safeWrite {
                if let pendingTransaction = pendingTransaction {
                    value.gas = pendingTransaction.gas
                    value.gasPrice = pendingTransaction.gasPrice
                    value.nonce = pendingTransaction.nonce
                    //We assume that by the time we get here, the block number is valid
                    value.blockNumber = Int(pendingTransaction.blockNumber)!
                }
                value.internalState = state.rawValue
            }
        }
    }

    @discardableResult func addOrUpdate(transactions: [TransactionInstance]) -> [TransactionInstance] {
        guard !transactions.isEmpty else { return [] }

        var transactionsToReturn: [TransactionInstance] = []

        store.performSync { realm in
            transactionsToReturn = self.filterTransactionsToNotOverrideERC20Transactions(transactions, realm: realm)
            guard !transactionsToReturn.isEmpty else { return }

            let transactionsToCommit = transactionsToReturn.map { Transaction(object: $0) }
            try? realm.safeWrite {
                realm.add(transactionsToCommit, update: .all)
            }
        }
        return transactionsToReturn
    }

    //We pull transactions data from the normal transactions API as well as ERC20 event log. For the same transaction, we only want data from the latter. Otherwise the UI will show the cell display switching between data from the 2 source as we fetch (or re-fetch)
    private func filterTransactionsToNotOverrideERC20Transactions(_ transactions: [TransactionInstance], realm: Realm) -> [TransactionInstance] {
        return transactions.filter { each in
            if each.isERC20Interaction {
                return true
            } else {
                if let tx = realm.object(ofType: Transaction.self, forPrimaryKey: each.primaryKey) {
                    return each.blockNumber != tx.blockNumber && each.blockNumber != 0
                } else {
                    return true
                }
            }
        }
    }

    @discardableResult public func add(transactions: [TransactionInstance]) -> [TransactionInstance] {
        guard !transactions.isEmpty else { return [] }

        let transactionsToAdd = transactions.map { Transaction(object: $0) }
        store.performSync { realm in
            try? realm.safeWrite {
                realm.add(transactionsToAdd, update: .all)
            }
        }

        return transactions
    }

    public func delete(_ transactions: [TransactionInstance]) {
        guard !transactions.isEmpty else { return }

        store.performSync { realm in
            try? realm.safeWrite {
                let transactionsToDelete = transactions.compactMap { realm.object(ofType: Transaction.self, forPrimaryKey: $0.primaryKey) }
                realm.delete(transactionsToDelete)
            }
        }
    }

    public func removeTransactions(for states: [TransactionState], servers: [RPCServer]) {
        store.performSync { realm in
            let objects = realm.objects(Transaction.self)
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
                realm.delete(realm.objects(Transaction.self))
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
    public func tokenIdsForErc721Token(contract: AlphaWallet.Address, forServer server: RPCServer, inAccount account: AlphaWallet.Address) -> Promise<[String]> {
        Promise { seal in
            //Important to sort ascending to figure out ownership from transfers in and out
            //TODO is this really slow? getting all transactions, right?
            //TODO why are some isERC20Interaction = false
            var tokenIds: Set<String> = .init()
            store.performSync { realm in
                let transactions = realm.objects(Transaction.self)
                    .filter(TransactionDataStore.functional.transactionPredicate(server: server, operationContract: contract))
                    .sorted(byKeyPath: "date", ascending: true)

                let operations: [LocalizedOperationObject] = transactions
                    .flatMap { $0.localizedOperations.filter { $0.contractAddress?.sameContract(as: contract) ?? false } }

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

            seal.fulfill(Array(tokenIds))
        }
    }
}

extension TransactionDataStore {
    public class functional {}
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
        struct Transaction: Encodable {
            let transactionHash: String
            let operations: [Operation]
        }

        let transactions = transactionStorage.transactions(forServer: server, sortedDateAscending: true)
        let transactionsToWrite: [Transaction] = transactions.map { eachTransaction in
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

    static func blockNumberPredicate(blockNumber: Int) -> NSPredicate {
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
    static func predicate(state: TransactionState) -> NSPredicate {
        return NSPredicate(format: "internalState == \(state.rawValue)")
    }
}
