//
//  Erc20TransferTransactionSchedulerProvider.swift
//  AlphaWalletFoundation
//
//  Created by Vladyslav Shepitko on 08.03.2023.
//

import Foundation
import Combine
import CombineExt
import AlphaWalletCore

protocol Erc20TransferTransactionSchedulerDelegate: AnyObject {
    func didReceiveResponse(_ response: Result<[TransactionInstance], PromiseError>, in provider: Erc20TransferTransactionSchedulerProvider)
}

/// Newly added transactions provider, performs fetching transaction from frist page until it find some of latest existed stored transaction. Once transaction has found the cycle starts from 0 page again
final class Erc20TransferTransactionSchedulerProvider: SchedulerProvider {
    private let session: WalletSession
    private let networking: ApiNetworking
    private var storage: TransactionsPaginationStorage
    private let defaultPagination: TransactionsPagination

    var interval: TimeInterval
    var name: String { "Erc20TransferTransactionSchedulerProvider" }
    var operation: AnyPublisher<Void, PromiseError> {
        return fetchPublisher()
    }

    weak var delegate: Erc20TransferTransactionSchedulerDelegate?

    init(session: WalletSession,
         networking: ApiNetworking,
         defaultPagination: TransactionsPagination,
         interval: TimeInterval,
         storage: TransactionsPaginationStorage) {

        self.interval = interval
        self.defaultPagination = defaultPagination
        self.storage = storage
        self.session = session
        self.networking = networking
    }

    private func fetchPublisher() -> AnyPublisher<Void, PromiseError> {
        let pagination = storage
            .transactionsPagination(server: session.server, fetchType: .erc20) ?? defaultPagination

        return networking
            .erc20TokenTransferTransactions(walletAddress: session.account.address, pagination: pagination)
            .handleEvents(receiveOutput: { [weak self] response in
                self?.handle(response: response)
            }, receiveCompletion: { [weak self] result in
                guard case .failure(let e) = result else { return }
                self?.handle(error: e)
            })
            .mapToVoid()
            .eraseToAnyPublisher()
    }

    private func handle(response: TransactionsResponse<TransactionInstance>) {
        storage.set(
            transactionsPagination: response.pagination,
            fetchType: .erc20,
            server: session.server)

        delegate?.didReceiveResponse(.success(response.transactions), in: self)
    }

    private func handle(error: PromiseError) {
        delegate?.didReceiveResponse(.failure(error), in: self)
    }
}
