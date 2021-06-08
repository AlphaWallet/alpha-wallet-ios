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

class SingleChainTransactionEtherscanDataCoordinator: SingleChainTransactionDataCoordinator {
    private let storage: TransactionsStorage
    private let session: WalletSession
    private let keystore: Keystore
    private let tokensStorage: TokensDataStore
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

    private var server: RPCServer {
        session.server
    }

    private var config: Config {
        session.config
    }

    private var wallet: AlphaWallet.Address {
        session.account.address
    }

    required init(
            session: WalletSession,
            storage: TransactionsStorage,
            keystore: Keystore,
            tokensStorage: TokensDataStore,
            promptBackupCoordinator: PromptBackupCoordinator,
            onFetchLatestTransactionsQueue fetchLatestTransactionsQueue: OperationQueue
    ) {
        self.session = session
        self.storage = storage
        self.keystore = keystore
        self.tokensStorage = tokensStorage
        self.promptBackupCoordinator = promptBackupCoordinator
        self.fetchLatestTransactionsQueue = fetchLatestTransactionsQueue
    }

    func start() {
        runScheduledTimers()
        if transactionsTracker.fetchingState != .done {
            fetchOlderTransactions(for: wallet)
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

    deinit {
        fetchLatestTransactionsQueue.cancelAllOperations()
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

        let server = self.server
        let config = self.config
        let wallet = self.wallet
        let tokensStorage = self.tokensStorage
        let provider = self.alphaWalletProvider
        let queue = self.queue
        let startBlock = Config.getLastFetchedErc20InteractionBlockNumber(server, wallet: wallet).flatMap { $0 + 1 }

        firstly {
            GetContractInteractions(queue: queue).getErc20Interactions(address: wallet, server: server, startBlock: startBlock)
        }.map { result in
            functional.extractBoundingBlockNumbers(fromTransactions: result)
        }.then { result, minBlockNumber, maxBlockNumber in
            functional.backFillTransactionGroup(result, startBlock: minBlockNumber, endBlock: maxBlockNumber, account: wallet, alphaWalletProvider: provider, tokensStorage: tokensStorage, config: config, server: server, queue: queue).map { ($0, maxBlockNumber) }
        }.done(on: queue) { [weak self] backFilledTransactions, maxBlockNumber in
            //Just to be sure, we don't want any kind of strange errors to clear our progress by resetting blockNumber = 0
            if maxBlockNumber > 0 {
                Config.setLastFetchedErc20InteractionBlockNumber(maxBlockNumber, server: server, wallet: wallet)
            }
            self?.update(items: backFilledTransactions)
        }.cauterize()
        .finally { [weak self] in
            self?.isAutoDetectingERC20Transactions = false
        }
    }

    private func autoDetectErc721Transactions() {
        guard !isAutoDetectingErc721Transactions else { return }
        isAutoDetectingErc721Transactions = true

        let server = self.server
        let config = self.config
        let wallet = self.wallet
        let startBlock = Config.getLastFetchedErc721InteractionBlockNumber(server, wallet: wallet).flatMap { $0 + 1 }
        let tokensStorage = self.tokensStorage
        let provider = self.alphaWalletProvider
        let queue = self.queue

        firstly {
            GetContractInteractions(queue: queue).getErc721Interactions(address: wallet, server: server, startBlock: startBlock)
        }.map { result in
            functional.extractBoundingBlockNumbers(fromTransactions: result)
        }.then { result, minBlockNumber, maxBlockNumber in
            functional.backFillTransactionGroup(result, startBlock: minBlockNumber, endBlock: maxBlockNumber, account: wallet, alphaWalletProvider: provider, tokensStorage: tokensStorage, config: config, server: server, queue: queue).map { ($0, maxBlockNumber) }
        }.done(on: queue) { [weak self] backFilledTransactions, maxBlockNumber in
            //Just to be sure, we don't want any kind of strange errors to clear our progress by resetting blockNumber = 0
            if maxBlockNumber > 0 {
                Config.setLastFetchedErc721InteractionBlockNumber(maxBlockNumber, server: server, wallet: wallet)
            }
            self?.update(items: backFilledTransactions)
        }.cauterize()
        .finally { [weak self] in
            self?.isAutoDetectingErc721Transactions = false
        }
    }

    func fetch() {
        queue.async { [weak self] in
            guard let strongSelf = self else { return }

            DispatchQueue.main.async {
                strongSelf.refreshEthBalance()
            }

            strongSelf.fetchLatestTransactions()
            strongSelf.fetchPendingTransactions()
        }
    }

    private func refreshEthBalance() {
        session.refresh(.balance)
    }

    private func update(items: [TransactionInstance]) {
        guard !items.isEmpty else { return }

        SingleChainTransactionEtherscanDataCoordinator.functional.filterTransactionsToPullContractsFrom(items, in: tokensStorage).done(on: queue, { [weak self] transactionsToPullContractsFrom, contractsAndTokenTypes in
            guard let strongSelf = self else { return }

            strongSelf.storage.add(transactions: items, transactionsToPullContractsFrom: transactionsToPullContractsFrom, contractsAndTokenTypes: contractsAndTokenTypes)
            strongSelf.delegate?.handleUpdateItems(inCoordinator: strongSelf, reloadImmediately: false)
        }).cauterize()
    }

    private func fetchPendingTransactions() {
        for each in storage.pendingObjects {
            updatePendingTransaction(each)
        }
    }

    private func updatePendingTransaction(_ transaction: TransactionInstance) {
        let request = GetTransactionRequest(hash: transaction.id)

        firstly {
            Session.send(EtherServiceRequest(server: server, batch: BatchFactory().create(request)))
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
                    if strongSelf.storage.hasCompletedTransaction(withNonce: transaction.nonce) {
                        strongSelf.delete(transactions: [transaction])
                    }
                    //The transaction might not be posted to this node yet (ie. it doesn't even think that this transaction is pending). Especially common if we post a transaction to TaiChi and fetch pending status through Etherscan
                case .responseNotFound, .errorObjectParseError, .unsupportedVersion, .unexpectedTypeObject, .missingBothResultAndError, .nonArrayResponse, .none:
                    break
                }
            case .connectionError, .requestError, .none:
                break
            }
        }
    }

