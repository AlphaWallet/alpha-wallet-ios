// Copyright © 2022 Stormbird PTE. LTD.

import Foundation
import Combine

//EIP-5169 https://github.com/ethereum/EIPs/pull/5169
class ScriptUri {
    private let blockchainProvider: BlockchainProvider

    init(blockchainProvider: BlockchainProvider) {
        self.blockchainProvider = blockchainProvider
    }

    func get(forContract contract: AlphaWallet.Address) async throws -> URL{
        try await blockchainProvider.call(Erc721ScriptUriMethodCall(contract: contract))
    }
}


