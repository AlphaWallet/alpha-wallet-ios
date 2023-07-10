// Copyright © 2022 Stormbird PTE. LTD.

import Foundation
import Combine
import AlphaWalletAddress
import protocol AlphaWalletWeb3.BlockchainCallable
import struct AlphaWalletWeb3.Erc721ScriptUriMethodCall
import APIKit

//EIP-5169 https://github.com/ethereum/EIPs/pull/5169
class ScriptUri {
    private let blockchainProvider: BlockchainCallable

    init(blockchainProvider: BlockchainCallable) {
        self.blockchainProvider = blockchainProvider
    }

    func get(forContract contract: AlphaWallet.Address) -> AnyPublisher<URL, SessionTaskError> {
        blockchainProvider.call(Erc721ScriptUriMethodCall(contract: contract))
    }
}