    private func delete(transactions: [TransactionInstance]) {
        storage.delete(transactions: transactions).done({ [weak self] _ in
            guard let strongSelf = self else { return }

            strongSelf.delegate?.handleUpdateItems(inCoordinator: strongSelf, reloadImmediately: true)
        }).cauterize()
    }

    private func update(state: TransactionState, for transaction: TransactionInstance, withPendingTransaction pendingTransaction: PendingTransaction?, shouldUpdateItems: Bool = true) {
        storage.update(state: state, for: transaction.primaryKey, withPendingTransaction: pendingTransaction).done(on: queue, { [weak self] _ in
            guard let strongSelf = self, shouldUpdateItems else { return }

            strongSelf.delegate?.handleUpdateItems(inCoordinator: strongSelf, reloadImmediately: false)
        }).cauterize()
    }

    ///Fetching transactions might take a long time, we use a flag to make sure we only pull the latest transactions 1 "page" at a time, otherwise we'd end up pulling the same "page" multiple times
    private func fetchLatestTransactions() {
        guard !isFetchingLatestTransactions else { return }
        isFetchingLatestTransactions = true

        let value = storage.transactionObjectsThatDoNotComeFromEventLogs()

        let startBlock: Int
        let sortOrder: AlphaWalletService.SortOrder

        if let newestCachedTransaction = value {
            startBlock = newestCachedTransaction.blockNumber + 1
            sortOrder = .asc
        } else {
            startBlock = 1
            sortOrder = .desc
        }

        let operation = FetchLatestTransactionsOperation(forSession: session, coordinator: self, startBlock: startBlock, sortOrder: sortOrder, queue: queue)
        fetchLatestTransactionsQueue.addOperation(operation)
    }

    private func handleError(error: Error) {
        //delegate?.didUpdate(result: .failure(TransactionError.failedToFetch))
        // Avoid showing an error on failed request, instead show cached transactions.
    }

