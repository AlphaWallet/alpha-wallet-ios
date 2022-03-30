//
//  OldestTransactionProvider.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 01.04.2022.
//

import Foundation
import Combine

final class OldestTransactionProvider: NSObject {
    private let session: WalletSession
    private lazy var transactionsTracker: TransactionsTracker = TransactionsTracker(sessionID: session.sessionID)
    private let scheduler: SchedulerProtocol
    private let tokensFromTransactionsFetcher: TokensFromTransactionsFetcher
    private let queue = DispatchQueue(label: "com.OldestTransactionProvider.updateQueue")
    private let transactionDataStore: TransactionDataStore

    init(session: WalletSession, scheduler: SchedulerProtocol, tokensFromTransactionsFetcher: TokensFromTransactionsFetcher, transactionDataStore: TransactionDataStore) {
        self.session = session
        self.scheduler = scheduler
        self.tokensFromTransactionsFetcher = tokensFromTransactionsFetcher
        self.transactionDataStore = transactionDataStore
        super.init()
    }

    func startScheduler() {
        queue.async {
            guard self.transactionsTracker.fetchingState != .done else { return }
            self.scheduler.start()
        }
    }

    func resumeScheduler() {
        queue.async {
            guard self.transactionsTracker.fetchingState != .done else { return }
            self.scheduler.resume()
        }
    }

    func cancelScheduler() {
        queue.async {
            self.scheduler.cancel()
        }
    }

    deinit {
        scheduler.cancel()
    }

    private func didReceiveError(error: Covalent.CovalentError) {
        switch error {
        case .requestFailure(let e):
            switch e {
            case .general(error: let e):
                if case Covalent.DecodyingError.paginationNotFound = e {
                    transactionsTracker.fetchingState = .done
                    scheduler.cancel()
                } else {
                    transactionsTracker.fetchingState = .failed
                }
            }
        case .jsonDecodeFailure, .sessionError:
            transactionsTracker.fetchingState = .failed
        }
    }

    private func didReceiveValue(transactions: [TransactionInstance]) {
        if transactions.isEmpty {
            transactionsTracker.fetchingState = .done
            scheduler.cancel()
        } else {
            transactionDataStore.addOrUpdate(transactions: transactions)
            tokensFromTransactionsFetcher.extractNewTokens(from: transactions)
        }
    }
}

extension OldestTransactionProvider: OldestTransactionSchedulerProviderDelegate {
    func didReceiveResponse(_ response: Swift.Result<[TransactionInstance], Covalent.CovalentError>, in provider: OldestTransactionSchedulerProvider) {
        switch response {
        case .success(let transactions):
            didReceiveValue(transactions: transactions)
        case .failure(let error):
            didReceiveError(error: error)
        }
    }
}
