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
    private var inFlightPromises: [String: Task<[BigInt: BigUInt], Error>] = [:]
    private let queue = DispatchQueue(label: "org.alphawallet.swift.erc1155BalanceFetcher")
    private let blockchainProvider: BlockchainProvider

    init(address: AlphaWallet.Address, blockchainProvider: BlockchainProvider) {
        self.blockchainProvider = blockchainProvider
        self.address = address
    }

    func clear() {
        inFlightPromises.removeAll()
    }

    func getErc1155Balance(contract: AlphaWallet.Address, tokenIds: Set<BigInt>) async throws -> [BigInt: BigUInt] {
        return try await Task { @MainActor in
            let key = "\(contract.eip55String)-\(tokenIds.hashValue)"
            if let promise = inFlightPromises[key] {
                return try await promise.value
            } else {
                //tokenIds must be unique (hence arg is a Set) so `Dictionary(uniqueKeysWithValues:)` wouldn't crash
                let promise = Task<[BigInt: BigUInt], Error> {
                    let result = try await blockchainProvider.callAsync(Erc1155BalanceOfBatchMethodCall(contract: contract, address: address, tokenIds: tokenIds))
                    inFlightPromises[key] = nil
                    return result
                }
                inFlightPromises[key] = promise
                return try await promise.value
            }
        }.value
    }
}
