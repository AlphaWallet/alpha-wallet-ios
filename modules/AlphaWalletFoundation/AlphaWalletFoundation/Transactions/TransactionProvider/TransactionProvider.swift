//
//  TransactionProvider.swift
//  AlphaWalletFoundation
//
//  Created by Vladyslav Shepitko on 07.03.2023.
//

import Foundation
import Combine

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

    private lazy var normalTransactionProvider: NormalTransactionsProvider = {
        let schedulerProvider = NormalTransactionsSchedulerProvider(
            session: session,
            networking: networking,
            defaultPagination: defaultPagination,
            interval: Constants.Covalent.newlyAddedTransactionUpdateInterval,
            storage: WalletConfig(address: session.account.address))

        let scheduler = Scheduler(provider: schedulerProvider)
        let provider = NormalTransactionsProvider(
            session: session,
            scheduler: scheduler,
            ercTokenDetector: ercTokenDetector,
            storage: WalletConfig(address: session.account.address),
            transactionDataStore: transactionDataStore)

        schedulerProvider.delegate = provider

        return provider
    }()

    private lazy var erc20TransferTransactionProvider: Erc20TransferTransactionProvider = {
        let schedulerProvider = Erc20TransferTransactionSchedulerProvider(
            session: session,
            networking: networking,
            defaultPagination: defaultPagination,
            interval: Constants.Covalent.newlyAddedTransactionUpdateInterval,
            storage: WalletConfig(address: session.account.address))

        let scheduler = Scheduler(provider: schedulerProvider)
        let provider = Erc20TransferTransactionProvider(
            session: session,
            scheduler: scheduler,
            ercTokenDetector: ercTokenDetector,
            storage: WalletConfig(address: session.account.address),
            transactionDataStore: transactionDataStore)

        schedulerProvider.delegate = provider

        return provider
    }()

    private lazy var erc721TransferTransactionProvider: Erc721TransferTransactionProvider = {
        let schedulerProvider = Erc721TransferTransactionSchedulerProvider(
            session: session,
            networking: networking,
            defaultPagination: defaultPagination,
            interval: Constants.Covalent.newlyAddedTransactionUpdateInterval,
            storage: WalletConfig(address: session.account.address))

        let scheduler = Scheduler(provider: schedulerProvider)
        let provider = Erc721TransferTransactionProvider(
            session: session,
            scheduler: scheduler,
            ercTokenDetector: ercTokenDetector,
            storage: WalletConfig(address: session.account.address),
            transactionDataStore: transactionDataStore)

        schedulerProvider.delegate = provider

        return provider
    }()

    private lazy var erc1155TransferTransactionProvider: Erc1155TransferTransactionProvider = {
        let schedulerProvider = Erc1155TransferTransactionSchedulerProvider(
            session: session,
            networking: networking,
            defaultPagination: defaultPagination,
            interval: Constants.Covalent.newlyAddedTransactionUpdateInterval,
            storage: WalletConfig(address: session.account.address))

        let scheduler = Scheduler(provider: schedulerProvider)
        let provider = Erc1155TransferTransactionProvider(
            session: session,
            scheduler: scheduler,
            ercTokenDetector: ercTokenDetector,
            storage: WalletConfig(address: session.account.address),
            transactionDataStore: transactionDataStore)

        schedulerProvider.delegate = provider

        return provider
    }()

    private let defaultPagination: TransactionsPagination

    public init(session: WalletSession,
                analytics: AnalyticsLogger,
                transactionDataStore: TransactionDataStore,
                ercTokenDetector: ErcTokenDetector,
                networking: ApiNetworking,
                defaultPagination: TransactionsPagination) {

        self.defaultPagination = defaultPagination
        self.session = session
        self.networking = networking
        self.analytics = analytics
        self.transactionDataStore = transactionDataStore
        self.ercTokenDetector = ercTokenDetector
    }

    public func start() {
        normalTransactionProvider.startScheduler()
        pendingTransactionProvider.start()
        erc20TransferTransactionProvider.startScheduler()
        erc721TransferTransactionProvider.startScheduler()
        erc1155TransferTransactionProvider.startScheduler()
        DispatchQueue(label: "com.transactionProvider.updateQueue").async { [weak self] in self?.removeUnknownTransactions() }
    }

    public func stopTimers() {
        normalTransactionProvider.cancelScheduler()
        pendingTransactionProvider.cancelScheduler()
        erc20TransferTransactionProvider.cancelScheduler()
        erc721TransferTransactionProvider.cancelScheduler()
        erc1155TransferTransactionProvider.cancelScheduler()
    }

    public func runScheduledTimers() {
        normalTransactionProvider.resumeScheduler()
        pendingTransactionProvider.resumeScheduler()
        erc20TransferTransactionProvider.resumeScheduler()
        erc721TransferTransactionProvider.resumeScheduler()
        erc1155TransferTransactionProvider.resumeScheduler()
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
