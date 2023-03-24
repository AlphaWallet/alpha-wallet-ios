// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import PromiseKit
import AlphaWalletWeb3
import AlphaWalletCore
import Combine

final actor GetContractSymbol {
    private var inFlightTasks: [String: LoaderTask<String>] = [:]

    private let blockchainProvider: BlockchainProvider

    init(blockchainProvider: BlockchainProvider) {
        self.blockchainProvider = blockchainProvider
    }

    func getSymbol(for contract: AlphaWallet.Address) async throws -> String {
        let key = contract.eip55String
        if let status = inFlightTasks[key] {
            switch status {
            case .fetched(let value):
                return value
            case .inProgress(let task):
                return try await task.value
            }
        }

        let task: Task<String, Error> = Task {
            return try await blockchainProvider.call(Erc20SymbolMethodCall(contract: contract))
        }

        inFlightTasks[key] = .inProgress(task)
        let value = try await task.value
        inFlightTasks[key] = .fetched(value)

        return value
    }
}
