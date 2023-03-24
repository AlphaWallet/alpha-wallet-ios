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
    private var inFlightTasks: [String: LoaderTask<[BigInt: BigUInt]>] = [:]
    private let blockchainProvider: BlockchainProvider

    init(address: AlphaWallet.Address, blockchainProvider: BlockchainProvider) {
        self.blockchainProvider = blockchainProvider
        self.address = address
    }

    func getErc1155Balance(contract: AlphaWallet.Address, tokenIds: Set<BigInt>) async throws -> [BigInt: BigUInt] {
        let key = "\(contract.eip55String)-\(tokenIds.hashValue)"
        if let status = inFlightTasks[key] {
            switch status {
            case .fetched(let value):
                return value
            case .inProgress(let task):
                return try await task.value
            }
        }

        let task: Task<[BigInt: BigUInt], Error> = Task {
            try await blockchainProvider.call(Erc1155BalanceOfBatchMethodCall(contract: contract, address: address, tokenIds: tokenIds))
        }

        inFlightTasks[key] = .inProgress(task)
        let value = try await task.value
        inFlightTasks[key] = .fetched(value)

        return value
    }
}
