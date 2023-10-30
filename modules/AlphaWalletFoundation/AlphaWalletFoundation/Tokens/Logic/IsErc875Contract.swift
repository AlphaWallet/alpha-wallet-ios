// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import Combine
import AlphaWalletWeb3

public class IsErc875Contract {
    private let blockchainProvider: BlockchainProvider

    public init(blockchainProvider: BlockchainProvider) {
        self.blockchainProvider = blockchainProvider
    }

    public func getIsERC875Contract(for contract: AlphaWallet.Address) async throws -> Bool {
        let result: SupportsInterfaceMethodCall.Response
        do {
            return try await blockchainProvider.callAsync(Erc875IsStormBirdContractMethodCall(contract: contract))
        } catch let error as Web3Error {
            if isNodeErrorExecutionReverted(error: error) {
                result = false
            } else {
                throw error
            }
        }
        return result
    }
}
