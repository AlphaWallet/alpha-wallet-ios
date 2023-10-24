// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import AlphaWalletWeb3
import AlphaWalletCore

final actor GetContractDecimals {
    private var inFlightTasks: [String: Task<Int, Error>] = [:]
    private let blockchainProvider: BlockchainProvider

    init(blockchainProvider: BlockchainProvider) {
        self.blockchainProvider = blockchainProvider
    }

    private func setTask(_ task: Task<Int, Error>?, forKey key: String) {
        inFlightTasks[key] = task
    }

    nonisolated func getDecimals(for contract: AlphaWallet.Address) async throws -> Int {
        let key = contract.eip55String
        if let task = await inFlightTasks[key] {
            return try await task.value
        } else {
            let task = Task<Int, Error> {
                let result = try await blockchainProvider.callAsync(Erc20DecimalsMethodCall(contract: contract))
                await setTask(nil, forKey: key)
                return result
            }
            await setTask(task, forKey: key)
            return try await task.value
        }
    }
}
