import Foundation
import BigInt
import RealmSwift
import PromiseKit

protocol TransactionsStorageDelegate: AnyObject {
    func didAddTokensWith(contracts: [AlphaWallet.Address], inTransactionsStorage: TransactionsStorage)
}

class TransactionsStorage: Hashable {

    static func == (lhs: TransactionsStorage, rhs: TransactionsStorage) -> Bool {
        return lhs.server == rhs.server && lhs.realm == rhs.realm
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(server.chainID)
    }

    //TODO if we move this to instance-side, we have to be careful it's the same instance we are accessing, otherwise we wouldn't find the pending transaction information when we need it
    static var pendingTransactionsInformation: [String: (server: RPCServer, data: Data, transactionType: TransactionType, gasPrice: BigInt)] = .init()

    private let realm: Realm
    weak var delegate: TransactionsStorageDelegate?

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
        return realm.objects(Transaction.self)
            .filter(TransactionsStorage.functional.nonEmptyIdTransactionPredicate(server: server))
            .sorted(byKeyPath: "date", ascending: false)
    }

    var completedObjects: Promise<[TransactionInstance]> {
        return Promise { seal in
            DispatchQueue.main.async { [weak self] in
                guard let strongSelf = self else { return seal.reject(PMKError.cancelled) }

                let completedTransactions = strongSelf.realm.objects(Transaction.self)
                    .filter(TransactionsStorage.functional.transactionPredicate(server: strongSelf.server, transactionState: .completed))
                    .sorted(byKeyPath: "date", ascending: false)
                    .map { TransactionInstance(transaction: $0) }

                seal.fulfill(Array(completedTransactions))
            }
        }
    }

    var pendingObjects: Promise<[TransactionInstance]> {
        return Promise { seal in
            DispatchQueue.main.async { [weak self] in
                guard let strongSelf = self else { return seal.reject(PMKError.cancelled) }

                let pendingTransactions = strongSelf.realm.objects(Transaction.self)
                    .filter(TransactionsStorage.functional.transactionPredicate(server: strongSelf.server, transactionState: .pending))
                    .sorted(byKeyPath: "date", ascending: false)
                    .map { TransactionInstance(transaction: $0) }

                seal.fulfill(Array(pendingTransactions))
            }
        }
    }

    func hasCompletedTransaction(withNonce nonce: String) -> Promise<Bool> {
        return Promise { seal in
            DispatchQueue.main.async { [weak self] in
                guard let strongSelf = self else { return seal.reject(PMKError.cancelled) }
                let predicate = TransactionsStorage
                    .functional
                    .transactionPredicate(server: strongSelf.server, transactionState: .completed, nonce: nonce)

                let value = !strongSelf.realm.objects(Transaction.self)
                        .filter(predicate)
                        .isEmpty

                seal.fulfill(value)
            }
        }
    }

    func transactionObjectsThatDoNotComeFromEventLogs() -> Promise<TransactionInstance?> {
        return Promise { seal in
            DispatchQueue.main.async { [weak self] in
                guard let strongSelf = self else { return seal.reject(PMKError.cancelled) }
                let predicate = TransactionsStorage
                    .functional
                    .nonERC20InteractionTransactionPredicate(server: strongSelf.server, transactionState: .completed)

                let transaction = strongSelf.realm.objects(Transaction.self)
                    .filter(predicate)
                    .sorted(byKeyPath: "date", ascending: false)
                    .map { TransactionInstance(transaction: $0) }
                    .first

                seal.fulfill(transaction)
            }
        }
    }

    var transactions: Promise<[TransactionInstance]> {
        return Promise { seal in
            DispatchQueue.main.async { [weak self] in
                guard let strongSelf = self else { return seal.reject(PMKError.cancelled) }
                let predicate = TransactionsStorage
                    .functional
                    .nonEmptyIdTransactionPredicate(server: strongSelf.server)

                let transactions = strongSelf.realm.objects(Transaction.self)
                    .filter(predicate)
                    .sorted(byKeyPath: "date", ascending: false)
                    .map { TransactionInstance(transaction: $0) }

                seal.fulfill(Array(transactions))
            }
        }
    }

    func transaction(withTransactionId transactionId: String) -> TransactionInstance? {
        let predicate = TransactionsStorage
            .functional
            .transactionPredicate(withTransactionId: transactionId, server: server)

        return realm.objects(Transaction.self)
            .filter(predicate) 
            .sorted(byKeyPath: "date", ascending: false)
            .map { TransactionInstance(transaction: $0) }
            .first
    }

    func delete(transactions: [TransactionInstance]) -> Promise<Void> {
        return Promise { seal in
            DispatchQueue.main.async { [weak self] in
                guard let strongSelf = self else { return seal.reject(PMKError.cancelled) }

                let realm = strongSelf.realm
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
    }

    func update(state: TransactionState, for primaryKey: String, withPendingTransaction pendingTransaction: PendingTransaction?) -> Promise<TransactionInstance> {
        enum AnyError: Error {
            case invalid
        }

        return Promise { seal in
            DispatchQueue.main.async { [weak self] in
                guard let strongSelf = self else { return seal.reject(PMKError.cancelled) }
                let realm = strongSelf.realm
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
                    let transaction = TransactionInstance(transaction: value)

                    do {
                        try realm.commitWrite()

                        seal.fulfill(transaction)
                    } catch {
                        seal.reject(error)
                    }
                } else {
                    seal.reject(AnyError.invalid)
                }
            }
        }
    }

    func add(transactions: [TransactionInstance], transactionsToPullContractsFrom: [TransactionInstance], contractsAndTokenTypes: [AlphaWallet.Address: TokenType]) {
        guard !transactions.isEmpty else { return }
        let newTransactions = transactions.map { Transaction(object: $0) }
        let newTransactionsToPullContractsFrom = transactionsToPullContractsFrom.map { Transaction(object: $0) }
        let transactionsToCommit = filterTransactionsToNotOverrideERC20Transactions(newTransactions, realm: realm)
        realm.beginWrite()
        realm.add(transactionsToCommit, update: .all)
        //NOTE: move adding transactions under single write realm transaction
        addTokensWithContractAddresses(fromTransactions: newTransactionsToPullContractsFrom, contractsAndTokenTypes: contractsAndTokenTypes, realm: realm)

        try! realm.commitWrite()
    }

    private func updateTransactionsWithoutCommitWrite(in realm: Realm, tokens: [TokenUpdate]) {
        for token in tokens {
            //Even though primaryKey is provided, it is important to specific contract because this might be creating a new TokenObject instance from transactions
            let update: [String: Any] = [
                "primaryKey": token.primaryKey,
                "contract": token.address.eip55String,
                "chainId": token.server.chainID,
                "name": token.name,
                "symbol": token.symbol,
                "decimals": token.decimals,
                "rawType": token.tokenType.rawValue,
            ]
            realm.create(TokenObject.self, value: update, update: .all)
        }
    }

    private func addTokensWithContractAddresses(fromTransactions transactions: [Transaction], contractsAndTokenTypes: [AlphaWallet.Address: TokenType], realm: Realm) {
        let tokens = Self.tokens(from: transactions, server: server, contractsAndTokenTypes: contractsAndTokenTypes)
        delegate?.didAddTokensWith(contracts: Array(Set(tokens.map { $0.address })), inTransactionsStorage: self)

        if !tokens.isEmpty {
            updateTransactionsWithoutCommitWrite(in: realm, tokens: tokens)
        }
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

    private static func tokens(from transactions: [Transaction], server: RPCServer, contractsAndTokenTypes: [AlphaWallet.Address: TokenType]) -> [TokenUpdate] {
        let tokens: [TokenUpdate] = transactions.flatMap { transaction -> [TokenUpdate] in
            let tokenUpdates: [TokenUpdate] = transaction.localizedOperations.compactMap { operation in
                guard let contract = operation.contractAddress else { return nil }
                guard let name = operation.name else { return nil }
                guard let symbol = operation.symbol else { return nil }
                let tokenType: TokenType
                if let t = contractsAndTokenTypes[contract] {
                    tokenType = t
                } else {
                    switch operation.operationType {
                    case .nativeCurrencyTokenTransfer:
                        tokenType = .nativeCryptocurrency
                    case .erc20TokenTransfer:
                        tokenType = .erc20
                    case .erc20TokenApprove:
                        tokenType = .erc20
                    case .erc721TokenTransfer:
                        tokenType = .erc721
                    case .erc875TokenTransfer:
                        tokenType = .erc875
                    case .erc1155TokenTransfer:
                        tokenType = .erc1155
                    case .unknown:
                        tokenType = .erc20
                    }
                }
                return TokenUpdate(
                        address: contract,
                        server: server,
                        name: name,
                        symbol: symbol,
                        decimals: operation.decimals,
                        tokenType: tokenType
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

    func writeJsonForTransactions(toUrl url: URL) {
        do {
            let data = try functional.generateJsonForTransactions(transactionStorage: self, toUrl: url)
            try data.write(to: url)
            verboseLog("Written transactions for \(server) to JSON to: \(url.absoluteString)")
        } catch {
            verboseLog("Error writing transactions for \(server) to JSON: \(url.absoluteString) error: \(error)")
        }
    }

    static func deleteAllTransactions(realm: Realm) {
        for each in RPCServer.availableServers {
            let transactionsStorage = TransactionsStorage(realm: realm, server: each, delegate: nil)
            transactionsStorage.deleteAll()
        }
    }
}

extension TransactionsStorage: Erc721TokenIdsFetcher {
    func tokenIdsForErc721Token(contract: AlphaWallet.Address, forServer server: RPCServer, inAccount account: AlphaWallet.Address) -> Promise<[String]> {
        Promise { seal in
            //Important to sort ascending to figure out ownership from transfers in and out
            //TODO is this really slow? getting all transactions, right?
            //TODO why are some isERC20Interaction = false
            DispatchQueue.main.async {
                let transactions = self.realm.objects(Transaction.self)
                    .filter(TransactionsStorage.functional.transactionPredicate(server: server, operationContract: contract))
                    .sorted(byKeyPath: "date", ascending: true)
                let operations: [LocalizedOperationObject] = transactions.flatMap { $0.localizedOperations.filter { $0.contractAddress?.sameContract(as: contract) ?? false } }

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

extension TransactionsStorage {
    class functional {}
}

extension TransactionsStorage.functional {
    static func generateJsonForTransactions(transactionStorage: TransactionsStorage, toUrl url: URL) throws -> Data {
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

        let transactions = transactionStorage.objects.sorted(byKeyPath: "date", ascending: true)
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

    static func nonEmptyIdTransactionPredicate(server: RPCServer) -> NSPredicate {
        return NSCompoundPredicate(andPredicateWithSubpredicates: [
            chainIdPredicate(server: server),
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
