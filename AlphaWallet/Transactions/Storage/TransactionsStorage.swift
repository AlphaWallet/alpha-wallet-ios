import Foundation
import BigInt
import RealmSwift
import PromiseKit
import Combine

class TransactionDataStore {
    //TODO if we move this to instance-side, we have to be careful it's the same instance we are accessing, otherwise we wouldn't find the pending transaction information when we need it
    static var pendingTransactionsInformation: [String: (server: RPCServer, data: Data, transactionType: TransactionType, gasPrice: BigInt)] = .init()

    private let realm: Realm

    init(realm: Realm) {
        self.realm = realm
    }

    func transactionCount(forServer server: RPCServer) -> Int {
        return transactions(forServer: server).count
    }

    func transactions(forServer server: RPCServer) -> Results<Transaction> {
        return realm.objects(Transaction.self)
            .filter(TransactionDataStore.functional.nonEmptyIdTransactionPredicate(server: server))
            .sorted(byKeyPath: "date", ascending: false)
    }

    func transactionsChangesetPublisher(forFilter filter: TransactionsFilterStrategy, servers: [RPCServer]) -> AnyPublisher<ChangeSet<[Transaction]>, Never> {
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

        return realm.threadSafe.objects(Transaction.self)
            .filter(predicate)
            .sorted(byKeyPath: "date", ascending: false)
            .changesetPublisher
            .map { change in
                switch change {
                case .initial(let transactions):
                    return .initial(Array(transactions.map { $0.freeze() }))
                case .update(let transactions, let deletions, let insertions, let modifications):
                    return .update(Array(transactions.map { $0.freeze() }), deletions: deletions, insertions: insertions, modifications: modifications)
                case .error(let error):
                    return .error(error)
                }
            } 
            .eraseToAnyPublisher()
    }

    func transactionsPublisher(forFilter filter: TransactionsFilterStrategy, servers: [RPCServer], oldestBlockNumber: Int? = nil) -> AnyPublisher<[Transaction], Error> {
        let oldestBlockNumberPredicate = oldestBlockNumber.flatMap { [TransactionDataStore.functional.blockNumberPredicate(blockNumber: $0)] } ?? []
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

        return realm.threadSafe.objects(Transaction.self)
            .filter(predicate)
            .sorted(byKeyPath: "date", ascending: false)
            .collectionPublisher
            .map { Array($0.freeze()) }
            .eraseToAnyPublisher()
    }

    func transactions(forServer server: RPCServer, withTransactionState transactionState: TransactionState) -> [TransactionInstance] {
        return realm.objects(Transaction.self)
            .filter(TransactionDataStore.functional.transactionPredicate(server: server, transactionState: transactionState))
            .sorted(byKeyPath: "date", ascending: false)
            .map { TransactionInstance(transaction: $0) }
    }

    func lastTransaction(forServer server: RPCServer, withTransactionState transactionState: TransactionState) -> TransactionInstance? {
        return realm.objects(Transaction.self)
            .filter(TransactionDataStore.functional.transactionPredicate(server: server, transactionState: transactionState))
            .sorted(byKeyPath: "date", ascending: false)
            .last
            .map { TransactionInstance(transaction: $0) }
    }

    func hasCompletedTransaction(withNonce nonce: String, forServer server: RPCServer) -> Bool {
        let predicate = TransactionDataStore
            .functional
            .transactionPredicate(server: server, transactionState: .completed, nonce: nonce)

        return !realm.objects(Transaction.self)
            .filter(predicate)
            .isEmpty
    }

    func transactionObjectsThatDoNotComeFromEventLogs(forServer server: RPCServer) -> TransactionInstance? {
        let predicate = TransactionDataStore
            .functional
            .nonERC20InteractionTransactionPredicate(server: server, transactionState: .completed)

        return realm.objects(Transaction.self)
            .filter(predicate)
            .sorted(byKeyPath: "date", ascending: false)
            .map { TransactionInstance(transaction: $0) }
            .first
    }

    func firstTransactions(forServer server: RPCServer) -> TransactionInstance? {
        let predicate = TransactionDataStore
            .functional
            .nonEmptyIdTransactionPredicate(server: server)

        return realm.objects(Transaction.self)
            .filter(predicate)
            .sorted(byKeyPath: "date", ascending: false)
            .map { TransactionInstance(transaction: $0) }
            .first
    }

    func transaction(withTransactionId transactionId: String, forServer server: RPCServer) -> TransactionInstance? {
        let predicate = TransactionDataStore
            .functional
            .transactionPredicate(withTransactionId: transactionId, server: server)

        return realm.objects(Transaction.self)
            .filter(predicate) 
            .sorted(byKeyPath: "date", ascending: false)
            .map { TransactionInstance(transaction: $0) }
            .first
    }

