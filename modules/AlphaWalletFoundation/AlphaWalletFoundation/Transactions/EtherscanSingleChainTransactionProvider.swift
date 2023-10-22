// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import BigInt
import Combine
import AlphaWalletCore

actor EtherscanSingleChainTransactionProvider: SingleChainTransactionProvider {
    private let transactionDataStore: TransactionDataStore
    private let session: WalletSession
    private let ercTokenDetector: ErcTokenDetector
    private var schedulerProviders: [SchedulerProviderData]
    private nonisolated lazy var pendingTransactionProvider: PendingTransactionProvider = {
        return PendingTransactionProvider(
            session: session,
            transactionDataStore: transactionDataStore,
            ercTokenDetector: ercTokenDetector)
    }()
    private var cancellable = Set<AnyCancellable>()
    private let oldestTransferTransactionsScheduler: Scheduler
    private let queue = DispatchQueue(label: "com.transactionProvider.updateQueue")

    public nonisolated var completeTransaction: AnyPublisher<Result<Transaction, PendingTransactionProvider.PendingTransactionProviderError>, Never> {
        pendingTransactionProvider.completeTransaction
    }
    private var _state: TransactionProviderState = .pending
    public var state: TransactionProviderState {
        get async {
            return _state
        }
    }

    init(session: WalletSession,
         analytics: AnalyticsLogger,
         transactionDataStore: TransactionDataStore,
         ercTokenDetector: ErcTokenDetector,
         blockchainExplorer: BlockchainExplorer,
         fetchTypes: [TransactionFetchType] = TransactionFetchType.allCases) {

        self.session = session
        self.transactionDataStore = transactionDataStore
        self.ercTokenDetector = ercTokenDetector

        schedulerProviders = .init(fetchTypes.map { fetchType in
            let schedulerProvider: SchedulerProvider & LatestTransactionProvidable
            switch fetchType {
            case .normal:
                schedulerProvider = LatestTransactionsSchedulerProvider(
                    session: session,
                    blockchainExplorer: session.blockchainExplorer,
                    transactionDataStore: transactionDataStore,
                    interval: 15,
                    stateProvider: PersistantSchedulerStateProvider(
                        sessionID: session.sessionID,
                        prefix: fetchType.rawValue))
            case .erc20, .erc721, .erc1155:
                schedulerProvider = LatestTransferTransactionsSchedulerProvider(
                    session: session,
                    blockchainExplorer: session.blockchainExplorer,
                    transferType: fetchType,
                    interval: 15,
                    stateProvider: PersistantSchedulerStateProvider(
                        sessionID: session.sessionID,
                        prefix: fetchType.rawValue))
            }

            return SchedulerProviderData(fetchType: fetchType, schedulerProvider: schedulerProvider)
        })

        let oldestTransactionsStateProvider = PersistantSchedulerStateProvider(
            sessionID: session.sessionID,
            prefix: EtherscanCompatibleSchedulerStatePrefix.oldestTransaction.rawValue)

        let oldestTransactionsProvider = OldestTransactionsSchedulerProvider(
            session: session,
            blockchainExplorer: session.blockchainExplorer,
            transactionDataStore: transactionDataStore,
            stateProvider: oldestTransactionsStateProvider,
            interval: 5)

        oldestTransferTransactionsScheduler = Scheduler(provider: oldestTransactionsProvider)

        schedulerProviders.forEach { data in
            data.schedulerProvider
                .publisher
                .sink { transactions in
                    Task { [weak self] in
                        await self?.handle(response: transactions, provider: data.schedulerProvider)
                    }
                }
                .store(in: &cancellable)
        }

        oldestTransactionsProvider.publisher
            .sink { transactions in
                Task { [weak self] in
                    await self?.handle(response: transactions, provider: oldestTransactionsProvider)
                }
            }
            .store(in: &cancellable)

        /*
        pendingTransactionProvider.completeTransaction
            .compactMap { try? self.transactionFetchType(transaction: $0.get()) }
            .setFailureType(to: PromiseError.self)
            .flatMap { self.fetchLatestTransactions(fetchTypes: [$0]) }
            .sink(receiveCompletion: { result in

            }, receiveValue: { transactions in

            }).store(in: &cancellable)
        */

        pendingTransactionProvider.completeTransaction
            .compactMap { try? $0.get() }
            .sink { transaction in
                Task { [weak self] in
                    await self?.forceFetchLatestTransactions(transaction: transaction)
                }
            }
            .store(in: &cancellable)
    }

    deinit {
        schedulerProviders.forEach { $0.cancel() }
        oldestTransferTransactionsScheduler.cancel()
        Task {
            await pendingTransactionProvider.cancelScheduler()
        }
    }

    func resume() async {
        guard _state == .stopped else { return }
        await pendingTransactionProvider.resumeScheduler()
        schedulerProviders.forEach { $0.restart() }
        oldestTransferTransactionsScheduler.restart()
        _state = .running
    }

    func pause() async {
        guard _state == .running || _state == .pending else { return }
        await pendingTransactionProvider.cancelScheduler()
        schedulerProviders.forEach { $0.cancel() }
        oldestTransferTransactionsScheduler.cancel()
        _state = .stopped
    }

    func start() async {
        guard _state == .pending else { return }
        await pendingTransactionProvider.start()
        schedulerProviders.forEach { $0.start() }
        oldestTransferTransactionsScheduler.start()
        queue.async { [weak self] in self?.removeUnknownTransactions() }
        _state = .running
    }

    public nonisolated func isServer(_ server: RPCServer) -> Bool {
        return session.server == server
    }
    //TODO: this method doesn't work right for now
    public func fetchLatestTransactions(fetchTypes: [TransactionFetchType]) async -> AnyPublisher<[Transaction], PromiseError> {
        func fetchLatestTransactions(transactions: [Transaction] = [], schedulerProvider: SchedulerProvider & LatestTransactionProvidable) -> AnyPublisher<[Transaction], PromiseError> {
            var transactions = transactions
            return schedulerProvider.fetchPublisher()
                .flatMap { response -> AnyPublisher<[Transaction], PromiseError> in
                    if response.isEmpty {
                        return .just(transactions)
                    } else {
                        let newTransactions = Array(Set(transactions).union(response))
                        if transactions.count == newTransactions.count {
                            return .just(newTransactions)
                        } else {
                            return fetchLatestTransactions(transactions: transactions, schedulerProvider: schedulerProvider)
                        }
                    }
                }.eraseToAnyPublisher()
        }

        let publishers = await fetchTypes.asyncCompactMap { getSchedulerProvider(fetchType: $0) }
            .map {
                fetchLatestTransactions(schedulerProvider: $0.schedulerProvider)
                    .replaceError(with: [])
                    .eraseToAnyPublisher()
            }

        guard !publishers.isEmpty else { return .empty() }

        return Publishers.MergeMany(publishers)
            .collect()
            .map { $0.flatMap { $0 } }
            .setFailureType(to: PromiseError.self)
            .eraseToAnyPublisher()
    }

    private nonisolated func removeUnknownTransactions() {
        //TODO: why do we remove such transactions? especially `.failed` and `.unknown`?
        transactionDataStore.removeTransactions(for: [.unknown], servers: [session.server])
    }

    private func handle(response: Result<[Transaction], PromiseError>, provider: SchedulerProvider) {
        switch response {
        case .success(let transactions):
            addOrUpdate(transactions: transactions)
        case .failure(let error):
            if case BlockchainExplorerError.methodNotSupported = error.embedded {
                if let scheduler = schedulerProviders.first(where: { $0.schedulerProvider === provider }) {
                    scheduler.cancel()
                }
            }
        }
    }

    private nonisolated func addOrUpdate(transactions: [Transaction]) {
        guard !transactions.isEmpty else { return }

        Task { @MainActor in
            await transactionDataStore.addOrUpdate(transactions: transactions)
            ercTokenDetector.detect(from: transactions)
        }
    }

    private func getSchedulerProvider(fetchType: TransactionFetchType) -> SchedulerProviderData? {
        schedulerProviders.first(where: { $0.fetchType == fetchType })
    }

    private func transactionFetchType(transaction: Transaction) -> TransactionFetchType {
        if let operation = transaction.operation {
            switch operation.operationType {
            case .erc1155TokenTransfer: return .erc1155
            case .erc20TokenTransfer: return .erc20
            case .erc721TokenTransfer: return .erc721
            default: return .normal
            }
        } else {
            return .normal
        }
    }

    private func forceFetchLatestTransactions(transaction: Transaction) {
        if let operation = transaction.operation {
            switch operation.operationType {
            case .erc1155TokenTransfer:
                guard let service = getSchedulerProvider(fetchType: .erc1155) else { return }
                service.restart(force: true)
            case .erc20TokenTransfer:
                guard let service = getSchedulerProvider(fetchType: .erc20) else { return }
                service.restart(force: true)
            case .erc721TokenTransfer:
                guard let service = getSchedulerProvider(fetchType: .erc721) else { return }
                service.restart(force: true)
            default:
                guard let service = getSchedulerProvider(fetchType: .normal) else { return }
                service.restart(force: true)
            }
        } else {
            guard let service = getSchedulerProvider(fetchType: .normal) else { return }
            service.restart(force: true)
        }
    }
}

