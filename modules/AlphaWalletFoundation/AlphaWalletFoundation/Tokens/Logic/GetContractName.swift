// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import AlphaWalletWeb3
import AlphaWalletCore

final class GetContractName {
    private let blockchainProvider: BlockchainProvider
    private var inFlightPromises: [String: Task<String, Error>] = [:]

    init(blockchainProvider: BlockchainProvider) {
        self.blockchainProvider = blockchainProvider
    }

    func getName(for contract: AlphaWallet.Address) async throws -> String {
        return try await Task { @MainActor in
            let key = contract.eip55String
            if let promise = inFlightPromises[key] {
                return try await promise.value
            } else {
                let promise = Task<String, Error> {
                    let result = try await blockchainProvider.callAsync(Erc20NameMethodCall(contract: contract))
                    inFlightPromises[key] = nil
                    return result
                }
                inFlightPromises[key] = promise
                return try await promise.value
            }
        }.value
    }
}
