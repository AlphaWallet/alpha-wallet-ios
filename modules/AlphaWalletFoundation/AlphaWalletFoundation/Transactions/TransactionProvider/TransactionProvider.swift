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

    private let defaultPagination: TransactionsPagination
    private let schedulers: [Scheduler]
    private let latestTransactionSchedulerProviders: [TransactionProvider.TransactionSchedulerProvider]
    private var cancellable = Set<AnyCancellable>()

    public init(session: WalletSession,
                analytics: AnalyticsLogger,
                transactionDataStore: TransactionDataStore,
                ercTokenDetector: ErcTokenDetector,
                networking: ApiNetworking,
                defaultPagination: TransactionsPagination,
                fetchTypes: [TransactionFetchType] = TransactionProvider.TransactionFetchType.allCases) {

        self.defaultPagination = defaultPagination
        self.session = session
        self.networking = networking
        self.analytics = analytics
        self.transactionDataStore = transactionDataStore
        self.ercTokenDetector = ercTokenDetector
        self.latestTransactionSchedulerProviders = fetchTypes.map { fetchType in
            TransactionSchedulerProvider(
                session: session,
                networking: networking,
                defaultPagination: defaultPagination,
                interval: Constants.Covalent.newlyAddedTransactionUpdateInterval,
                paginationStorage: WalletConfig(address: session.account.address),
                fetchType: fetchType,
                stateProvider: PersistantSchedulerStateProvider(sessionID: session.sessionID, prefix: fetchType.rawValue))
        }

        schedulers = latestTransactionSchedulerProviders.map { Scheduler(provider: $0) }

        latestTransactionSchedulerProviders.forEach { provider in
            provider.publisher
                .sink { [weak self] in self?.handle(response: $0, provider: provider) }
                .store(in: &cancellable)
        }
    }

    private func handle(response: Result<[Transaction], PromiseError>, provider: SchedulerProvider) {
        switch response {
        case .success(let transactions):
            let newOrUpdatedTransactions = transactionDataStore.addOrUpdate(transactions: transactions)
            ercTokenDetector.detect(from: newOrUpdatedTransactions)
        case .failure(let error):
            if case ApiNetworkingError.methodNotSupported = error.embedded {
                if let scheduler = schedulers.first(where: { $0.provider === provider }) {
                    scheduler.cancel()
                }
            }
        }
    }

    public func start() {
        pendingTransactionProvider.start()
        schedulers.forEach { $0.start() }
        DispatchQueue(label: "com.transactionProvider.updateQueue").async { [weak self] in self?.removeUnknownTransactions() }
    }

    public func stopTimers() {
        pendingTransactionProvider.cancelScheduler()
        schedulers.forEach { $0.cancel() }
    }

    public func runScheduledTimers() {
        pendingTransactionProvider.resumeScheduler()
        schedulers.forEach { $0.restart() }
    }

    public func stop() {
        stopTimers()
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
