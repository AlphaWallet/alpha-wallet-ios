// Copyright © 2019 Stormbird PTE. LTD.

import Foundation
import BigInt
import Combine
import AlphaWalletCore
import AlphaWalletWeb3

actor GetErc721ForTicketsBalance {
    private var inFlightTasks: [String: Task<[String], Error>] = [:]
    private let blockchainProvider: BlockchainProvider

    init(blockchainProvider: BlockchainProvider) {
        self.blockchainProvider = blockchainProvider
    }

    private func setTask(_ task: Task<[String], Error>?, forKey key: String) {
        inFlightTasks[key] = task
    }

    nonisolated func getErc721ForTicketsTokenBalance(for address: AlphaWallet.Address, contract: AlphaWallet.Address) async throws -> [String] {
        let key = "\(address.eip55String)-\(contract.eip55String)"
        if let task = await inFlightTasks[key] {
            return try await task.value
        } else {
            let task = Task<[String], Error> {
                let result = try await blockchainProvider
                        .callAsync(Erc721GetBalancesMethodCall(contract: contract, address: address))
                await setTask(nil, forKey: key)
                return result
            }
            await setTask(task, forKey: key)
            return try await task.value
        }
    }
}
