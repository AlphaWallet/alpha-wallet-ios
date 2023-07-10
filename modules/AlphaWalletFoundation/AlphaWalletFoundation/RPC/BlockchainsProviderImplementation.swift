//
//  BlockchainsProviderImplementation.swift
//  AlphaWalletFoundation
//
//  Created by Vladyslav Shepitko on 17.01.2023.
//

import Foundation
import Combine
import AlphaWalletCore
import AlphaWalletWeb3

public protocol BlockchainFactory {
    func buildBlockchain(server: RPCServer) -> BlockchainProvider
}

public final class BaseBlockchainFactory: BlockchainFactory {
    private let analytics: AnalyticsLogger

    public init(analytics: AnalyticsLogger) {
        self.analytics = analytics
    }

    public func buildBlockchain(server: RPCServer) -> BlockchainProvider {
        return RpcBlockchainProvider(
            server: server,
            analytics: analytics,
            params: .defaultParams(for: server))
    }
}

public class BlockchainsProviderImplementation: BlockchainsProvider {
    private let serversProvider: ServersProvidable
    private let blockchainsSubject: CurrentValueSubject<ServerDictionary<BlockchainProvider>, Never> = .init(.init())
    private let blockchainFactory: BlockchainFactory
    private var cancelable = Set<AnyCancellable>()

    public var blockchains: AnyPublisher<ServerDictionary<BlockchainCallable>, Never> {
        return blockchainsSubject.map { each in
            let backingDict: ServerDictionary<BlockchainCallable> = each.mapValues { $0 as BlockchainCallable }
            return backingDict
        }.eraseToAnyPublisher()
    }

    public func blockchain(with server: RPCServer) -> BlockchainCallable? {
        blockchainsSubject.value[safe: server]
    }

    public init(serversProvider: ServersProvidable,
                blockchainFactory: BlockchainFactory) {

        self.blockchainFactory = blockchainFactory
        self.serversProvider = serversProvider
        start()
    }

    private func start() {
        serversProvider.enabledServersPublisher
            .map { [blockchainsSubject, blockchainFactory] servers -> ServerDictionary<BlockchainProvider> in
                var blockchains: ServerDictionary<BlockchainProvider> = .init()

                for server in servers {
                    if let blockchain = blockchainsSubject.value[safe: server] {
                        blockchains[server] = blockchain
                    } else {
                        blockchains[server] = blockchainFactory.buildBlockchain(server: server)
                    }
                }
                return blockchains
            }.assign(to: \.value, on: blockchainsSubject, ownership: .weak)
            .store(in: &cancelable)
    }
}
