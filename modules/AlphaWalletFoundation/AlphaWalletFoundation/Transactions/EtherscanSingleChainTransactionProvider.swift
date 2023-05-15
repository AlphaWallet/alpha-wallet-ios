// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import BigInt
import Combine
import AlphaWalletCore

class EtherscanSingleChainTransactionProvider: SingleChainTransactionProvider {
    private let transactionDataStore: TransactionDataStore
    private let session: WalletSession
    private let ercTokenDetector: ErcTokenDetector
    private let schedulerProviders: AtomicArray<SchedulerProviderData>
    private lazy var pendingTransactionProvider: PendingTransactionProvider = {
        return PendingTransactionProvider(
            session: session,
            transactionDataStore: transactionDataStore,
            ercTokenDetector: ercTokenDetector)
    }()
    private var cancellable = Set<AnyCancellable>()
    private let oldestTransferTransactionsScheduler: Scheduler
    private let queue = DispatchQueue(label: "com.transactionProvider.updateQueue")

    public private (set) var state: TransactionProviderState = .pending

    init(session: WalletSession,
         analytics: AnalyticsLogger,
         transactionDataStore: TransactionDataStore,
         ercTokenDetector: ErcTokenDetector,
         apiNetworking: ApiNetworking) {

        self.session = session
        self.transactionDataStore = transactionDataStore
        self.ercTokenDetector = ercTokenDetector

        let latestTransactionsProvider = LatestTransactionsSchedulerProvider(
            session: session,
            apiNetworking: session.apiNetworking,
            transactionDataStore: transactionDataStore,
            interval: 15,
            stateProvider: PersistantSchedulerStateProvider(sessionID: session.sessionID, prefix: EtherscanCompatibleSchedulerStatePrefix.normalTransactions.rawValue))

        let erc20LatestTransactionsProvider = LatestTransferTransactionsSchedulerProvider(
            session: session,
            apiNetworking: session.apiNetworking,
            transferType: .erc20TokenTransfer,
            interval: 15,
            stateProvider: PersistantSchedulerStateProvider(sessionID: session.sessionID, prefix: EtherscanCompatibleSchedulerStatePrefix.erc20LatestTransactions.rawValue))

        let erc721LatestTransactionsProvider = LatestTransferTransactionsSchedulerProvider(
            session: session,
            apiNetworking: session.apiNetworking,
            transferType: .erc721TokenTransfer,
            interval: 15,
            stateProvider: PersistantSchedulerStateProvider(sessionID: session.sessionID, prefix: EtherscanCompatibleSchedulerStatePrefix.erc721LatestTransactions.rawValue))

        let oldestTransactionsStateProvider = PersistantSchedulerStateProvider(
            sessionID: session.sessionID,
            prefix: EtherscanCompatibleSchedulerStatePrefix.oldestTransaction.rawValue)

        let oldestTransactionsProvider = OldestTransactionsSchedulerProvider(
            session: session,
            apiNetworking: session.apiNetworking,
            transactionDataStore: transactionDataStore,
            stateProvider: oldestTransactionsStateProvider)

        schedulerProviders = .init([
            .init(fetchType: .normal, schedulerProvider: latestTransactionsProvider, publisher: latestTransactionsProvider.publisher),
            .init(fetchType: .erc20Transfer, schedulerProvider: erc20LatestTransactionsProvider, publisher: erc20LatestTransactionsProvider.publisher),
            .init(fetchType: .erc721Transfer, schedulerProvider: erc721LatestTransactionsProvider, publisher: erc721LatestTransactionsProvider.publisher)
        ])

        oldestTransferTransactionsScheduler = Scheduler(provider: oldestTransactionsProvider)

        schedulerProviders.forEach { data in
            data.publisher
                .sink { [weak self] in self?.handle(response: $0, provider: data.schedulerProvider) }
                .store(in: &cancellable)
        }

        oldestTransactionsProvider.publisher
            .sink { [weak self] in self?.handle(response: $0, provider: oldestTransactionsProvider) }
            .store(in: &cancellable)

        pendingTransactionProvider.completeTransaction
            .compactMap { try? $0.get() }
            .sink { [weak self] in self?.forceFetchLatestTransactions(transaction: $0) }
            .store(in: &cancellable)
    }

