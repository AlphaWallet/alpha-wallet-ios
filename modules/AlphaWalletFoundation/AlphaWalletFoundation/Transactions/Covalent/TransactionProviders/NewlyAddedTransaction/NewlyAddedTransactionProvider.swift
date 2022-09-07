//
//  NewlyAddedTransactionProvider.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 01.04.2022.
//

import Foundation
import Combine

/// Provider performs fetching newly added transactions start from 0 page and increase page index untinl it find some of transactions that has already stored in db.
/// Resets page index once it found first matching transactions
final class NewlyAddedTransactionProvider: NSObject {
    private let session: WalletSession
    private let scheduler: SchedulerProtocol
    private let tokensFromTransactionsFetcher: TokensFromTransactionsFetcher
    private let queue = DispatchQueue(label: "com.NewlyAddedTransactionProvider.updateQueue")
    private let transactionDataStore: TransactionDataStore

    init(session: WalletSession, scheduler: SchedulerProtocol, tokensFromTransactionsFetcher: TokensFromTransactionsFetcher, transactionDataStore: TransactionDataStore) {
        self.session = session
        self.scheduler = scheduler
        self.tokensFromTransactionsFetcher = tokensFromTransactionsFetcher
        self.transactionDataStore = transactionDataStore
        super.init()
    }

    func startScheduler() {
        queue.async { [scheduler, transactionDataStore, session] in
            //NOTE: only when there are some transactions, otherwise transactions will be fetched via, OldestTransactionProvider
            guard transactionDataStore.transactionCount(forServer: session.server) > 0 else { return }
            scheduler.start()
        }
    }

    func resumeScheduler() {
        queue.async { [scheduler, transactionDataStore, session] in
            guard transactionDataStore.transactionCount(forServer: session.server) > 0 else { return }
            scheduler.resume()
        }
    }

    func cancelScheduler() {
        queue.async { [scheduler] in
            scheduler.cancel()
        }
    }

    deinit {
        scheduler.cancel() 
    }

    private func didReceiveValue(transactions: [TransactionInstance]) {
        let newOrUpdatedTransactions = transactionDataStore.addOrUpdate(transactions: transactions)
        tokensFromTransactionsFetcher.extractNewTokens(from: newOrUpdatedTransactions)
        //NOTE: in case if thre some transactions that already exist we can suggest to reset `covalentLastNewestPage`
        if newOrUpdatedTransactions.count != transactions.count || transactions.isEmpty {
            session.config.set(covalentLastNewestPage: session.server, wallet: session.account, page: nil)
        }
    }

    private func didReceiveError(error: Covalent.CovalentError) {
        //no-op
    }
}

extension NewlyAddedTransactionProvider: NewlyAddedTransactionSchedulerProviderDelegate {
    func didReceiveResponse(_ response: Swift.Result<[TransactionInstance], Covalent.CovalentError>, in provider: NewlyAddedTransactionSchedulerProvider) {
        switch response {
        case .success(let transactions):
            didReceiveValue(transactions: transactions)
        case .failure(let error):
            didReceiveError(error: error)
        }
    }
}

extension Covalent.ToNativeTransactionMapper {
    static func mapCovalentToNativeTransaction(transactions: [Covalent.Transaction], server: RPCServer) -> [TransactionInstance] {
        let transactions: [TransactionInstance] = Covalent.ToNativeTransactionMapper()
            .mapToNativeTransactions(transactions: transactions, server: server)
        return mergeTransactionOperationsIntoSingleTransaction(transactions)
    }

    static func mergeTransactionOperationsIntoSingleTransaction(_ transactions: [TransactionInstance]) -> [TransactionInstance] {
        var results: [TransactionInstance] = .init()
        for each in transactions {
            if let index = results.firstIndex(where: { $0.blockNumber == each.blockNumber }) {
                var found = results[index]
                found.localizedOperations.append(contentsOf: each.localizedOperations)
                results[index] = found
            } else {
                results.append(each)
            }
        }
        return results
    }
}
