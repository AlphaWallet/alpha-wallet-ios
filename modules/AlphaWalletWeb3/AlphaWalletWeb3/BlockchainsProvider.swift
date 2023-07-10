// Copyright © 2023 Stormbird PTE. LTD.

import Combine
import AlphaWalletCore

public protocol BlockchainsProvider {
    var blockchains: AnyPublisher<ServerDictionary<BlockchainCallable>, Never> { get }

    func blockchain(with server: RPCServer) -> BlockchainCallable?

}