    deinit {
        schedulerProviders.forEach { $0.cancel() }
        oldestTransferTransactionsScheduler.cancel()
        pendingTransactionProvider.cancelScheduler()
    }

    func resume() {
        guard state == .stopped else { return }

        pendingTransactionProvider.resumeScheduler()
        schedulerProviders.forEach { $0.restart() }
        oldestTransferTransactionsScheduler.restart()

        state = .running
    }

    func pause() {
        guard state == .running || state == .pending else { return }

        pendingTransactionProvider.cancelScheduler()
        schedulerProviders.forEach { $0.cancel() }
        oldestTransferTransactionsScheduler.cancel()

        state = .stopped
    }

    func start() {
        pendingTransactionProvider.start()
        schedulerProviders.forEach { $0.start() }
        oldestTransferTransactionsScheduler.start()

        queue.async { [weak self] in self?.removeUnknownTransactions() }
        state = .running
    }

    public func stop() {
        pendingTransactionProvider.cancelScheduler()
        schedulerProviders.forEach { $0.cancel() }
        oldestTransferTransactionsScheduler.cancel()
    }

    public func isServer(_ server: RPCServer) -> Bool {
        return session.server == server
    }

    private func removeUnknownTransactions() {
        //TODO why do we remove such transactions? especially `.failed` and `.unknown`?
        transactionDataStore.removeTransactions(for: [.unknown], servers: [session.server])
    }

    private func handle(response: Result<[Transaction], PromiseError>, provider: SchedulerProvider) {
        switch response {
        case .success(let transactions):
            addOrUpdate(transactions: transactions)
        case .failure(let error):
            if case ApiNetworkingError.methodNotSupported = error.embedded {
                if let scheduler = schedulerProviders.first(where: { $0.schedulerProvider === provider }) {
                    scheduler.cancel()
                }
            }
        }
    }

    private func addOrUpdate(transactions: [Transaction]) {
        guard !transactions.isEmpty else { return }

        transactionDataStore.addOrUpdate(transactions: transactions)
        ercTokenDetector.detect(from: transactions)
    }

    private func getSchedulerProvider(fetchType: FetchType) -> SchedulerProviderData? {
        schedulerProviders.first(where: { $0.fetchType == fetchType })
    }

    private func forceFetchLatestTransactions(transaction: Transaction) {
        if let operation = transaction.operation {
            switch operation.operationType {
            case .erc1155TokenTransfer:
                guard let service = self.getSchedulerProvider(fetchType: .erc1155Transfer) else { return }
                service.restart(force: true)
            case .erc20TokenTransfer:
                guard let service = self.getSchedulerProvider(fetchType: .erc20Transfer) else { return }
                service.restart(force: true)
            case .erc721TokenTransfer:
                guard let service = self.getSchedulerProvider(fetchType: .erc721Transfer) else { return }
                service.restart(force: true)
            default:
                guard let service = self.getSchedulerProvider(fetchType: .normal) else { return }
                service.restart(force: true)
            }
        } else {
            guard let service = self.getSchedulerProvider(fetchType: .normal) else { return }
            service.restart(force: true)
        }
    }
}

extension EtherscanSingleChainTransactionProvider {

    private struct SchedulerProviderData {
        private let scheduler: Scheduler

        let fetchType: FetchType
        let schedulerProvider: SchedulerProvider
        let publisher: AnyPublisher<Result<[Transaction], PromiseError>, Never>

