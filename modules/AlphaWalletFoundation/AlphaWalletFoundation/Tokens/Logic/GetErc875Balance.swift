// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import Combine
import AlphaWalletCore
import AlphaWalletWeb3

class GetErc875Balance {
    private let queue = DispatchQueue(label: "org.alphawallet.swift.getErc875Balance")
    private var inFlightPublishers: [String: AnyPublisher<[String], SessionTaskError>] = [:]
    private let blockchainProvider: BlockchainProvider

    init(blockchainProvider: BlockchainProvider) {
        self.blockchainProvider = blockchainProvider
    }

    func getErc875TokenBalance(for address: AlphaWallet.Address, contract: AlphaWallet.Address) -> AnyPublisher<[String], SessionTaskError> {
        Just(contract)
            .receive(on: queue)
            .setFailureType(to: SessionTaskError.self)
            .flatMap { [weak self, queue, blockchainProvider] contract -> AnyPublisher<[String], SessionTaskError> in
                let key = "\(address.eip55String)-\(contract.eip55String)"

                if let publisher = self?.inFlightPublishers[key] {
                    return publisher
                } else {
                    let publisher = blockchainProvider
                        .call(Erc875BalanceOfMethodCall(contract: contract, address: address))
                        .receive(on: queue)
                        .handleEvents(receiveCompletion: { _ in self?.inFlightPublishers[key] = .none })
                        .share()
                        .eraseToAnyPublisher()

                    self?.inFlightPublishers[key] = publisher

                    return publisher
                }
            }.eraseToAnyPublisher()
    }
}
