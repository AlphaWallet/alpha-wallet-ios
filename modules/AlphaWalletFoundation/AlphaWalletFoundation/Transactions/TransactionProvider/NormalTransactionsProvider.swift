//
//  NewlyAddedTransactionProvider.swift
//  AlphaWalletFoundation
//
//  Created by Vladyslav Shepitko on 07.03.2023.
//

import Foundation
import Combine
import AlphaWalletCore

enum TransactionFetchType: String {
    case normal
    case erc20
    case erc721
    case erc1155
}

/// Provider performs fetching newly added transactions start from 0 page and increase page index untinl it find some of transactions that has already stored in db.
/// Resets page index once it found first matching transactions
final class NormalTransactionsProvider {
    private let session: WalletSession
    private let scheduler: SchedulerProtocol
    private let ercTokenDetector: ErcTokenDetector
    private let queue = DispatchQueue(label: "com.NormalTransactionsProvider.updateQueue")
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

extension NormalTransactionsProvider: NormalTransactionsSchedulerProviderDelegate {
    func didReceiveResponse(_ response: Result<[TransactionInstance], PromiseError>, in provider: NormalTransactionsSchedulerProvider) {
        switch response {
        case .success(let transactions):
            handle(transactions: transactions)
        case .failure(let error):
            handle(error: error)
        }
    }
}
