// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import Combine
import AlphaWalletWeb3
import AlphaWalletCore

final actor GetContractDecimals {
    private var inFlightTasks: [String: LoaderTask<Int>] = [:]
    private let blockchainProvider: BlockchainProvider

    init(blockchainProvider: BlockchainProvider) {
        self.blockchainProvider = blockchainProvider
    }

    func getDecimals(for contract: AlphaWallet.Address) async throws -> Int {
        let key = contract.eip55String
        if let status = inFlightTasks[key] {
            switch status {
            case .fetched(let value):
                return value
            case .inProgress(let task):
                return try await task.value
            }
        }

        let task: Task<Int, Error> = Task {
            return try await blockchainProvider.call(Erc20DecimalsMethodCall(contract: contract))
        }

        inFlightTasks[key] = .inProgress(task)
        let value = try await task.value
        inFlightTasks[key] = .fetched(value)

        return value
    }
}
