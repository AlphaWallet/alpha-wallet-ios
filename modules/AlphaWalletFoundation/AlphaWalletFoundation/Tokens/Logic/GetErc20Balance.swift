// Copyright © 2019 Stormbird PTE. LTD.

import Foundation
import BigInt
import Combine
import AlphaWalletWeb3
import AlphaWalletCore

final actor GetErc20Balance {
    private var inFlightTasks: [String: Task<BigUInt, Error>] = [:]
    private let blockchainProvider: BlockchainProvider

    init(blockchainProvider: BlockchainProvider) {
        self.blockchainProvider = blockchainProvider
    }

    private func setTask(_ task: Task<BigUInt, Error>?, forKey key: String) {
        inFlightTasks[key] = task
    }

    nonisolated func getErc20Balance(for address: AlphaWallet.Address, contract: AlphaWallet.Address) async throws -> BigUInt {
        let key = "\(address.eip55String)-\(contract.eip55String)"
        if let task = await inFlightTasks[key] {
            return try await task.value
        } else {
            let task = Task<BigUInt, Error> {
                let result = try await blockchainProvider.callAsync(Erc20BalanceOfMethodCall(contract: contract, address: address))
                await setTask(nil, forKey: key)
                return result
            }
            await setTask(task, forKey: key)
            return try await task.value
        }
    }
}
