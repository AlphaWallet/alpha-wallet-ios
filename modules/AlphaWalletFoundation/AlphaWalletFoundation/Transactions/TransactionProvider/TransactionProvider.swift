//
//  TransactionProvider.swift
//  AlphaWalletFoundation
//
//  Created by Vladyslav Shepitko on 07.03.2023.
//

import Foundation
import Combine
import AlphaWalletCore

public class TransactionProvider: SingleChainTransactionProvider {
    private let transactionDataStore: TransactionDataStore
    private let session: WalletSession
    private let analytics: AnalyticsLogger
    private let ercTokenDetector: ErcTokenDetector
    private let networking: ApiNetworking
    private lazy var pendingTransactionProvider: PendingTransactionProvider = {
        return PendingTransactionProvider(
            session: session,
            transactionDataStore: transactionDataStore,
            ercTokenDetector: ercTokenDetector)
    }()
    private let schedulerProviders: [TransactionSchedulerProviderData]
    private var cancellable = Set<AnyCancellable>()
    private let queue = DispatchQueue(label: "com.transactionProvider.updateQueue")

    public private (set) var state: TransactionProviderState = .pending

    public init(session: WalletSession,
                analytics: AnalyticsLogger,
                transactionDataStore: TransactionDataStore,
                ercTokenDetector: ErcTokenDetector,
                networking: ApiNetworking,
                defaultPagination: TransactionsPagination,
                fetchTypes: [TransactionFetchType] = TransactionProvider.TransactionFetchType.allCases) {

        self.session = session
        self.networking = networking
        self.analytics = analytics
        self.transactionDataStore = transactionDataStore
        self.ercTokenDetector = ercTokenDetector
        self.schedulerProviders = fetchTypes.map { fetchType in
            let schedulerProvider = TransactionSchedulerProvider(
                session: session,
                networking: networking,
                defaultPagination: defaultPagination,
                interval: Constants.Covalent.newlyAddedTransactionUpdateInterval,
                paginationStorage: WalletConfig(address: session.account.address),
                fetchType: fetchType,
                stateProvider: PersistantSchedulerStateProvider(sessionID: session.sessionID, prefix: fetchType.rawValue))
            let scheduler = Scheduler(provider: schedulerProvider)

            return TransactionSchedulerProviderData(
                scheduler: scheduler,
                fetchType: fetchType,
                schedulerProvider: schedulerProvider)
        }

        self.schedulerProviders.forEach { data in
            data.schedulerProvider
                .publisher
                .sink { [weak self] in self?.handle(response: $0, provider: data.schedulerProvider) }
                .store(in: &cancellable)
        }

        pendingTransactionProvider.completeTransaction
            .compactMap { try? $0.get() }
            .sink { [weak self] in self?.forceFetchLatestTransactions(transaction: $0) }
            .store(in: &cancellable)
    }

    deinit {
        schedulerProviders.forEach { $0.cancel() }
        pendingTransactionProvider.cancelScheduler()
    }

    private func handle(response: Result<[Transaction], PromiseError>, provider: SchedulerProvider) {
        switch response {
        case .success(let transactions):
            let newOrUpdatedTransactions = transactionDataStore.addOrUpdate(transactions: transactions)
            ercTokenDetector.detect(from: newOrUpdatedTransactions)
        case .failure(let error):
            if case ApiNetworkingError.methodNotSupported = error.embedded {
                if let data = schedulerProviders.first(where: { $0.schedulerProvider === provider }) {
                    data.cancel()
                }
            }
        }
    }

    private func getSchedulerProvider(fetchType: TransactionFetchType) -> TransactionSchedulerProviderData? {
        schedulerProviders.first(where: { $0.fetchType == fetchType })
    }