private protocol LatestTransactionProvidable {
    var publisher: AnyPublisher<Result<[Transaction], PromiseError>, Never> { get }

    func fetchPublisher() -> AnyPublisher<[Transaction], PromiseError>
}

extension EtherscanSingleChainTransactionProvider {

    private struct SchedulerProviderData {
        private let scheduler: Scheduler

        let fetchType: TransactionFetchType
        let schedulerProvider: SchedulerProvider & LatestTransactionProvidable

        init(fetchType: TransactionFetchType,
             schedulerProvider: SchedulerProvider & LatestTransactionProvidable) {

            self.fetchType = fetchType
            self.scheduler = Scheduler(provider: schedulerProvider)
            self.schedulerProvider = schedulerProvider
        }

        func start() {
            scheduler.start()
        }

        func cancel() {
            scheduler.cancel()
        }

        func restart(force: Bool = false) {
            scheduler.restart(force: force)
        }
    }

    final class LatestTransferTransactionsSchedulerProvider: SchedulerProvider, LatestTransactionProvidable {
        private let session: WalletSession
        private let blockchainExplorer: BlockchainExplorer
        private let subject = PassthroughSubject<Result<[Transaction], PromiseError>, Never>()
        private let stateProvider: SchedulerStateProvider
        private let transferType: TransactionFetchType

