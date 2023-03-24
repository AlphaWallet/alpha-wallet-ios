// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import PromiseKit
import AlphaWalletCore
import Combine

actor GetErc875Balance {
    private let blockchainProvider: BlockchainProvider
    private var inFlightTasks: [String: LoaderTask<[String]>] = [:]

    init(blockchainProvider: BlockchainProvider) {
        self.blockchainProvider = blockchainProvider
    }

    func getErc875TokenBalance(for address: AlphaWallet.Address, contract: AlphaWallet.Address) async throws -> [String] {
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
            return try await blockchainProvider.call(Erc875BalanceOfMethodCall(contract: contract, address: address))
        }

        inFlightTasks[key] = .inProgress(task)
        let value = try await task.value
        inFlightTasks[key] = .fetched(value)

        return value
    }
}
