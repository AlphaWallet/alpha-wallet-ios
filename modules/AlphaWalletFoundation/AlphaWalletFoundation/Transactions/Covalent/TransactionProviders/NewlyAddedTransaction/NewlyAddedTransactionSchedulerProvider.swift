//
//  NewlyAddedTransactionSchedulerProvider.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 26.04.2022.
//

import Foundation
import Combine
import CombineExt

protocol NewlyAddedTransactionSchedulerProviderDelegate: AnyObject {
    func didReceiveResponse(_ response: Swift.Result<[TransactionInstance], Covalent.CovalentError>, in provider: NewlyAddedTransactionSchedulerProvider)
}

/// Newly added transactions provider, performs fetching transaction from frist page until it find some of latest existed stored transaction. Once transaction has found the cycle starts from 0 page again
final class NewlyAddedTransactionSchedulerProvider: SchedulerProvider {
    private let session: WalletSession
    private let networkService: CovalentNetworkService
    private let fetchNewlyAddedTransactionsQueue: OperationQueue

    var interval: TimeInterval { return Constants.Covalent.newlyAddedTransactionUpdateInterval }
    var name: String { "NewlyAddedTransactionSchedulerProvider" }
    var operation: AnyPublisher<Void, SchedulerError> {
        return fetchNewlyAddedTransactionPublisher()
    }

    weak var delegate: NewlyAddedTransactionSchedulerProviderDelegate?

    init(session: WalletSession, networkService: CovalentNetworkService, fetchNewlyAddedTransactionsQueue: OperationQueue) {
        self.session = session
        self.networkService = networkService
        self.fetchNewlyAddedTransactionsQueue = fetchNewlyAddedTransactionsQueue
    }

    private func fallbackForUnsupportedServer() -> AnyPublisher<Void, SchedulerError> {
        session.config
            .set(covalentLastNewestPage: session.server, wallet: session.account, page: nil)

        delegate?.didReceiveResponse(.success([]), in: self)

        return Just(())
            .setFailureType(to: SchedulerError.self)
            .eraseToAnyPublisher()
    }

    private func fetchNewlyAddedTransactionPublisher() -> AnyPublisher<Void, SchedulerError> {
        let lastPage = session.config
            .covalentLastNewestPage(server: session.server, wallet: session.account)
            .flatMap { $0 + 1 }

        guard CovalentNetworkService.isSupport(server: session.server) else {
            return fallbackForUnsupportedServer()
        }

        return networkService
            .transactions(page: lastPage, pageSize: Constants.Covalent.newlyAddedTransactionsPerPage)
            .retry(times: 3)
            .subscribe(on: fetchNewlyAddedTransactionsQueue)
            .handleEvents(receiveOutput: { [weak self] response in
                self?.didReceiveValue(response: response)
            }, receiveCompletion: { [weak self] result in
                guard case .failure(let e) = result else { return }
                self?.didReceiveError(error: e)
            })
            .mapToVoid()
            .mapError { SchedulerError.covalentError($0) }
            .eraseToAnyPublisher()
    }

    private func didReceiveValue(response: Covalent.TransactionsResponse) {
        let transactions = Covalent.ToNativeTransactionMapper
            .mapCovalentToNativeTransaction(transactions: response.data.transactions, server: session.server)
        let page = response.data.pagination.pageNumber

        session.config
            .set(covalentLastNewestPage: session.server, wallet: session.account, page: page)

        delegate?.didReceiveResponse(.success(transactions), in: self)
    }

    private func didReceiveError(error: Covalent.CovalentError) {
        delegate?.didReceiveResponse(.failure(error), in: self)
    }
}

extension Config {

    private static func covalentLastNewestPageKey(server: RPCServer, wallet: Wallet) -> String {
        return "covalentLastNewestPage-\(wallet.address)-\(server.chainID)"
    }

    func covalentLastNewestPage(server: RPCServer, wallet: Wallet) -> Int? {
        let key = Config.covalentLastNewestPageKey(server: server, wallet: wallet)
        return defaults.value(forKey: key) as? Int
    }

    func set(covalentLastNewestPage server: RPCServer, wallet: Wallet, page: Int?) {
        let key = Config.covalentLastNewestPageKey(server: server, wallet: wallet)
        defaults.set(page, forKey: key)
    }
}

extension CovalentNetworkService {
    static func isSupport(server: RPCServer) -> Bool {
        switch server.serverWithEnhancedSupport {
        case .klaytnCypress:
            return true
        case .main, .xDai, .polygon, .binance_smart_chain, .heco, .rinkeby, .arbitrum, .klaytnBaobabTestnet, nil:
            return false
        }
    }
}