    func delete(transactions: [TransactionInstance]) {
        let objects = transactions.compactMap {
            realm.object(ofType: Transaction.self, forPrimaryKey: $0.primaryKey)
        }

        realm.beginWrite()
        realm.delete(objects)
        try? realm.commitWrite()
    }

    func update(state: TransactionState, for primaryKey: String, withPendingTransaction pendingTransaction: PendingTransaction?) {
        guard let value = realm.object(ofType: Transaction.self, forPrimaryKey: primaryKey) else { return }
        realm.beginWrite()

        if let pendingTransaction = pendingTransaction {
            value.gas = pendingTransaction.gas
            value.gasPrice = pendingTransaction.gasPrice
            value.nonce = pendingTransaction.nonce
            //We assume that by the time we get here, the block number is valid
            value.blockNumber = Int(pendingTransaction.blockNumber)!
        }
        value.internalState = state.rawValue

        try? realm.commitWrite()
    }

    func addOrUpdate(transactions: [TransactionInstance]) {
        let newTransactions = transactions.map { Transaction(object: $0) }
        let transactionsToCommit = filterTransactionsToNotOverrideERC20Transactions(newTransactions, realm: realm)
        guard !transactionsToCommit.isEmpty else { return }

        realm.beginWrite()
        realm.add(transactionsToCommit, update: .all)

        try! realm.commitWrite()
    }

    //We pull transactions data from the normal transactions API as well as ERC20 event log. For the same transaction, we only want data from the latter. Otherwise the UI will show the cell display switching between data from the 2 source as we fetch (or re-fetch)
    private func filterTransactionsToNotOverrideERC20Transactions(_ transactions: [Transaction], realm: Realm) -> [Transaction] {
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

    @discardableResult func add(transactions: [Transaction]) -> [Transaction] {
        guard !transactions.isEmpty else { return [] }
        realm.beginWrite()
        realm.add(transactions, update: .all)
        try! realm.commitWrite()
        return transactions
    }

    func delete(_ items: [Transaction]) {
        guard !items.isEmpty else { return }
        try! realm.write {
            realm.delete(items)
        }
    }

    func removeTransactions(for states: [TransactionState], servers: [RPCServer]) {
        let objects = realm.objects(Transaction.self)
            .filter("chainId IN %@", servers.map { $0.chainID })
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

    func writeJsonForTransactions(toUrl url: URL, server: RPCServer) {
        do {
            let data = try functional.generateJsonForTransactions(transactionStorage: self, server: server, toUrl: url)
            try data.write(to: url)
            verboseLog("Written transactions for \(server) to JSON to: \(url.absoluteString)")
        } catch {
            verboseLog("Error writing transactions for \(server) to JSON: \(url.absoluteString) error: \(error)")
        }
    }

    static func deleteAllTransactions(realm: Realm, config: Config) {
        let transactionsStorage = TransactionDataStore(realm: realm)
        transactionsStorage.deleteAll()
    }
}

extension TransactionDataStore: Erc721TokenIdsFetcher {
    func tokenIdsForErc721Token(contract: AlphaWallet.Address, forServer server: RPCServer, inAccount account: AlphaWallet.Address) -> Promise<[String]> {
        Promise { seal in
            //Important to sort ascending to figure out ownership from transfers in and out
            //TODO is this really slow? getting all transactions, right?
            //TODO why are some isERC20Interaction = false
            DispatchQueue.main.async {
                let transactions = self.realm.objects(Transaction.self)
                    .filter(TransactionDataStore.functional.transactionPredicate(server: server, operationContract: contract))
                    .sorted(byKeyPath: "date", ascending: true)

                let operations: [LocalizedOperationObject] = transactions
                    .flatMap { $0.localizedOperations.filter { $0.contractAddress?.sameContract(as: contract) ?? false } }

                var tokenIds: Set<String> = .init()
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

                seal.fulfill(Array(tokenIds))
            }
        }
    }
}

extension TransactionDataStore {
    class functional {}
}

extension TransactionDataStore.functional {

    static func transactionsFilter(for strategy: ActivitiesFilterStrategy, tokenObject: TokenObject) -> TransactionsFilterStrategy {
        return .filter(strategy: strategy, tokenObject: tokenObject)
    }

    static func generateJsonForTransactions(transactionStorage: TransactionDataStore, server: RPCServer, toUrl url: URL) throws -> Data {
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

        let transactions = transactionStorage.transactions(forServer: server).sorted(byKeyPath: "date", ascending: true)
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