    private func forceFetchLatestTransactions(transaction: Transaction) {
        if let operation = transaction.operation {
            switch operation.operationType {
            case .erc1155TokenTransfer:
                guard let service = self.getSchedulerProvider(fetchType: .erc1155) else { return }
                service.restart(force: true)
            case .erc20TokenTransfer:
                guard let service = self.getSchedulerProvider(fetchType: .erc20) else { return }
                service.restart(force: true)
            case .erc721TokenTransfer:
                guard let service = self.getSchedulerProvider(fetchType: .erc721) else { return }
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

    public func start() {
        guard state == .pending else { return }

        pendingTransactionProvider.start()
        schedulerProviders.forEach { $0.start() }
        queue.async { [weak self] in self?.removeUnknownTransactions() }
        state = .running
    }

    public func resume() {
        guard state == .stopped else { return }

        pendingTransactionProvider.resumeScheduler()

        schedulerProviders.forEach { $0.restart() }
        state = .running
    }

    public func pause() {
        guard state == .running || state == .pending else { return }

        pendingTransactionProvider.cancelScheduler()
        schedulerProviders.forEach { $0.cancel() }
        state = .stopped
    }

    public func isServer(_ server: RPCServer) -> Bool {
        return session.server == server
    }

    private func removeUnknownTransactions() {
        //TODO why do we remove such transactions? especially `.failed` and `.unknown`?
        transactionDataStore.removeTransactions(for: [.unknown], servers: [session.server])
    }
}

extension TransactionProvider {
    private struct TransactionSchedulerProviderData {
        private let scheduler: Scheduler

        let fetchType: TransactionFetchType
        let schedulerProvider: TransactionProvider.TransactionSchedulerProvider

        init(scheduler: Scheduler,
             fetchType: TransactionFetchType,
             schedulerProvider: TransactionProvider.TransactionSchedulerProvider) {

            self.scheduler = scheduler
            self.fetchType = fetchType
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

    public enum TransactionFetchType: String, CaseIterable {
        case normal
        case erc20
        case erc721
        case erc1155
    }

    final class TransactionSchedulerProvider: SchedulerProvider {
        private let session: WalletSession
        private let networking: ApiNetworking
        private var paginationStorage: TransactionsPaginationStorage
        private let defaultPagination: TransactionsPagination
        private let fetchType: TransactionFetchType
        private let stateProvider: SchedulerStateProvider
        private let subject = PassthroughSubject<Result<[Transaction], PromiseError>, Never>()

        var interval: TimeInterval
        var name: String { "TransactionSchedulerProvider.\(fetchType)" }
        var operation: AnyPublisher<Void, PromiseError> {
            return fetchPublisher()
        }

        var publisher: AnyPublisher<Result<[Transaction], PromiseError>, Never> {
            subject.eraseToAnyPublisher()
        }

        init(session: WalletSession,
             networking: ApiNetworking,
             defaultPagination: TransactionsPagination,
             interval: TimeInterval,
             paginationStorage: TransactionsPaginationStorage,
             fetchType: TransactionFetchType,
             stateProvider: SchedulerStateProvider) {

            self.stateProvider = stateProvider
            self.fetchType = fetchType
            self.interval = interval
            self.defaultPagination = defaultPagination
            self.paginationStorage = paginationStorage
            self.session = session
            self.networking = networking
        }

        private func fetchPublisher() -> AnyPublisher<Void, PromiseError> {
            guard stateProvider.state != .stopped else {
                return .fail(PromiseError(error: SchedulerError.cancelled))
            }

            return buildFetchPublisher()
                .handleEvents(receiveOutput: { [weak self] response in
                    self?.handle(response: response)
                }, receiveCompletion: { [weak self] result in
                    guard case .failure(let e) = result else { return }
                    self?.handle(error: e)
                }).mapToVoid()
                .eraseToAnyPublisher()
        }

        private func buildFetchPublisher() -> AnyPublisher<TransactionsResponse, PromiseError> {
            let pagination = paginationStorage.transactionsPagination(server: session.server, fetchType: fetchType) ?? defaultPagination

            switch fetchType {
            case .normal:
                return networking.normalTransactions(walletAddress: session.account.address, pagination: pagination)
            case .erc20:
                return networking.erc20TokenTransferTransactions(walletAddress: session.account.address, pagination: pagination)
            case .erc721:
                return networking.erc721TokenTransferTransactions(walletAddress: session.account.address, pagination: pagination)
            case .erc1155:
                return networking.erc1155TokenTransferTransaction(walletAddress: session.account.address, pagination: pagination)
            }
        }
        //NOTE: pay attention! response from networking returns pagination for next page
        private func handle(response: TransactionsResponse) {
            paginationStorage.set(
                transactionsPagination: response.pagination,
                fetchType: fetchType,
                server: session.server)

            subject.send(.success(response.transactions))
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