    //TODO notify user of received tokens too
    private func notifyUserEtherReceived(inNewTransactions transactions: [TransactionInstance]) {
        guard !transactions.isEmpty else { return }

        let wallet = keystore.currentWallet

        let objects = storage.transactions
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
        let toNotifyUnique: [TransactionInstance] = filterUniqueTransactions(toNotify)
        let newIncomingEthTransactions = toNotifyUnique.filter { wallet.address.sameContract(as: $0.to) }
        let formatter = EtherNumberFormatter.short
        let thresholdToShowNotification = Date.yesterday
        for each in newIncomingEthTransactions {
            let amount = formatter.string(from: BigInt(each.value) ?? BigInt(), decimals: 18)
            if each.date > thresholdToShowNotification {
                self.notifyUserEtherReceived(for: each.id, amount: amount)
            }
        }
        let etherReceivedUsedForBackupPrompt = newIncomingEthTransactions
                .last { wallet.address.sameContract(as: $0.to) }
                .flatMap { BigInt($0.value) }

        switch session.server {
        //TODO make this work for other mainnets
        case .main:
            etherReceivedUsedForBackupPrompt.flatMap {
                self.promptBackupCoordinator.showCreateBackupAfterReceiveNativeCryptoCurrencyPrompt(nativeCryptoCurrency: $0)
            }
        case .classic, .xDai:
            break
        case .kovan, .ropsten, .rinkeby, .poa, .sokol, .callisto, .goerli, .artis_sigma1, .artis_tau1, .binance_smart_chain, .binance_smart_chain_testnet, .custom, .heco, .heco_testnet, .fantom, .fantom_testnet, .avalanche, .avalanche_testnet, .polygon, .mumbai_testnet, .optimistic, .optimisticKovan, .cronosTestnet:
            break
        }

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
        switch server {
        case .main, .xDai:
            content.body = R.string.localizable.transactionsReceivedEther(amount, server.symbol)
        case .kovan, .ropsten, .rinkeby, .poa, .sokol, .classic, .callisto, .goerli, .artis_sigma1, .artis_tau1, .binance_smart_chain, .binance_smart_chain_testnet, .custom, .heco, .heco_testnet, .fantom, .fantom_testnet, .avalanche, .avalanche_testnet, .polygon, .mumbai_testnet, .optimistic, .optimisticKovan, .cronosTestnet:
            content.body = R.string.localizable.transactionsReceivedEther("\(amount) (\(server.name))", server.symbol)
        }
        content.sound = .default
        let identifier = Constants.etherReceivedNotificationIdentifier
        let request = UNNotificationRequest(identifier: "\(identifier):\(transactionId)", content: content, trigger: nil)

        DispatchQueue.main.async {
            notificationCenter.add(request)
        }
    }

