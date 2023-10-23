// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import AlphaWalletWeb3
import AlphaWalletCore

final class GetContractDecimals {
    private var inFlightPromises: [String: Task<Int, Error>] = [:]

    private let blockchainProvider: BlockchainProvider

    init(blockchainProvider: BlockchainProvider) {
        self.blockchainProvider = blockchainProvider
    }

    func getDecimals(for contract: AlphaWallet.Address) async throws -> Int {
        return try await Task { @MainActor in
            let key = contract.eip55String
            if let promise = inFlightPromises[key] {
                return try await promise.value
            } else {
                let promise = Task<Int, Error> {
                    let result = try await blockchainProvider.callAsync(Erc20DecimalsMethodCall(contract: contract))
                    inFlightPromises[key] = nil
                    return result
                }
                inFlightPromises[key] = promise
                return try await promise.value
            }
        }.value
    }
}
