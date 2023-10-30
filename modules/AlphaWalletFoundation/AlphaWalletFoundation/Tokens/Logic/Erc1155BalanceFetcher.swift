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
final actor Erc1155BalanceFetcher {
    private let address: AlphaWallet.Address
    private var inFlightTasks: [String: Task<[BigInt: BigUInt], Error>] = [:]
    private let blockchainProvider: BlockchainProvider

    init(address: AlphaWallet.Address, blockchainProvider: BlockchainProvider) {
        self.blockchainProvider = blockchainProvider
        self.address = address
    }

    deinit {
        clear()
    }

    private func setTask(_ task: Task<[BigInt: BigUInt], Error>?, forKey key: String) {
        inFlightTasks[key] = task
    }

    //Do not make non-private and call from another class/type's deinit with await
    private func clear() {
        inFlightTasks.removeAll()
    }

    nonisolated func getErc1155Balance(contract: AlphaWallet.Address, tokenIds: Set<BigInt>) async throws -> [BigInt: BigUInt] {
        let key = "\(contract.eip55String)-\(tokenIds.hashValue)"
        if let task = await inFlightTasks[key] {
            return try await task.value
        } else {
            //tokenIds must be unique (hence arg is a Set) so `Dictionary(uniqueKeysWithValues:)` wouldn't crash
            let task = Task<[BigInt: BigUInt], Error> {
                let result = try await blockchainProvider.callAsync(Erc1155BalanceOfBatchMethodCall(contract: contract, address: address, tokenIds: tokenIds))
                await setTask(nil, forKey: key)
                return result
            }
            await setTask(task, forKey: key)
            return try await task.value
        }
    }
}
