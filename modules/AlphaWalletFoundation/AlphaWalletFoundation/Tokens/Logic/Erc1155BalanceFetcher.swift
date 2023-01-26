// Copyright © 2021 Stormbird PTE. LTD.

import Foundation
import BigInt
import AlphaWalletWeb3
import Combine

///Fetching ERC1155 tokens in 2 steps:
///
///A. Fetch known contracts and tokenIds owned (now or previously) for each, writing them to JSON. tokenIds are never removed (so we can easily discover their balance is 0 in the next step)
///B. Fetch balance for each tokenId owned (now or previously. For the latter value would be 0)
///
///This class performs (B)
final class Erc1155BalanceFetcher {
    private let address: AlphaWallet.Address
    private var inFlightPromises: [String: AnyPublisher<[BigInt: BigUInt], SessionTaskError>] = [:]
    private let queue = DispatchQueue(label: "org.alphawallet.swift.erc1155BalanceFetcher")
    private let blockchainProvider: BlockchainProvider

    init(address: AlphaWallet.Address, blockchainProvider: BlockchainProvider) {
        self.blockchainProvider = blockchainProvider
        self.address = address
    }

    func getErc1155Balance(contract: AlphaWallet.Address, tokenIds: Set<BigInt>) -> AnyPublisher<[BigInt: BigUInt], SessionTaskError> {
        return Just(contract)
            .receive(on: queue)
            .setFailureType(to: SessionTaskError.self)
            .flatMap { [weak self, queue, address, blockchainProvider] contract -> AnyPublisher<[BigInt: BigUInt], SessionTaskError> in
                let key = "\(contract.eip55String)-\(tokenIds.hashValue)"

                if let promise = self?.inFlightPromises[key] {
                    return promise
                } else {
                    //tokenIds must be unique (hence arg is a Set) so `Dictionary(uniqueKeysWithValues:)` wouldn't crash
                    let promise = blockchainProvider
                        .call(Erc1155BalanceOfBatchMethodCall(contract: contract, address: address, tokenIds: tokenIds))
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
