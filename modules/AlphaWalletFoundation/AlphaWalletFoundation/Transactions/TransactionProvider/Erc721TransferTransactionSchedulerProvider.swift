//
//  Erc721TransferTransactionSchedulerProvider.swift
//  AlphaWalletFoundation
//
//  Created by Vladyslav Shepitko on 08.03.2023.
//

import Foundation
import Combine
import CombineExt
import AlphaWalletCore

protocol Erc721TransferTransactionSchedulerDelegate: AnyObject {
    func didReceiveResponse(_ response: Result<[TransactionInstance], PromiseError>, in provider: Erc721TransferTransactionSchedulerProvider)
}

/// Newly added transactions provider, performs fetching transaction from frist page until it find some of latest existed stored transaction. Once transaction has found the cycle starts from 0 page again
final class Erc721TransferTransactionSchedulerProvider: SchedulerProvider {
    private let session: WalletSession
    private let networking: ApiNetworking
    private var storage: TransactionsPaginationStorage
    private let defaultPagination: TransactionsPagination

    let interval: TimeInterval
    var name: String { "Erc721TransferTransactionSchedulerProvider" }
    var operation: AnyPublisher<Void, PromiseError> {
        return fetchPublisher()
    }

    weak var delegate: Erc721TransferTransactionSchedulerDelegate?

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
            .transactionsPagination(server: session.server, fetchType: .erc721) ?? defaultPagination

        return networking
            .erc721TokenTransferTransactions(walletAddress: session.account.address, pagination: pagination)
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
            fetchType: .erc721,
            server: session.server)

        delegate?.didReceiveResponse(.success(response.transactions), in: self)
    }

    private func handle(error: PromiseError) {
        delegate?.didReceiveResponse(.failure(error), in: self)
    }
}