        let interval: TimeInterval
        var name: String { "LatestTransferTransactionsSchedulerProvider.\(session.account.address.eip55String).\(session.server)" }
        var operation: AnyPublisher<Void, PromiseError> {
            return fetchPublisher()
                .mapToVoid()
                .eraseToAnyPublisher()
        }

        var publisher: AnyPublisher<Result<[Transaction], PromiseError>, Never> {
            subject.eraseToAnyPublisher()
        }

        init(session: WalletSession, blockchainExplorer: BlockchainExplorer, transferType: TransactionFetchType, interval: TimeInterval, stateProvider: SchedulerStateProvider) {
            self.stateProvider = stateProvider
            self.transferType = transferType
            self.interval = interval
            self.session = session
            self.blockchainExplorer = blockchainExplorer
        }

        func fetchPublisher() -> AnyPublisher<[Transaction], PromiseError> {
            //TODO can remove after a while, maybe? This is to fix previously marking it as not supported
            if transferType == .erc721 && session.server == .sepolia {
                stateProvider.state = .initial
            }

            guard stateProvider.state != .stopped else {
                return .fail(PromiseError(error: SchedulerError.cancelled))
            }

            return buildFetchPublisher()
                .handleEvents(receiveOutput: { [weak self] response in
                    self?.handle(response: response.transactions)
                }, receiveCompletion: { [weak self] result in
                    guard case .failure(let e) = result else { return }
                    self?.handle(error: e)
                }).map { $0.transactions }
                .eraseToAnyPublisher()
        }

