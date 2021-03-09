// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit
import APIKit
import BigInt
import JSONRPCKit
import PromiseKit
import Result
import UserNotifications

class SingleChainTransactionEtherscanDataCoordinator: SingleChainTransactionDataCoordinator {
    private let storage: TransactionsStorage
    let session: WalletSession
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
    private var isFetchingLatestTransactions = false
    var coordinators: [Coordinator] = []
    weak var delegate: SingleChainTransactionDataCoordinatorDelegate?

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
            fetchOlderTransactions(for: session.account.address)
            autoDetectERC20Transactions()
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
            }
        }, selector: #selector(Operation.main), userInfo: nil, repeats: true)
    }

    //TODO should this be added to the queue?
    private func autoDetectERC20Transactions() {
        guard !isAutoDetectingERC20Transactions else { return }
        isAutoDetectingERC20Transactions = true

        let server = session.server
        let wallet = session.account.address

        let startBlock = Config.getLastFetchedErc20InteractionBlockNumber(session.server, wallet: wallet).flatMap { $0 + 1 }
        GetContractInteractions(queue: self.queue).getErc20Interactions(address: wallet, server: server, startBlock: startBlock) { [weak self] result in
            guard let strongSelf = self else { return }

            let blockNumbers = result.map(\.blockNumber)
            if let minBlockNumber = blockNumbers.min(), let maxBlockNumber = blockNumbers.max() {
                firstly {
                    strongSelf.backFillErc20TransactionGroup(result, startBlock: minBlockNumber, endBlock: maxBlockNumber)
                }.done(on: strongSelf.queue) { backFilledTransactions in
                    Config.setLastFetchedErc20InteractionBlockNumber(maxBlockNumber, server: server, wallet: wallet)

                    strongSelf.update(items: backFilledTransactions)
                }.cauterize()
                .finally {
                    strongSelf.isAutoDetectingERC20Transactions = false
                }
            } else {
                strongSelf.isAutoDetectingERC20Transactions = false
                strongSelf.update(items: result)
            }
        }
    }

    private func backFillErc20TransactionGroup(_ transactionsToFill: [TransactionInstance], startBlock: Int, endBlock: Int) -> Promise<[TransactionInstance]> {
        return firstly {
            fetchTransactions(for: session.account.address, startBlock: startBlock, endBlock: endBlock, sortOrder: .asc)
        }.map(on: self.queue) { fillerTransactions -> [TransactionInstance] in
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

    func fetch() {
        self.queue.async {
            DispatchQueue.main.async {
                self.session.refresh(.balance)
            }

            self.fetchLatestTransactions()
            self.fetchPendingTransactions()
        }
    }

    private func update(items: [TransactionInstance]) {
        guard !items.isEmpty else { return }

        filterTransactionsToPullContractsFrom(items).done(on: self.queue, { transactionsToPullContractsFrom, contractsAndTokenTypes in
            self.storage.add(transactions: items, transactionsToPullContractsFrom: transactionsToPullContractsFrom, contractsAndTokenTypes: contractsAndTokenTypes)
            self.delegate?.handleUpdateItems(inCoordinator: self)
        }).cauterize()
    }

    private var contractsToAvoid: [AlphaWallet.Address] {
        let alreadyAddedContracts = tokensStorage.enabledObject.map { $0.contractAddress }
        let deletedContracts = tokensStorage.deletedContracts.map { $0.contractAddress }
        let hiddenContracts = tokensStorage.hiddenContracts.map { $0.contractAddress }
        let delegateContracts = tokensStorage.delegateContracts.map { $0.contractAddress }

        return alreadyAddedContracts + deletedContracts + hiddenContracts + delegateContracts
    }

    private func filterTransactionsToPullContractsFrom(_ transactions: [TransactionInstance]) -> Promise<(transactions: [TransactionInstance], contractTypes: [AlphaWallet.Address: TokenType])> {
        return Promise { seal in
            let contractsToAvoid = self.contractsToAvoid
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
            switch self.session.server {
            case .xDai, .poa:
                let contracts = Array(Set(filteredTransactions.compactMap { $0.localizedOperations.first?.contractAddress }))
                let tokenTypePromises = contracts.map { self.tokensStorage.getTokenType(for: $0) }

                when(fulfilled: tokenTypePromises).map { tokenTypes in
                    let contractsToTokenTypes = Dictionary(uniqueKeysWithValues: zip(contracts, tokenTypes))
                    return (transactions: filteredTransactions, contractTypes: contractsToTokenTypes)
                }.done { val in
                    seal.fulfill(val)
                }.catch { error in
                    seal.reject(error)
                }
            case .main, .classic, .kovan, .ropsten, .rinkeby, .sokol, .callisto, .goerli, .artis_sigma1, .artis_tau1, .binance_smart_chain, .binance_smart_chain_testnet, .custom, .heco, .heco_testnet, .taiChi:
                seal.fulfill((transactions: filteredTransactions, contractTypes: .init()))
            } 
        }
    }

    private func fetchPendingTransactions() {
        storage.pendingObjects.forEach {
            self.updatePendingTransaction($0)
        }
    }

    private func updatePendingTransaction(_ transaction: TransactionInstance) {
        let request = GetTransactionRequest(hash: transaction.id)

        firstly {
            Session.send(EtherServiceRequest(server: session.server, batch: BatchFactory().create(request)))
        }.done { pendingTransaction in
            if let blockNumber = Int(pendingTransaction.blockNumber), blockNumber > 0 {
                //NOTE: We dont want to call function handleUpdateItems: twice because it will be updated in update(items:
                self.update(state: .completed, for: transaction, withPendingTransaction: pendingTransaction, shouldUpdateItems: false)
                self.update(items: [transaction])
            }
        }.catch { error in
            switch error as? SessionTaskError {
            case .responseError(let error):
                // TODO: Think about the logic to handle pending transactions.
                switch error as? JSONRPCError {
                case .responseError:
                    self.delete(transactions: [transaction])
                case .resultObjectParseError:
                    if transaction.date > Date().addingTimeInterval(TransactionDataCoordinator.deleteMissingInternalSeconds) {
                        self.update(state: .failed, for: transaction, withPendingTransaction: nil)
                    }
                case .responseNotFound, .errorObjectParseError, .unsupportedVersion, .unexpectedTypeObject, .missingBothResultAndError, .nonArrayResponse, .none:
                    break
                }
            case .connectionError, .requestError, .none:
                break
            }
        }
    }

    private func delete(transactions: [TransactionInstance]) {
        storage.delete(transactions: transactions).done(on: self.queue, { _ in
            self.delegate?.handleUpdateItems(inCoordinator: self)
        }).cauterize()
    }

    private func update(state: TransactionState, for transaction: TransactionInstance, withPendingTransaction pendingTransaction: PendingTransaction?, shouldUpdateItems: Bool = true) {
        storage.update(state: state, for: transaction.primaryKey, withPendingTransaction: pendingTransaction).done(on: self.queue, { _ in
            guard shouldUpdateItems else { return }

            self.delegate?.handleUpdateItems(inCoordinator: self)
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

        let operation = FetchLatestTransactionsOperation(forSession: session, coordinator: self, startBlock: startBlock, sortOrder: sortOrder, queue: self.queue)
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
        case .kovan, .ropsten, .rinkeby, .poa, .sokol, .callisto, .goerli, .artis_sigma1, .artis_tau1, .binance_smart_chain, .binance_smart_chain_testnet, .custom, .heco, .heco_testnet, .taiChi:
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
        switch session.server {
        case .main, .xDai:
            content.body = R.string.localizable.transactionsReceivedEther(amount, session.server.symbol)
        case .kovan, .ropsten, .rinkeby, .poa, .sokol, .classic, .callisto, .goerli, .artis_sigma1, .artis_tau1, .binance_smart_chain, .binance_smart_chain_testnet, .custom, .heco, .heco_testnet, .taiChi:
            content.body = R.string.localizable.transactionsReceivedEther("\(amount) (\(session.server.name))", session.server.symbol)
        }
        content.sound = .default
        let identifier = Constants.etherReceivedNotificationIdentifier
        let request = UNNotificationRequest(identifier: "\(identifier):\(transactionId)", content: content, trigger: nil)

        DispatchQueue.main.async {
            notificationCenter.add(request)
        }
    }

    private func fetchTransactions(for address: AlphaWallet.Address, startBlock: Int, endBlock: Int = 999_999_999, sortOrder: AlphaWalletService.SortOrder) -> Promise<[TransactionInstance]> {

        return alphaWalletProvider.request(.getTransactions(
            config: session.config,
            server: session.server,
            address: address,
            startBlock: startBlock,
            endBlock: endBlock,
            sortOrder: sortOrder
        ))
        .map(on: self.queue) {
            try $0.map(ArrayResponse<RawTransaction>.self).result.map {
                TransactionInstance.from(transaction: $0, tokensStorage: self.tokensStorage)
            }
        }.then(on: self.queue) {
            when(fulfilled: $0).compactMap(on: self.queue) {
                $0.compactMap { $0 }
            }
        }
    }

    private func fetchOlderTransactions(for address: AlphaWallet.Address) {
        guard let oldestCachedTransaction = storage.completedObjects.last else { return }

        let promise = fetchTransactions(for: address, startBlock: 1, endBlock: oldestCachedTransaction.blockNumber - 1, sortOrder: .desc)
        promise.done(on: self.queue, { [weak self] transactions in
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
        }).catch(on: self.queue) { [weak self] _ in
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
                coordinator.fetchTransactions(for: session.account.address, startBlock: startBlock, sortOrder: sortOrder)
            }.done(on: queue, { transactions in
                coordinator.notifyUserEtherReceived(inNewTransactions: transactions)
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
