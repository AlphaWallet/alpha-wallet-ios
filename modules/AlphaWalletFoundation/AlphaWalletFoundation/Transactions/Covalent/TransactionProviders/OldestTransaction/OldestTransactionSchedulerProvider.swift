//
//  OldestTransactionSchedulerProvider.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 26.04.2022.
//

import Foundation
import Combine

protocol OldestTransactionSchedulerProviderDelegate: AnyObject {
    func didReceiveResponse(_ response: Swift.Result<[TransactionInstance], Covalent.CovalentError>, in provider: OldestTransactionSchedulerProvider)
}

final class OldestTransactionSchedulerProvider: SchedulerProvider {
    private let provider: Covalent.NetworkProvider = .init()
    private let session: WalletSession
    private let fetchLatestTransactionsQueue: OperationQueue
    //NOTE: additional flag to determine whether call is on apps launch. We want to fetch tsx for latest page, as prev requests might be ended with error.
    //reset only when receive success.
    private var isInitialCall: Bool = true

    var interval: TimeInterval { Constants.Covalent.oldestTransactionUpdateInterval }
    var name: String { "OldestTransactionSchedulerProvider" }
    var operation: AnyPublisher<Void, SchedulerError> {
        return fetchOldestTransactionPublisher()
    }

    weak var delegate: OldestTransactionSchedulerProviderDelegate?

    init(session: WalletSession, fetchLatestTransactionsQueue: OperationQueue) {
        self.session = session
        self.fetchLatestTransactionsQueue = fetchLatestTransactionsQueue
    }

    private func fallbackForUnsupportedServer() -> AnyPublisher<Void, SchedulerError> {
        delegate?.didReceiveResponse(.success([]), in: self)
        session.config.set(covalentOldestPageForServer: session.server, wallet: session.account, page: nil)

        return .just(())
    }

    private func didReceiveValue(_ response: Covalent.TransactionsResponse) {
        let transactions = Covalent.ToNativeTransactionMapper
            .mapCovalentToNativeTransaction(transactions: response.data.transactions, server: session.server)
        let page = response.data.pagination.pageNumber

        delegate?.didReceiveResponse(.success(transactions), in: self)
        session.config.set(covalentOldestPageForServer: session.server, wallet: session.account, page: page)
        isInitialCall = false
    }

    private func didReceiveError(_ e: Covalent.CovalentError) {
        delegate?.didReceiveResponse(.failure(e), in: self)
    }

    private func fetchOldestTransactionPublisher() -> AnyPublisher<Void, SchedulerError> {
        let lastPage = session.config
            .covalentOldestPage(server: session.server, wallet: session.account)
            .flatMap { isInitialCall ? $0 : $0 + 1 }

        guard Covalent.NetworkProvider.isSupport(server: session.server) else {
            return fallbackForUnsupportedServer()
        }

        return provider
            .transactions(walletAddress: session.account.address, server: session.server, page: lastPage, pageSize: Constants.Covalent.oldestAddedTransactionsPerPage)
            .retry(times: 3)
            .subscribe(on: fetchLatestTransactionsQueue)
            .handleEvents(receiveOutput: { [weak self] response in
                self?.didReceiveValue(response)
            }, receiveCompletion: { [weak self] result in
                guard case .failure(let e) = result else { return }
                self?.didReceiveError(e)
            })
            .mapToVoid()
            .mapError { SchedulerError.covalentError($0) }
            .eraseToAnyPublisher()
    }
}

fileprivate extension Config {

    private static func covalentOldestPageKey(server: RPCServer, wallet: Wallet) -> String {
        return "covalentOldestPage-\(wallet.address)-\(server.chainID)"
    }

    private static func hasInvalidatedPageKey(server: RPCServer, wallet: Wallet) -> String {
        return "hasInvalidatedPage-\(wallet.address)-\(server.chainID)"
    }

    func covalentOldestPage(server: RPCServer, wallet: Wallet) -> Int? {
        let key = Config.covalentOldestPageKey(server: server, wallet: wallet)
        return defaults.value(forKey: key) as? Int
    }

    func set(covalentOldestPageForServer server: RPCServer, wallet: Wallet, page: Int?) {
        let key = Config.covalentOldestPageKey(server: server, wallet: wallet)
        defaults.set(page, forKey: key)
    }

    func hasInvalidatedPage(server: RPCServer, wallet: Wallet) -> Bool {
        let key = Config.hasInvalidatedPageKey(server: server, wallet: wallet)
        return defaults.value(forKey: key) as? Bool ?? false
    }

    func set(hasInvalidatedPage server: RPCServer, wallet: Wallet) {
        let key = Config.hasInvalidatedPageKey(server: server, wallet: wallet)
        defaults.set(true, forKey: key)
    }
}
