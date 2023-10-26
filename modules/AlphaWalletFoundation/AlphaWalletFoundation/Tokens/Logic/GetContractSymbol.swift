// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import AlphaWalletWeb3
import AlphaWalletCore

final actor GetContractSymbol {
    private var inFlightTasks: [String: Task<String, Error>] = [:]
    private let blockchainProvider: BlockchainProvider

    init(blockchainProvider: BlockchainProvider) {
        self.blockchainProvider = blockchainProvider
    }

    private func setTask(_ task: Task<String, Error>?, forKey key: String) {
        inFlightTasks[key] = task
    }

    nonisolated func getSymbol(for contract: AlphaWallet.Address) async throws -> String {
        let key = contract.eip55String
        if let task = await inFlightTasks[key] {
            return try await task.value
        } else {
            let task = Task<String, Error> {
                let result = try await blockchainProvider.callAsync(Erc20SymbolMethodCall(contract: contract))
                await setTask(nil, forKey: key)
                return result
            }
            await setTask(task, forKey: key)
            return try await task.value
        }
    }
}
