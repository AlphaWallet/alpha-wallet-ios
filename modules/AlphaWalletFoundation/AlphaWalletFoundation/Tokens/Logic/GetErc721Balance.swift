//
// Created by James Sangalli on 14/7/18.
// Copyright © 2018 Stormbird PTE. LTD.
//

import Foundation
import BigInt
import Combine
import AlphaWalletCore

final actor GetErc721Balance {
    private var inFlightTasks: [String: LoaderTask<[String]>] = [:]
    private let blockchainProvider: BlockchainProvider

    init(blockchainProvider: BlockchainProvider) {
        self.blockchainProvider = blockchainProvider
    }

    func getErc721TokenBalance(for address: AlphaWallet.Address, contract: AlphaWallet.Address) async throws -> [String] {
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
            return try await blockchainProvider.call(Erc721BalanceOfMethodCall(contract: contract, address: address))
        }

        inFlightTasks[key] = .inProgress(task)
        let value = try await task.value
        inFlightTasks[key] = .fetched(value)

        return value
    }
}