        init(fetchType: FetchType,
             schedulerProvider: SchedulerProvider,
             publisher: AnyPublisher<Result<[Transaction], PromiseError>, Never>) {

            self.fetchType = fetchType
            self.scheduler = Scheduler(provider: schedulerProvider)
            self.schedulerProvider = schedulerProvider
            self.publisher = publisher
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

    private enum FetchType {
        case normal
        case erc20Transfer
        case erc721Transfer
        case erc1155Transfer
    }

    enum TransferType {
        case erc20TokenTransfer
        case erc721TokenTransfer
        case erc1155TokenTransfer
    }

    final class LatestTransferTransactionsSchedulerProvider: SchedulerProvider {
        private let session: WalletSession
        private let apiNetworking: ApiNetworking
        private let subject = PassthroughSubject<Result<[Transaction], PromiseError>, Never>()
        private let stateProvider: SchedulerStateProvider
        private let transferType: TransferType

        let interval: TimeInterval
        var name: String = ""
        var operation: AnyPublisher<Void, PromiseError> {
            return fetchPublisher()
        }

        var publisher: AnyPublisher<Result<[Transaction], PromiseError>, Never> {
            subject.eraseToAnyPublisher()
        }

        init(session: WalletSession,
             apiNetworking: ApiNetworking,
             transferType: TransferType,
             interval: TimeInterval = 0,
             stateProvider: SchedulerStateProvider,
             name: String = "") {

            self.stateProvider = stateProvider
            self.transferType = transferType
            self.name = name
            self.interval = interval
            self.session = session
            self.apiNetworking = apiNetworking
        }

        private func fetchPublisher() -> AnyPublisher<Void, PromiseError> {
            guard stateProvider.state != .stopped else {
                return .fail(PromiseError(error: SchedulerError.cancelled))
            }

            return buildFetchPublisher()
                .handleEvents(receiveOutput: { [weak self] response in
                    self?.handle(response: response.0)
                }, receiveCompletion: { [weak self] result in
                    guard case .failure(let e) = result else { return }
                    self?.handle(error: e)
                }).mapToVoid()
                .eraseToAnyPublisher()
        }

        //NOTE: don't play with .stopped state set it only when method is not supported, otherwise u will stop service
        private func buildFetchPublisher() -> AnyPublisher<([Transaction], Int), PromiseError> {
            let server = session.server
            let wallet = session.account.address

            switch transferType {
            case .erc20TokenTransfer:
                let startBlock = Config.getLastFetchedErc20InteractionBlockNumber(server, wallet: wallet).flatMap { $0 + 1 }
                return apiNetworking.erc20TokenTransferTransactions(walletAddress: wallet, startBlock: startBlock)
                    .handleEvents(receiveOutput: { _, maxBlockNumber in
                        //Just to be sure, we don't want any kind of strange errors to clear our progress by resetting blockNumber = 0
                        if maxBlockNumber > 0 {
                            Config.setLastFetchedErc20InteractionBlockNumber(maxBlockNumber, server: server, wallet: wallet)
                        }
                    }).eraseToAnyPublisher()
            case .erc721TokenTransfer:
                let startBlock = Config.getLastFetchedErc721InteractionBlockNumber(server, wallet: wallet).flatMap { $0 + 1 }
                return apiNetworking.erc721TokenTransferTransactions(walletAddress: wallet, startBlock: startBlock)
                    .handleEvents(receiveOutput: { _, maxBlockNumber in
                        //Just to be sure, we don't want any kind of strange errors to clear our progress by resetting blockNumber = 0
                        if maxBlockNumber > 0 {
                            Config.setLastFetchedErc721InteractionBlockNumber(maxBlockNumber, server: server, wallet: wallet)
                        }
                    }).eraseToAnyPublisher()
            case .erc1155TokenTransfer:
                return .empty()
            }
        }

        private func handle(response: [Transaction]) {
            subject.send(.success(response))
        }

        private func handle(error: PromiseError) {
            if case ApiNetworkingError.methodNotSupported = error.embedded {
                stateProvider.state = .stopped
            } else {
                stateProvider.state = .failured
            }

            subject.send(.failure(error))
        }
    }

    final class LatestTransactionsSchedulerProvider: SchedulerProvider {
        private let session: WalletSession
        private let apiNetworking: ApiNetworking
        private let subject = PassthroughSubject<Result<[Transaction], PromiseError>, Never>()
        private let stateProvider: SchedulerStateProvider
        private let transactionDataStore: TransactionDataStore

        let interval: TimeInterval
        let name: String
        var operation: AnyPublisher<Void, PromiseError> {
            return fetchPublisher()
        }

        var publisher: AnyPublisher<Result<[Transaction], PromiseError>, Never> {
            subject.eraseToAnyPublisher()
        }

        init(session: WalletSession,
             apiNetworking: ApiNetworking,
             transactionDataStore: TransactionDataStore,
             interval: TimeInterval = 0,
             name: String = "",
             stateProvider: SchedulerStateProvider) {

            self.stateProvider = stateProvider
            self.transactionDataStore = transactionDataStore
            self.name = name
            self.interval = interval
            self.session = session
            self.apiNetworking = apiNetworking
        }

        ///Fetching transactions might take a long time, we use a flag to make sure we only pull the latest transactions 1 "page" at a time, otherwise we'd end up pulling the same "page" multiple times
        private func fetchPublisher() -> AnyPublisher<Void, PromiseError> {
            guard stateProvider.state != .stopped else {
                return .fail(PromiseError(error: SchedulerError.cancelled))
            }

            let startBlock: Int
            let sortOrder: GetTransactions.SortOrder

            if let newestCachedTransaction = transactionDataStore.transactionObjectsThatDoNotComeFromEventLogs(forServer: session.server) {
                startBlock = newestCachedTransaction.blockNumber + 1
                sortOrder = .asc
            } else {
                startBlock = 1
                sortOrder = .desc
            }

            return apiNetworking
                .normalTransactions(walletAddress: session.account.address, startBlock: startBlock, endBlock: 999_999_999, sortOrder: sortOrder)
                .handleEvents(receiveOutput: { [weak self] response in
                    self?.handle(response: response)
                }, receiveCompletion: { [weak self] result in
                    guard case .failure(let e) = result else { return }
                    self?.handle(error: e)
                }).mapToVoid()
                .eraseToAnyPublisher()
        }

        private func handle(response: [Transaction]) {
            subject.send(.success(response))
        }

        private func handle(error: PromiseError) {
            if case ApiNetworkingError.methodNotSupported = error.embedded {
                stateProvider.state = .stopped
            } else {
                stateProvider.state = .failured
            }

            subject.send(.failure(error))
        }
    }

    final class OldestTransactionsSchedulerProvider: SchedulerProvider {
        private let session: WalletSession
        private let apiNetworking: ApiNetworking
        private let subject = PassthroughSubject<Result<[Transaction], PromiseError>, Never>()
        private let transactionDataStore: TransactionDataStore
        private let stateProvider: SchedulerStateProvider

        let interval: TimeInterval
        let name: String
        var operation: AnyPublisher<Void, PromiseError> {
            return fetchPublisher()
        }

        var publisher: AnyPublisher<Result<[Transaction], PromiseError>, Never> {
            subject.eraseToAnyPublisher()
        }

        init(session: WalletSession,
             apiNetworking: ApiNetworking,
             transactionDataStore: TransactionDataStore,
             stateProvider: SchedulerStateProvider,
             interval: TimeInterval = 0.3,
             name: String = "") {

            self.stateProvider = stateProvider
            self.transactionDataStore = transactionDataStore
            self.name = name
            self.interval = interval
            self.session = session
            self.apiNetworking = apiNetworking
        }

        ///Fetching transactions might take a long time, we use a flag to make sure we only pull the latest transactions 1 "page" at a time, otherwise we'd end up pulling the same "page" multiple times
        private func fetchPublisher() -> AnyPublisher<Void, PromiseError> {
            guard stateProvider.state != .stopped else {
                return .fail(PromiseError(error: SchedulerError.cancelled))
            }

            guard let oldestCachedTransaction = transactionDataStore.lastTransaction(forServer: session.server) else { return .empty() }

            return apiNetworking
                .normalTransactions(walletAddress: session.account.address, startBlock: 1, endBlock: oldestCachedTransaction.blockNumber - 1, sortOrder: .desc)
                .handleEvents(receiveOutput: { [weak self] response in
                    self?.handle(response: response)
                }, receiveCompletion: { [weak self] result in
                    guard case .failure(let e) = result else { return }
                    self?.handle(error: e)
                })
                .mapToVoid()
                .eraseToAnyPublisher()
        }

        private func handle(response: [Transaction]) {
            if response.isEmpty {
                stateProvider.state = .stopped
            }

            subject.send(.success(response))
        }

        private func handle(error: PromiseError) {
            if case ApiNetworkingError.methodNotSupported = error.embedded {
                stateProvider.state = .stopped
            } else {
                stateProvider.state = .failured
            }

            subject.send(.failure(error))
        }
    }
}
