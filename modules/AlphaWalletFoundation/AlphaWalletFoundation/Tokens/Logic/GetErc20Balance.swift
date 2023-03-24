// Copyright © 2019 Stormbird PTE. LTD.

import Foundation
import BigInt
import Combine
import AlphaWalletWeb3
import AlphaWalletCore

final actor GetErc20Balance {
    private let blockchainProvider: BlockchainProvider
    private var inFlightTasks: [String: LoaderTask<BigUInt>] = [:]

    init(blockchainProvider: BlockchainProvider) {
        self.blockchainProvider = blockchainProvider
    }

    func getErc20Balance(for address: AlphaWallet.Address, contract: AlphaWallet.Address) async throws -> BigUInt {
        let key = "\(address.eip55String)-\(contract.eip55String)"
        if let status = inFlightTasks[key] {
            switch status {
            case .fetched(let value):
                return value
            case .inProgress(let task):
                return try await task.value
            }
        }

        let task: Task<BigUInt, Error> = Task {
            return try await blockchainProvider.call(Erc20BalanceOfMethodCall(contract: contract, address: address))
        }

        inFlightTasks[key] = .inProgress(task)
        let value = try await task.value
        inFlightTasks[key] = .fetched(value)

        return value
    }
}