        //NOTE: don't play with .stopped state set it only when method is not supported, otherwise u will stop service
        private func buildFetchPublisher() -> AnyPublisher<TransactionsResponse, PromiseError> {
            //TODO remove Config instance creation
            if Config().development.isAutoFetchingDisabled {
                return .empty()
            }

            let server = session.server
            let wallet = session.account.address

            switch transferType {
            case .erc20:
                let startBlock = Config.getLastFetchedErc20InteractionBlockNumber(server, wallet: wallet).flatMap { $0 + 1 }
                let pagination = BlockBasedPagination(startBlock: startBlock, endBlock: nil)

                return blockchainExplorer.erc20TokenTransferTransactions(walletAddress: wallet, pagination: pagination)
                    .handleEvents(receiveOutput: { response in
                        //Just to be sure, we don't want any kind of strange errors to clear our progress by resetting blockNumber = 0
                        if let nextPage = response.nextPage as? BlockBasedPagination, let maxBlockNumber = nextPage.startBlock {
                            Config.setLastFetchedErc20InteractionBlockNumber(maxBlockNumber, server: server, wallet: wallet)
                        }
                    }).eraseToAnyPublisher()
            case .erc721:
                let startBlock = Config.getLastFetchedErc721InteractionBlockNumber(server, wallet: wallet).flatMap { $0 + 1 }
                let pagination = BlockBasedPagination(startBlock: startBlock, endBlock: nil)
                return blockchainExplorer.erc721TokenTransferTransactions(walletAddress: wallet, pagination: pagination)
                    .handleEvents(receiveOutput: { response in
                        //Just to be sure, we don't want any kind of strange errors to clear our progress by resetting blockNumber = 0
                        if let nextPage = response.nextPage as? BlockBasedPagination, let maxBlockNumber = nextPage.startBlock {
                            Config.setLastFetchedErc721InteractionBlockNumber(maxBlockNumber, server: server, wallet: wallet)
                        }
                    }).eraseToAnyPublisher()
            case .erc1155:
                let startBlock = Config.getLastFetchedErc1155InteractionBlockNumber(session.server, wallet: wallet).flatMap { $0 + 1 }
                let pagination = BlockBasedPagination(startBlock: startBlock, endBlock: nil)

                return blockchainExplorer.erc1155TokenTransferTransaction(walletAddress: wallet, pagination: pagination)
                    .handleEvents(receiveOutput: { response in
                        //Just to be sure, we don't want any kind of strange errors to clear our progress by resetting blockNumber = 0
                        if let nextPage = response.nextPage as? BlockBasedPagination, let maxBlockNumber = nextPage.startBlock {
                            Config.setLastFetchedErc1155InteractionBlockNumber(maxBlockNumber, server: server, wallet: wallet)
                        }
                    }).eraseToAnyPublisher()
            case .normal:
                return .empty()
            }
        }

        private func handle(response: [Transaction]) {
            subject.send(.success(response))
        }

        private func handle(error: PromiseError) {
            if case BlockchainExplorerError.methodNotSupported = error.embedded {
                //We mark as "stopped" (the wording is not right, it should just be "notSupported") and persist it, so we wouldn't attempt to use it for that type of transaction fetching on that particular chain
                //TODO we didn't track the API service (e.g Etherscan vs Blockscout) used, so it's possible that it's not supported on one and then we switch to one that supports it and we wouldn't know to use it
                stateProvider.state = .stopped
            } else {
                stateProvider.state = .failured
            }

            subject.send(.failure(error))
        }
    }

    final class LatestTransactionsSchedulerProvider: SchedulerProvider, LatestTransactionProvidable {
        private let session: WalletSession
        private let blockchainExplorer: BlockchainExplorer
        private let subject = PassthroughSubject<Result<[Transaction], PromiseError>, Never>()
        private let stateProvider: SchedulerStateProvider
        private let transactionDataStore: TransactionDataStore

        let interval: TimeInterval
        var name: String { "LatestTransactionsSchedulerProvider.\(session.account.address.eip55String)" }
        var operation: AnyPublisher<Void, PromiseError> {
            return fetchPublisher()
                .mapToVoid()
                .eraseToAnyPublisher()
        }

        var publisher: AnyPublisher<Result<[Transaction], PromiseError>, Never> {
            subject.eraseToAnyPublisher()
        }

        init(session: WalletSession, blockchainExplorer: BlockchainExplorer, transactionDataStore: TransactionDataStore, interval: TimeInterval, stateProvider: SchedulerStateProvider) {
            self.stateProvider = stateProvider
            self.transactionDataStore = transactionDataStore
            self.interval = interval
            self.session = session
            self.blockchainExplorer = blockchainExplorer
        }

