//
//  Erc20TransferTransactionProvider.swift
//  AlphaWalletFoundation
//
//  Created by Vladyslav Shepitko on 08.03.2023.
//

import Foundation
import Combine
import AlphaWalletCore

final class Erc20TransferTransactionProvider {
    private let session: WalletSession
    private let scheduler: SchedulerProtocol
    private let ercTokenDetector: ErcTokenDetector
    private let queue = DispatchQueue(label: "com.erc20TransferTransactionProvider.updateQueue")
    private let transactionDataStore: TransactionDataStore
    private var storage: TransactionsPaginationStorage

    init(session: WalletSession,
         scheduler: SchedulerProtocol,
         ercTokenDetector: ErcTokenDetector,
         storage: TransactionsPaginationStorage,
         transactionDataStore: TransactionDataStore) {

        self.session = session
        self.scheduler = scheduler
        self.ercTokenDetector = ercTokenDetector
        self.transactionDataStore = transactionDataStore
        self.storage = storage
    }

    func startScheduler() {
        queue.async { [scheduler] in scheduler.start() }
    }

    func resumeScheduler() {
        queue.async { [scheduler] in scheduler.resume() }
    }

    func cancelScheduler() {
        queue.async { [scheduler] in scheduler.cancel() }
    }

    deinit {
        scheduler.cancel()
    }

    private func handle(transactions: [TransactionInstance]) {
        let newOrUpdatedTransactions = transactionDataStore.addOrUpdate(transactions: transactions)
        ercTokenDetector.detect(from: newOrUpdatedTransactions)
    }

    private func handle(error: PromiseError) {
        //no-op
    }
}

extension Erc20TransferTransactionProvider: Erc20TransferTransactionSchedulerDelegate {
    func didReceiveResponse(_ response: Result<[TransactionInstance], PromiseError>, in provider: Erc20TransferTransactionSchedulerProvider) {
        switch response {
        case .success(let transactions):
            handle(transactions: transactions)
        case .failure(let error):
            handle(error: error)
        }
    }
}
