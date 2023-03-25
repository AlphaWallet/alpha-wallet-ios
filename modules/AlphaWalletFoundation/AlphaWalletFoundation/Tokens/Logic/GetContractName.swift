// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import AlphaWalletWeb3
import AlphaWalletCore
import Combine

final class GetContractName {
    private let blockchainProvider: BlockchainProvider
    private var inFlightPromises: [String: AnyPublisher<String, SessionTaskError>] = [:]
    private let queue = DispatchQueue(label: "org.alphawallet.swift.getContractName")

    init(blockchainProvider: BlockchainProvider) {
        self.blockchainProvider = blockchainProvider
    }

    func getName(for contract: AlphaWallet.Address) -> AnyPublisher<String, SessionTaskError> {
        return Just(contract)
            .receive(on: queue)
            .setFailureType(to: SessionTaskError.self)
            .flatMap { [weak self, queue, blockchainProvider] contract -> AnyPublisher<String, SessionTaskError> in
                let key = contract.eip55String

                if let promise = self?.inFlightPromises[key] {
                    return promise
                } else {
                    let promise = blockchainProvider
                        .call(Erc20NameMethodCall(contract: contract))
                        .receive(on: queue)
                        .handleEvents(receiveCompletion: { _ in self?.inFlightPromises[key] = .none })
                        .share()
                        .eraseToAnyPublisher()

                    self?.inFlightPromises[key] = promise

                    return promise
                }
            }.eraseToAnyPublisher()
    }
}
