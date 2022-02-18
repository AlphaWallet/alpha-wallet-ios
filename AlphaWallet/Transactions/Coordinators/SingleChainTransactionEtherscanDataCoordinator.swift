// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit
import APIKit
import BigInt
import JSONRPCKit
import Moya
import PromiseKit
import Result
import UserNotifications
import Mixpanel

// swiftlint:disable type_body_length
class SingleChainTransactionEtherscanDataCoordinator: SingleChainTransactionDataCoordinator {
    private let storage: TransactionsStorage
    let session: WalletSession
    private let keystore: Keystore
    private let tokensDataStore: TokensDataStore
    private let promptBackupCoordinator: PromptBackupCoordinator
    private let fetchLatestTransactionsQueue: OperationQueue
    private let queue = DispatchQueue(label: "com.SingleChainTransaction.updateQueue")
    private var timer: Timer?
    private var updateTransactionsTimer: Timer?
    private lazy var transactionsTracker: TransactionsTracker = {
        return TransactionsTracker(sessionID: session.sessionID)
    }()
    private let alphaWalletProvider = AlphaWalletProviderFactory.makeProvider()

    private var isAutoDetectingERC20Transactions: Bool = false
    private var isAutoDetectingErc721Transactions: Bool = false
    private var isFetchingLatestTransactions = false
    var coordinators: [Coordinator] = []
    weak var delegate: SingleChainTransactionDataCoordinatorDelegate?
    lazy var tokenProvider: TokenProviderType = TokenProvider(account: session.account, server: session.server)

    required init(
            session: WalletSession,
            storage: TransactionsStorage,
            keystore: Keystore,
            tokensDataStore: TokensDataStore,
            promptBackupCoordinator: PromptBackupCoordinator,
            onFetchLatestTransactionsQueue fetchLatestTransactionsQueue: OperationQueue
    ) {
        self.session = session
        self.storage = storage
        self.keystore = keystore
        self.tokensDataStore = tokensDataStore
        self.promptBackupCoordinator = promptBackupCoordinator
        self.fetchLatestTransactionsQueue = fetchLatestTransactionsQueue
    }

    func start() {
        runScheduledTimers()
        if transactionsTracker.fetchingState != .done {
            fetchOlderTransactions(for: session.account.address)
            autoDetectERC20Transactions()
            autoDetectErc721Transactions()
        }
    }

    func stopTimers() {
        timer?.invalidate()
        timer = nil
        updateTransactionsTimer?.invalidate()
        updateTransactionsTimer = nil
    }

