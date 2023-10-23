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

    func getErc721ForTicketsTokenBalance(for address: AlphaWallet.Address, contract: AlphaWallet.Address) async throws -> [String] {
        let key = "\(address.eip55String)-\(contract.eip55String)"
        if let task = inFlightTasks[key] {
            return try await task.value
        } else {
            let task = Task<[String], Error> {
                let result = try await blockchainProvider
                        .callAsync(Erc721GetBalancesMethodCall(contract: contract, address: address))
                inFlightTasks[key] = nil
                return result
            }
            inFlightTasks[key] = task
            return try await task.value
        }
    }
}
