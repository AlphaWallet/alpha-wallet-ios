// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import Combine

public class IsErc875Contract {
    private let blockchainProvider: BlockchainProvider

    public init(blockchainProvider: BlockchainProvider) {
        self.blockchainProvider = blockchainProvider
    }

    public func getIsERC875Contract(for contract: AlphaWallet.Address) async throws -> Bool {
        try await blockchainProvider.call(Erc875IsStormBirdContractMethodCall(contract: contract))
    }
}
