// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import AlphaWalletWeb3
import AlphaWalletCore

final actor GetContractName {
    private let blockchainProvider: BlockchainProvider
    private var inFlightTasks: [String: Task<String, Error>] = [:]

    init(blockchainProvider: BlockchainProvider) {
        self.blockchainProvider = blockchainProvider
    }

    private func setTask(_ task: Task<String, Error>?, forKey key: String) {
        inFlightTasks[key] = task
    }

    nonisolated func getName(for contract: AlphaWallet.Address) async throws -> String {
        let key = contract.eip55String
        if let task = await inFlightTasks[key] {
            return try await task.value
        } else {
            let task = Task<String, Error> {
                let result = try await blockchainProvider.callAsync(Erc20NameMethodCall(contract: contract))
                await setTask(nil, forKey: key)
                return result
            }
            await setTask(task, forKey: key)
            return try await task.value
        }
    }
}