    func runScheduledTimers() {
        guard timer == nil, updateTransactionsTimer == nil else {
            return
        }

        timer = Timer.scheduledTimer(timeInterval: 5, target: BlockOperation { [weak self] in
            guard let strongSelf = self else { return }

            strongSelf.queue.async {
                strongSelf.fetchPendingTransactions()
            }
        }, selector: #selector(Operation.main), userInfo: nil, repeats: true)

        updateTransactionsTimer = Timer.scheduledTimer(timeInterval: 15, target: BlockOperation { [weak self] in
            guard let strongSelf = self else { return }

            strongSelf.queue.async {
                strongSelf.fetchLatestTransactions()
                strongSelf.autoDetectERC20Transactions()
                strongSelf.autoDetectErc721Transactions()
            }
        }, selector: #selector(Operation.main), userInfo: nil, repeats: true)
    }

    //TODO should this be added to the queue?
    //TODO when blockscout-compatible, this includes ERC721 too. Maybe rename?
    private func autoDetectERC20Transactions() {
        guard !isAutoDetectingERC20Transactions else { return }
        isAutoDetectingERC20Transactions = true
        let server = session.server
        let wallet = session.account.address
        let startBlock = Config.getLastFetchedErc20InteractionBlockNumber(session.server, wallet: wallet).flatMap { $0 + 1 }
        firstly {
            GetContractInteractions(queue: queue).getErc20Interactions(address: wallet, server: server, startBlock: startBlock)
        }.map(on: queue, { result -> (transactions: [TransactionInstance], min: Int, max: Int) in
            return functional.extractBoundingBlockNumbers(fromTransactions: result)
        }).then(on: queue, { [weak self] result, minBlockNumber, maxBlockNumber -> Promise<([TransactionInstance], Int)> in
            guard let strongSelf = self else { return .init(error: PMKError.cancelled) }

            return functional.backFillTransactionGroup(result, startBlock: minBlockNumber, endBlock: maxBlockNumber, session: strongSelf.session, alphaWalletProvider: strongSelf.alphaWalletProvider, tokensDataStore: strongSelf.tokensDataStore, tokenProvider: strongSelf.tokenProvider, queue: strongSelf.queue).map { ($0, maxBlockNumber) }
        }).done(on: queue) { [weak self] backFilledTransactions, maxBlockNumber in
            guard let strongSelf = self else { return }
            //Just to be sure, we don't want any kind of strange errors to clear our progress by resetting blockNumber = 0
            if maxBlockNumber > 0 {
                Config.setLastFetchedErc20InteractionBlockNumber(maxBlockNumber, server: server, wallet: wallet)
            }
            strongSelf.update(items: backFilledTransactions)
        }.catch({ e in
            error(value: e, function: #function, rpcServer: server, address: wallet)
        })
        .finally { [weak self] in
            self?.isAutoDetectingERC20Transactions = false
        }
    }

    private func autoDetectErc721Transactions() {
        guard !isAutoDetectingErc721Transactions else { return }
        isAutoDetectingErc721Transactions = true
        let server = session.server
        let wallet = session.account.address
        let startBlock = Config.getLastFetchedErc721InteractionBlockNumber(session.server, wallet: wallet).flatMap { $0 + 1 }
        firstly {
            GetContractInteractions(queue: queue).getErc721Interactions(address: wallet, server: server, startBlock: startBlock)
        }.map(on: queue, { result in
            functional.extractBoundingBlockNumbers(fromTransactions: result)
        }).then(on: queue, { [weak self] result, minBlockNumber, maxBlockNumber -> Promise<([TransactionInstance], Int)> in
            guard let strongSelf = self else { return .init(error: PMKError.cancelled) }
            return functional.backFillTransactionGroup(result, startBlock: minBlockNumber, endBlock: maxBlockNumber, session: strongSelf.session, alphaWalletProvider: strongSelf.alphaWalletProvider, tokensDataStore: strongSelf.tokensDataStore, tokenProvider: strongSelf.tokenProvider, queue: strongSelf.queue).map { ($0, maxBlockNumber) }
        }).done(on: queue) { [weak self] backFilledTransactions, maxBlockNumber in
            guard let strongSelf = self else { return }
            //Just to be sure, we don't want any kind of strange errors to clear our progress by resetting blockNumber = 0
            if maxBlockNumber > 0 {
                Config.setLastFetchedErc721InteractionBlockNumber(maxBlockNumber, server: server, wallet: wallet)
            }
            strongSelf.update(items: backFilledTransactions)
        }.catch({ e in
            error(value: e, rpcServer: server, address: wallet)
        })
        .finally { [weak self] in
            self?.isAutoDetectingErc721Transactions = false
        }
    }

    func fetch() {
        queue.async { [weak self] in
            guard let strongSelf = self else { return }

            strongSelf.session.refresh(.balance)
            strongSelf.fetchLatestTransactions()
            strongSelf.fetchPendingTransactions()
        }
    }

    private func update(items: [TransactionInstance]) {
        guard !items.isEmpty else { return }

        filterTransactionsToPullContractsFrom(items).done(on: .main, { [weak self] transactionsToPullContractsFrom, contractsAndTokenTypes in
            guard let strongSelf = self else { return }
            //NOTE: Realm write operation!
            strongSelf.storage.add(transactions: items, transactionsToPullContractsFrom: transactionsToPullContractsFrom, contractsAndTokenTypes: contractsAndTokenTypes)
            strongSelf.delegate?.handleUpdateItems(inCoordinator: strongSelf, reloadImmediately: false)
        }).cauterize()
    }

    private func detectContractsToAvoid(for tokensStorage: TokensDataStore, forServer server: RPCServer) -> Promise<[AlphaWallet.Address]> {
        return Promise { seal in
            DispatchQueue.main.async {
                let deletedContracts = tokensStorage.deletedContracts(forServer: server).map { $0.contractAddress }
                let hiddenContracts = tokensStorage.hiddenContracts(forServer: server).map { $0.contractAddress }
                let delegateContracts = tokensStorage.delegateContracts(forServer: server).map { $0.contractAddress }
                let alreadyAddedContracts = tokensStorage.enabledTokenObjects(forServers: [server]).map { $0.contractAddress }

                seal.fulfill(alreadyAddedContracts + deletedContracts + hiddenContracts + delegateContracts)
            }
        }
    }

    private func filterTransactionsToPullContractsFrom(_ transactions: [TransactionInstance]) -> Promise<(transactions: [TransactionInstance], contractTypes: [AlphaWallet.Address: TokenType])> {
        return detectContractsToAvoid(for: tokensDataStore, forServer: session.server).then(on: queue, { [weak self] contractsToAvoid -> Promise<(transactions: [TransactionInstance], contractTypes: [AlphaWallet.Address: TokenType])> in
            guard let strongSelf = self else { return .init(error: PMKError.cancelled) }

            let filteredTransactions = transactions.filter {
                if let toAddressToCheck = AlphaWallet.Address(string: $0.to), contractsToAvoid.contains(toAddressToCheck) {
                    return false
                }
                if let contractAddressToCheck = $0.operation?.contractAddress, contractsToAvoid.contains(contractAddressToCheck) {
                    return false
                }
                return true
            }

            //The fetch ERC20 transactions endpoint from Etherscan returns only ERC20 token transactions but the Blockscout version also includes ERC721 transactions too (so it's likely other types that it can detect will be returned too); thus we check the token type rather than assume that they are all ERC20
            let contracts = Array(Set(filteredTransactions.compactMap { $0.localizedOperations.first?.contractAddress }))
            let tokenTypePromises = contracts.map { strongSelf.tokenProvider.getTokenType(for: $0) }

            return when(fulfilled: tokenTypePromises).map(on: strongSelf.queue, { tokenTypes in
                let contractsToTokenTypes = Dictionary(uniqueKeysWithValues: zip(contracts, tokenTypes))
                return (transactions: filteredTransactions, contractTypes: contractsToTokenTypes)
            })
        })
    }

    private func fetchPendingTransactions() {
        storage.pendingObjects.done { [weak self] txs in
            guard let strongSelf = self else { return }

            for each in txs {
                strongSelf.updatePendingTransaction(each )
            }
        }.cauterize()
    }

    private func updatePendingTransaction(_ transaction: TransactionInstance) {
        let request = GetTransactionRequest(hash: transaction.id)

        firstly {
            Session.send(EtherServiceRequest(server: session.server, batch: BatchFactory().create(request)))
        }.done { [weak self] pendingTransaction in
            guard let strongSelf = self else { return }

            if let blockNumber = Int(pendingTransaction.blockNumber), blockNumber > 0 {
                //NOTE: We dont want to call function handleUpdateItems: twice because it will be updated in update(items:
                strongSelf.update(state: .completed, for: transaction, withPendingTransaction: pendingTransaction, shouldUpdateItems: false)
                strongSelf.update(items: [transaction])
            }
        }.catch { [weak self] error in
            guard let strongSelf = self else { return }

            switch error as? SessionTaskError {
            case .responseError(let error):
                // TODO: Think about the logic to handle pending transactions.
                //TODO we need to detect when a transaction is marked as failed by the node?
                switch error as? JSONRPCError {
                case .responseError:
                    strongSelf.delete(transactions: [transaction])
                case .resultObjectParseError:
                    strongSelf.storage.hasCompletedTransaction(withNonce: transaction.nonce).done(on: strongSelf.queue, { value in
                        if value {
                            strongSelf.delete(transactions: [transaction])
                        }
                    }).cauterize()
                    //The transaction might not be posted to this node yet (ie. it doesn't even think that this transaction is pending). Especially common if we post a transaction to Ethermine and fetch pending status through Etherscan
                case .responseNotFound, .errorObjectParseError, .unsupportedVersion, .unexpectedTypeObject, .missingBothResultAndError, .nonArrayResponse, .none:
                    break
                }
            case .connectionError, .requestError, .none:
                break
            }
        }
    }

    private func delete(transactions: [TransactionInstance]) {
        storage.delete(transactions: transactions).done(on: queue, { [weak self] _ in
            guard let strongSelf = self else { return }
            strongSelf.delegate?.handleUpdateItems(inCoordinator: strongSelf, reloadImmediately: true)
        }).cauterize()
    }

    private func update(state: TransactionState, for transaction: TransactionInstance, withPendingTransaction pendingTransaction: PendingTransaction?, shouldUpdateItems: Bool = true) {
        storage.update(state: state, for: transaction.primaryKey, withPendingTransaction: pendingTransaction).done(on: queue, { [weak self] _ in
            guard let strongSelf = self else { return }
            guard shouldUpdateItems else { return }

            strongSelf.delegate?.handleUpdateItems(inCoordinator: strongSelf, reloadImmediately: false)
        }).cauterize()
    }

    ///Fetching transactions might take a long time, we use a flag to make sure we only pull the latest transactions 1 "page" at a time, otherwise we'd end up pulling the same "page" multiple times
    private func fetchLatestTransactions() {
        guard !isFetchingLatestTransactions else { return }
        isFetchingLatestTransactions = true

        storage.transactionObjectsThatDoNotComeFromEventLogs().done(on: queue, { [weak self] value in
            guard let strongSelf = self else { return }

            let startBlock: Int
            let sortOrder: AlphaWalletService.SortOrder

            if let newestCachedTransaction = value {
                startBlock = newestCachedTransaction.blockNumber + 1
                sortOrder = .asc
            } else {
                startBlock = 1
                sortOrder = .desc
            }

            let operation = FetchLatestTransactionsOperation(forSession: strongSelf.session, coordinator: strongSelf, startBlock: startBlock, sortOrder: sortOrder, queue: strongSelf.queue)
            strongSelf.fetchLatestTransactionsQueue.addOperation(operation)
        }).cauterize()
    }

    private func handleError(error e: Error) {
        //delegate?.didUpdate(result: .failure(TransactionError.failedToFetch))
        // Avoid showing an error on failed request, instead show cached transactions.
        error(value: e)
    }

    //TODO notify user of received tokens too
    private func notifyUserEtherReceived(inNewTransactions transactions: [TransactionInstance]) {
        guard !transactions.isEmpty else { return }

        let wallet = keystore.currentWallet

        storage.transactions.done(on: queue, { [weak self] objects in
            guard let strongSelf = self else { return }

            var toNotify: [TransactionInstance]

            if let newestCached = objects.first {
                toNotify = transactions.filter { $0.blockNumber > newestCached.blockNumber }
            } else {
                toNotify = transactions
            }

            //Beyond a certain number, it's too noisy and a performance nightmare. Eg. the first time we fetch transactions for a newly imported wallet, we might get 10,000 of them
            let maximumNumberOfNotifications = 10
            if toNotify.count > maximumNumberOfNotifications {
                toNotify = Array(toNotify[0..<maximumNumberOfNotifications])
            }
            let toNotifyUnique: [TransactionInstance] = strongSelf.filterUniqueTransactions(toNotify)
            let newIncomingEthTransactions = toNotifyUnique.filter { wallet.address.sameContract(as: $0.to) }
            let formatter = EtherNumberFormatter.short
            let thresholdToShowNotification = Date.yesterday
            for each in newIncomingEthTransactions {
                let amount = formatter.string(from: BigInt(each.value) ?? BigInt(), decimals: 18)
                if each.date > thresholdToShowNotification {
                    strongSelf.notifyUserEtherReceived(for: each.id, amount: amount)
                }
            }
            let etherReceivedUsedForBackupPrompt = newIncomingEthTransactions
                    .last { wallet.address.sameContract(as: $0.to) }
                    .flatMap { BigInt($0.value) }

            DispatchQueue.main.async {
                switch strongSelf.session.server {
                //TODO make this work for other mainnets
                case .main:
                    etherReceivedUsedForBackupPrompt.flatMap {
                        strongSelf.promptBackupCoordinator.showCreateBackupAfterReceiveNativeCryptoCurrencyPrompt(nativeCryptoCurrency: $0)
                    }
                case .classic, .xDai:
                    break
                case .kovan, .ropsten, .rinkeby, .poa, .sokol, .callisto, .goerli, .artis_sigma1, .artis_tau1, .binance_smart_chain, .binance_smart_chain_testnet, .custom, .heco, .heco_testnet, .fantom, .fantom_testnet, .avalanche, .avalanche_testnet, .polygon, .mumbai_testnet, .optimistic, .optimisticKovan, .cronosTestnet, .arbitrum, .arbitrumRinkeby, .palm, .palmTestnet:
                    break
                }
            }
        }).cauterize()
    }

    //Etherscan for Ropsten returns the same transaction twice. Normally Realm will take care of this, but since we are showing user a notification, we don't want to show duplicates
    private func filterUniqueTransactions(_ transactions: [TransactionInstance]) -> [TransactionInstance] {
        var results = [TransactionInstance]()
        for each in transactions {
            if !results.contains(where: { each.id == $0.id }) {
                results.append(each)
            }
        }
        return results
    }

    private func notifyUserEtherReceived(for transactionId: String, amount: String) {
        let notificationCenter = UNUserNotificationCenter.current()
        let content = UNMutableNotificationContent()
        //TODO support other mainnets too
        switch session.server {
        case .main, .xDai:
            content.body = R.string.localizable.transactionsReceivedEther(amount, session.server.symbol)
        case .kovan, .ropsten, .rinkeby, .poa, .sokol, .classic, .callisto, .goerli, .artis_sigma1, .artis_tau1, .binance_smart_chain, .binance_smart_chain_testnet, .custom, .heco, .heco_testnet, .fantom, .fantom_testnet, .avalanche, .avalanche_testnet, .polygon, .mumbai_testnet, .optimistic, .optimisticKovan, .cronosTestnet, .arbitrum, .arbitrumRinkeby, .palm, .palmTestnet:
            content.body = R.string.localizable.transactionsReceivedEther("\(amount) (\(session.server.name))", session.server.symbol)
        }
        content.sound = .default
        let identifier = Constants.etherReceivedNotificationIdentifier
        let request = UNNotificationRequest(identifier: "\(identifier):\(transactionId)", content: content, trigger: nil)

        DispatchQueue.main.async {
            notificationCenter.add(request)
        }
    }

    private func fetchOlderTransactions(for address: AlphaWallet.Address) {
        storage.completedObjects.done(on: queue, { [weak self] txs in
            guard let strongSelf = self else { return }
            guard let oldestCachedTransaction = txs.last else { return }

            let promise = functional.fetchTransactions(for: address, startBlock: 1, endBlock: oldestCachedTransaction.blockNumber - 1, sortOrder: .desc, session: strongSelf.session, alphaWalletProvider: strongSelf.alphaWalletProvider, tokensDataStore: strongSelf.tokensDataStore, tokenProvider: strongSelf.tokenProvider, queue: strongSelf.queue)
            promise.done(on: strongSelf.queue, { [weak self] transactions in
                guard let strongSelf = self else { return }

                strongSelf.update(items: transactions)

                if transactions.isEmpty {
                    strongSelf.transactionsTracker.fetchingState = .done
                } else {
                    let timeout = DispatchTime.now() + .milliseconds(300)
                    strongSelf.queue.asyncAfter(deadline: timeout) {
                        strongSelf.fetchOlderTransactions(for: address)
                    }
                }
            }).catch(on: strongSelf.queue) { [weak self] _ in
                guard let strongSelf = self else { return }

                strongSelf.transactionsTracker.fetchingState = .failed
            }
        }).catch({ e in
            error(value: e, rpcServer: self.session.server, address: address)
        })
    }

    func stop() {
        timer?.invalidate()
        timer = nil

        updateTransactionsTimer?.invalidate()
        updateTransactionsTimer = nil
    }

    func isServer(_ server: RPCServer) -> Bool {
        return session.server == server
    }

    //This inner class reaches into the internals of its outer coordinator class to call some methods. It exists so we can wrap operations into an Operation class and feed it into a queue, so we don't put much logic into it
    class FetchLatestTransactionsOperation: Operation {
        private let session: WalletSession
        weak private var coordinator: SingleChainTransactionEtherscanDataCoordinator?
        private let startBlock: Int
        private let sortOrder: AlphaWalletService.SortOrder
        override var isExecuting: Bool {
            return coordinator?.isFetchingLatestTransactions ?? false
        }
        override var isFinished: Bool {
            return !isExecuting
        }
        override var isAsynchronous: Bool {
            return true
        }
        private let queue: DispatchQueue

        init(forSession session: WalletSession, coordinator: SingleChainTransactionEtherscanDataCoordinator, startBlock: Int, sortOrder: AlphaWalletService.SortOrder, queue: DispatchQueue) {
            self.session = session
            self.coordinator = coordinator
            self.startBlock = startBlock
            self.sortOrder = sortOrder
            self.queue = queue
            super.init()
            self.queuePriority = session.server.networkRequestsQueuePriority
        }

        override func main() {
            guard let coordinator = self.coordinator else { return }

            firstly {
                SingleChainTransactionEtherscanDataCoordinator.functional.fetchTransactions(for: session.account.address, startBlock: startBlock, sortOrder: sortOrder, session: coordinator.session, alphaWalletProvider: coordinator.alphaWalletProvider, tokensDataStore: coordinator.tokensDataStore, tokenProvider: coordinator.tokenProvider, queue: coordinator.queue)
            }.then(on: queue, { transactions -> Promise<[TransactionInstance]> in
                //NOTE: we want to perform notification creating on main thread
                coordinator.notifyUserEtherReceived(inNewTransactions: transactions)

                return .value(transactions)
            }).done(on: queue, { transactions in
                coordinator.update(items: transactions)
            }).catch { e in
                error(value: e, rpcServer: coordinator.session.server, address: self.session.account.address)
            }.finally { [weak self] in
                guard let strongSelf = self else { return }

                strongSelf.willChangeValue(forKey: "isExecuting")
                strongSelf.willChangeValue(forKey: "isFinished")

                coordinator.isFetchingLatestTransactions = false

                strongSelf.didChangeValue(forKey: "isExecuting")
                strongSelf.didChangeValue(forKey: "isFinished")
            }
        }
    }
}
// swiftlint:enable type_body_length

extension SingleChainTransactionEtherscanDataCoordinator {
    class functional {}
}

extension SingleChainTransactionEtherscanDataCoordinator.functional {
    static func extractBoundingBlockNumbers(fromTransactions transactions: [TransactionInstance]) -> (transactions: [TransactionInstance], min: Int, max: Int) {
        let blockNumbers = transactions.map(\.blockNumber)
        if let minBlockNumber = blockNumbers.min(), let maxBlockNumber = blockNumbers.max() {
            return (transactions: transactions, min: minBlockNumber, max: maxBlockNumber)
        } else {
            return (transactions: [], min: 0, max: 0)
        }
    }

    static func fetchTransactions(for address: AlphaWallet.Address, startBlock: Int, endBlock: Int = 999_999_999, sortOrder: AlphaWalletService.SortOrder, session: WalletSession, alphaWalletProvider: MoyaProvider<AlphaWalletService>, tokensDataStore: TokensDataStore, tokenProvider: TokenProviderType, queue: DispatchQueue) -> Promise<[TransactionInstance]> {
        let target: AlphaWalletService = .getTransactions(config: session.config, server: session.server, address: address, startBlock: startBlock, endBlock: endBlock, sortOrder: sortOrder)
        return firstly {
            alphaWalletProvider.request(target)
        }.map(on: queue) { response -> [Promise<TransactionInstance?>] in
            if response.statusCode == 404 {
                //Clearer than a JSON deserialization error when it's a 404
                enum E: Error {
                    case statusCode404
                }
                throw E.statusCode404
            }
            return try response.map(ArrayResponse<RawTransaction>.self).result.map {
                TransactionInstance.from(transaction: $0, tokensDataStore: tokensDataStore, tokenProvider: tokenProvider, server: session.server)
            }
        }.then(on: queue) {
            when(fulfilled: $0).compactMap(on: queue) {
                $0.compactMap { $0 }
            }
        }
    }

    static func backFillTransactionGroup(_ transactionsToFill: [TransactionInstance], startBlock: Int, endBlock: Int, session: WalletSession, alphaWalletProvider: MoyaProvider<AlphaWalletService>, tokensDataStore: TokensDataStore, tokenProvider: TokenProviderType, queue: DispatchQueue) -> Promise<[TransactionInstance]> {
        guard !transactionsToFill.isEmpty else { return .value([]) }
        return firstly {
            fetchTransactions(for: session.account.address, startBlock: startBlock, endBlock: endBlock, sortOrder: .asc, session: session, alphaWalletProvider: alphaWalletProvider, tokensDataStore: tokensDataStore, tokenProvider: tokenProvider, queue: queue)
        }.map(on: queue) { fillerTransactions -> [TransactionInstance] in
            var results: [TransactionInstance] = .init()
            for each in transactionsToFill {
                //ERC20 transactions are expected to have operations because of the API we use to retrieve them from
                guard !each.localizedOperations.isEmpty else { continue }
                if var transaction = fillerTransactions.first(where: { $0.blockNumber == each.blockNumber }) {
                    transaction.isERC20Interaction = true
                    transaction.localizedOperations = each.localizedOperations
                    results.append(transaction)
                } else {
                    results.append(each)
                }
            }
            return results
        }
    }
}

func error(value e: Error, pref: String = "", function f: String = #function, rpcServer: RPCServer? = nil, address: AlphaWallet.Address? = nil) {
    var description = pref
    description += rpcServer.flatMap { " server: \($0)" } ?? ""
    description += address.flatMap { " address: \($0.eip55String)" } ?? ""
    description += " \(e)"
    errorLog(description, callerFunctionName: f)
}
