// Copyright © 2019 Stormbird PTE. LTD.

import Foundation 
import BigInt
import Combine
import AlphaWalletCore

actor GetErc721ForTicketsBalance {
    private var inFlightTasks: [String: LoaderTask<[String]>] = [:]
    private let blockchainProvider: BlockchainProvider

    init(blockchainProvider: BlockchainProvider) {
        self.blockchainProvider = blockchainProvider
    }

    func getErc721ForTicketsTokenBalance(for address: AlphaWallet.Address, contract: AlphaWallet.Address) async throws -> [String] {
        let key = "\(address.eip55String)-\(contract.eip55String)"
        if let status = inFlightTasks[key] {
            switch status {
            case .fetched(let value):
                return value
            case .inProgress(let task):
                return try await task.value
            }
        }

        let task: Task<[String], Error> = Task {
            return try await blockchainProvider.call(Erc721GetBalancesMethodCall(contract: contract, address: address))
        }

        inFlightTasks[key] = .inProgress(task)
        let value = try await task.value
        inFlightTasks[key] = .fetched(value)

        return value
    }
}
