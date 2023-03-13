//
//  NormalTransactionsSchedulerProvider.swift
//  AlphaWalletFoundation
//
//  Created by Vladyslav Shepitko on 07.03.2023.
//

import Foundation
import Combine
import CombineExt
import AlphaWalletCore

protocol NormalTransactionsSchedulerProviderDelegate: AnyObject {
    func didReceiveResponse(_ response: Swift.Result<[TransactionInstance], PromiseError>, in provider: NormalTransactionsSchedulerProvider)
}

/// Newly added transactions provider, performs fetching transaction from frist page until it find some of latest existed stored transaction. Once transaction has found the cycle starts from 0 page again
final class NormalTransactionsSchedulerProvider: SchedulerProvider {
    private let session: WalletSession
    private let networking: ApiNetworking
    private var storage: TransactionsPaginationStorage
    private let defaultPagination: TransactionsPagination

    let interval: TimeInterval
    var name: String { "NormalTransactionsSchedulerProvider" }
    var operation: AnyPublisher<Void, PromiseError> {
        return fetchPublisher()
    }

    weak var delegate: NormalTransactionsSchedulerProviderDelegate?

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
            .transactionsPagination(server: session.server, fetchType: .normal) ?? defaultPagination

        return networking
            .normalTransactions(walletAddress: session.account.address, pagination: pagination, sortOrder: nil)
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
            fetchType: .normal,
            server: session.server)
        
        delegate?.didReceiveResponse(.success(response.transactions), in: self)
    }

    private func handle(error: PromiseError) {
        delegate?.didReceiveResponse(.failure(error), in: self)
    }
}

extension TransactionInstance {

    init(normalTransaction transaction: NormalTransaction, server: RPCServer) {
        self.init(
            id: transaction.hash,
            server: server,
            blockNumber: Int(transaction.blockNumber)!,
            transactionIndex: Int(transaction.transactionIndex)!,
            from: transaction.from,
            to: transaction.to,
            value: transaction.value,
            gas: transaction.gas,
            gasPrice: transaction.gasUsed,
            gasUsed: transaction.gasUsed,
            nonce: transaction.nonce,
            date: Date(timeIntervalSince1970: transaction.timeStamp.doubleValue),
            localizedOperations: [],
            state: .completed,
            isErc20Interaction: true)
    }

    init(erc20TokenTransferTransaction transaction: Erc20TokenTransferTransaction, server: RPCServer) {
        let localizedOperation = LocalizedOperationObjectInstance(
            from: transaction.from,
            to: transaction.to,
            contract: AlphaWallet.Address(uncheckedAgainstNullAddress: transaction.contractAddress),
            type: OperationType.erc20TokenTransfer.rawValue,
            value: transaction.value,
            tokenId: "",
            symbol: transaction.tokenSymbol,
            name: transaction.tokenName,
            decimals: Int(transaction.tokenDecimal)!)

        self.init(
            id: transaction.hash,
            server: server,
            blockNumber: Int(transaction.blockNumber)!,
            transactionIndex: Int(transaction.transactionIndex)!,
            from: transaction.from,
            to: transaction.to,
            value: "0",
            gas: transaction.gas,
            gasPrice: transaction.gasUsed,
            gasUsed: transaction.gasUsed,
            nonce: transaction.nonce,
            date: Date(timeIntervalSince1970: transaction.timeStamp.doubleValue),
            localizedOperations: [localizedOperation],
            state: .completed,
            isErc20Interaction: true)
    }

    init(erc721TokenTransferTransaction transaction: Erc721TokenTransferTransaction, server: RPCServer) {
        let localizedOperation = LocalizedOperationObjectInstance(
            from: transaction.from,
            to: transaction.to,
            contract: AlphaWallet.Address(uncheckedAgainstNullAddress: transaction.contractAddress),
            type: OperationType.erc721TokenTransfer.rawValue,
            value: transaction.value,
            tokenId: transaction.tokenId,
            symbol: transaction.tokenSymbol,
            name: transaction.tokenName,
            decimals: Int(transaction.tokenDecimal)!)

        self.init(
            id: transaction.hash,
            server: server,
            blockNumber: Int(transaction.blockNumber)!,
            transactionIndex: Int(transaction.transactionIndex)!,
            from: transaction.from,
            to: transaction.to,
            value: "0",
            gas: transaction.gas,
            gasPrice: transaction.gasUsed,
            gasUsed: transaction.gasUsed,
            nonce: transaction.nonce,
            date: Date(timeIntervalSince1970: transaction.timeStamp.doubleValue),
            localizedOperations: [localizedOperation],
            state: .completed,
            isErc20Interaction: true)
    }

    init(erc1155TokenTransferTransaction transaction: Erc1155TokenTransferTransaction, server: RPCServer) {

        let localizedOperation = LocalizedOperationObjectInstance(
            from: transaction.from,
            to: transaction.to,
            contract: AlphaWallet.Address(uncheckedAgainstNullAddress: transaction.contractAddress),
            type: OperationType.erc1155TokenTransfer.rawValue,
            //TODO: implement tokenValue
            //tokenValue: transaction.tokenValue
            value: transaction.value,
            tokenId: transaction.tokenId,
            symbol: transaction.tokenSymbol,
            name: transaction.tokenName,
            decimals: Int(transaction.tokenDecimal)!)

        self.init(
            id: transaction.hash,
            server: server,
            blockNumber: Int(transaction.blockNumber)!,
            transactionIndex: Int(transaction.transactionIndex)!,
            from: transaction.from,
            to: transaction.to,
            value: transaction.tokenValue, //FIXME: "0" should be here
            gas: transaction.gas,
            gasPrice: transaction.gasUsed,
            gasUsed: transaction.gasUsed,
            nonce: transaction.nonce,
            date: Date(timeIntervalSince1970: transaction.timeStamp.doubleValue),
            localizedOperations: [localizedOperation],
            state: .completed,
            isErc20Interaction: true)
    }
}