    private func fetchOlderTransactions(for address: AlphaWallet.Address) {
        guard let oldestCachedTransaction = storage.completedObjects.last else { return }

        let promise = functional.fetchTransactions(for: address, startBlock: 1, endBlock: oldestCachedTransaction.blockNumber - 1, sortOrder: .desc, alphaWalletProvider: alphaWalletProvider, tokensStorage: tokensStorage, config: config, server: server, queue: queue)
        promise.done(on: queue, { [weak self] transactions in
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
        }).catch(on: queue) { [weak self] _ in
            guard let strongSelf = self else { return }

            strongSelf.transactionsTracker.fetchingState = .failed
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil

        updateTransactionsTimer?.invalidate()
        updateTransactionsTimer = nil
    }

    func isServer(_ server: RPCServer) -> Bool {
        return self.server == server
    }

    //This inner class reaches into the internals of its outer coordinator class to call some methods. It exists so we can wrap operations into an Operation class and feed it into a queue, so we don't put much logic into it
    class FetchLatestTransactionsOperation: Operation {
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
        private let contractAddress: AlphaWallet.Address
        private let config: Config
        private let server: RPCServer

        init(forSession session: WalletSession, coordinator: SingleChainTransactionEtherscanDataCoordinator, startBlock: Int, sortOrder: AlphaWalletService.SortOrder, queue: DispatchQueue) {
            self.contractAddress = session.account.address
            self.coordinator = coordinator
            self.startBlock = startBlock
            self.sortOrder = sortOrder
            self.queue = queue
            self.config = session.config
            self.server = session.server
            super.init()
            self.queuePriority = session.server.networkRequestsQueuePriority
        }

        override func main() {
            guard let coordinator = self.coordinator else { return }
            firstly {
                SingleChainTransactionEtherscanDataCoordinator.functional.fetchTransactions(for: contractAddress, startBlock: startBlock, sortOrder: sortOrder, alphaWalletProvider: coordinator.alphaWalletProvider, tokensStorage: coordinator.tokensStorage, config: config, server: server, queue: coordinator.queue)
            }.then(on: .main, { transactions -> Promise<[TransactionInstance]> in
                //NOTE: we want to perform notification creating on main thread
                coordinator.notifyUserEtherReceived(inNewTransactions: transactions)

                return .value(transactions)
            }).done(on: queue, { transactions in
                coordinator.update(items: transactions)
            }).catch { e in
                coordinator.handleError(error: e)
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

    static func fetchTransactions(for address: AlphaWallet.Address, startBlock: Int, endBlock: Int = 999_999_999, sortOrder: AlphaWalletService.SortOrder, alphaWalletProvider: MoyaProvider<AlphaWalletService>, tokensStorage: TokensDataStore, config: Config, server: RPCServer, queue: DispatchQueue) -> Promise<[TransactionInstance]> {
        firstly {
            alphaWalletProvider.request(.getTransactions(config: config, server: server, address: address, startBlock: startBlock, endBlock: endBlock, sortOrder: sortOrder))
        }.map(on: queue) {
            try $0.map(ArrayResponse<RawTransaction>.self).result.map {
                TransactionInstance.from(transaction: $0, tokensStorage: tokensStorage)
            }
        }.then(on: queue) {
            when(fulfilled: $0).compactMap(on: queue) {
                $0.compactMap { $0 }
            }
        }
    }

    static func backFillTransactionGroup(_ transactionsToFill: [TransactionInstance], startBlock: Int, endBlock: Int, account: AlphaWallet.Address, alphaWalletProvider: MoyaProvider<AlphaWalletService>, tokensStorage: TokensDataStore, config: Config, server: RPCServer, queue: DispatchQueue) -> Promise<[TransactionInstance]> {
        guard !transactionsToFill.isEmpty else { return .value([]) }
        return firstly {
            fetchTransactions(for: account, startBlock: startBlock, endBlock: endBlock, sortOrder: .asc, alphaWalletProvider: alphaWalletProvider, tokensStorage: tokensStorage, config: config, server: server, queue: queue)
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

    static func filterTransactionsToPullContractsFrom(_ transactions: [TransactionInstance], in tokensStorage: TokensDataStore) -> Promise<(transactions: [TransactionInstance], contractTypes: [AlphaWallet.Address: TokenType])> {

        func getContractsToAvoid(in tokensStorage: TokensDataStore) -> [AlphaWallet.Address] {
            let alreadyAddedContracts = tokensStorage.enabledObject.map { $0.contractAddress }
            let deletedContracts = tokensStorage.deletedContracts.map { $0.contractAddress }
            let hiddenContracts = tokensStorage.hiddenContracts.map { $0.contractAddress }
            let delegateContracts = tokensStorage.delegateContracts.map { $0.contractAddress }

            return alreadyAddedContracts + deletedContracts + hiddenContracts + delegateContracts
        }

        return Promise { seal in
            let contractsToAvoid = getContractsToAvoid(in: tokensStorage)
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
            let tokenTypePromises = contracts.map { tokensStorage.getTokenType(for: $0) }

            when(fulfilled: tokenTypePromises).map { tokenTypes in
                let contractsToTokenTypes = Dictionary(uniqueKeysWithValues: zip(contracts, tokenTypes))
                return (transactions: filteredTransactions, contractTypes: contractsToTokenTypes)
            }.done { val in
                seal.fulfill(val)
            }.catch { error in
                seal.reject(error)
            }
        }
    }
}