        ///Fetching transactions might take a long time, we use a flag to make sure we only pull the latest transactions 1 "page" at a time, otherwise we'd end up pulling the same "page" multiple times
        func fetchPublisher() -> AnyPublisher<[Transaction], PromiseError> {
            guard stateProvider.state != .stopped else {
                return .fail(PromiseError(error: SchedulerError.cancelled))
            }

            //TODO remove Config instance creation
            if Config().development.isAutoFetchingDisabled {
                return .empty()
            }

            let publisher = Future<[Transaction], PromiseError> { promise in
                Task { @MainActor in
                    let startBlock: Int
                    let sortOrder: GetTransactions.SortOrder
                    if let newestCachedTransaction = await self.transactionDataStore.transactionObjectsThatDoNotComeFromEventLogs(forServer: self.session.server) {
                        startBlock = newestCachedTransaction.blockNumber + 1
                        sortOrder = .asc
                    } else {
                        startBlock = 1
                        sortOrder = .desc
                    }

                    let pagination = BlockBasedPagination(startBlock: startBlock, endBlock: 999_999_999)

                    self.blockchainExplorer
                        .normalTransactions(walletAddress: self.session.account.address, sortOrder: sortOrder, pagination: pagination)
                        .handleEvents(receiveOutput: { [weak self] response in
                            self?.handle(response: response.transactions)
                            promise(Result.success(response.transactions))
                        }, receiveCompletion: { [weak self] result in
                            guard case .failure(let e) = result else { return }
                            self?.handle(error: e)
                        })
                }
            }
            return publisher.eraseToAnyPublisher()
        }

        private func handle(response: [Transaction]) {
            subject.send(.success(response))
        }

        private func handle(error: PromiseError) {
            if case BlockchainExplorerError.methodNotSupported = error.embedded {
                stateProvider.state = .stopped
            } else {
                stateProvider.state = .failured
            }

            subject.send(.failure(error))
        }
    }

    final class OldestTransactionsSchedulerProvider: SchedulerProvider {
        private let session: WalletSession
        private let blockchainExplorer: BlockchainExplorer
        private let subject = PassthroughSubject<Result<[Transaction], PromiseError>, Never>()
        private let transactionDataStore: TransactionDataStore
        private let stateProvider: SchedulerStateProvider

        let interval: TimeInterval
        var name: String { "OldestTransactionsSchedulerProvider.\(session.account.address.eip55String)" }
        var operation: AnyPublisher<Void, PromiseError> {
            return fetchPublisher()
        }

        var publisher: AnyPublisher<Result<[Transaction], PromiseError>, Never> {
            subject.eraseToAnyPublisher()
        }

        init(session: WalletSession, blockchainExplorer: BlockchainExplorer, transactionDataStore: TransactionDataStore, stateProvider: SchedulerStateProvider, interval: TimeInterval) {
            self.stateProvider = stateProvider
            self.transactionDataStore = transactionDataStore
            self.interval = interval
            self.session = session
            self.blockchainExplorer = blockchainExplorer
        }

        ///Fetching transactions might take a long time, we use a flag to make sure we only pull the latest transactions 1 "page" at a time, otherwise we'd end up pulling the same "page" multiple times
        private func fetchPublisher() -> AnyPublisher<Void, PromiseError> {
            guard stateProvider.state != .stopped else {
                return .fail(PromiseError(error: SchedulerError.cancelled))
            }

            let subject = PassthroughSubject<Void, PromiseError>()
            Task { @MainActor in
                guard let oldestCachedTransaction = await transactionDataStore.lastTransaction(forServer: session.server) else {
                    subject.send()
                    return
                }

                let pagination = BlockBasedPagination(startBlock: 1, endBlock: oldestCachedTransaction.blockNumber - 1)

                blockchainExplorer
                    .normalTransactions(walletAddress: session.account.address, sortOrder: .desc, pagination: pagination)
                    .handleEvents(receiveOutput: { [weak self] response in
                        self?.handle(response: response.transactions)
                        subject.send()
                    }, receiveCompletion: { [weak self] result in
                        guard case .failure(let e) = result else { return }
                        self?.handle(error: e)
                    })
            }
            return subject.eraseToAnyPublisher()
        }

        private func handle(response: [Transaction]) {
            if response.isEmpty {
                stateProvider.state = .stopped
            }

            subject.send(.success(response))
        }

        private func handle(error: PromiseError) {
            if case BlockchainExplorerError.methodNotSupported = error.embedded {
                stateProvider.state = .stopped
            } else {
                stateProvider.state = .failured
            }

            subject.send(.failure(error))
        }
    }
}
