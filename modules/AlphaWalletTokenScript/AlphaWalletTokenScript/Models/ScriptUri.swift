// Copyright © 2022 Stormbird PTE. LTD.

import Foundation
import Combine
import AlphaWalletAddress
import AlphaWalletWeb3
import APIKit

//EIP-5169 https://github.com/ethereum/EIPs/pull/5169
class ScriptUri {
    private let blockchainProvider: BlockchainCallable

    init(blockchainProvider: BlockchainCallable) {
        self.blockchainProvider = blockchainProvider
    }

    func get(forContract contract: AlphaWallet.Address) -> AnyPublisher<[URL], SessionTaskError> {
        //EIP-5169 started out as having scriptURI() return `string` then updated to return `string[]`, so we must support both. Ideally we should just call `scriptURI()` once and interpret the results both ways to see which matches, but that needs some changes
        return blockchainProvider.call(ScriptUrisMethodCall(contract: contract))
                .catch { _ in
                    return self.blockchainProvider.call(ScriptUriMethodCall(contract: contract)).map { [$0] }
                }
                .eraseToAnyPublisher()
    }
}
