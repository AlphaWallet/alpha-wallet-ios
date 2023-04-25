//
//  BlockchainsProvider.swift
//  AlphaWalletFoundation
//
//  Created by Vladyslav Shepitko on 17.01.2023.
//

import Foundation
import Combine

public protocol BlockchainFactory {
    func buildBlockchain(server: RPCServer) -> BlockchainProvider
}

public final class BaseBlockchainFactory: BlockchainFactory {
    private let config: Config
    private let analytics: AnalyticsLogger

    public init(config: Config,
                analytics: AnalyticsLogger) {

        self.config = config
        self.analytics = analytics
    }

    public func buildBlockchain(server: RPCServer) -> BlockchainProvider {
        return RpcBlockchainProvider(
            server: server,
            analytics: analytics,
            params: .defaultParams(for: server))
    }
}

public class BlockchainsProvider {
    private let serversProvider: ServersProvidable
    private let blockchainsSubject: CurrentValueSubject<ServerDictionary<BlockchainProvider>, Never> = .init(.init())
    private let blockchainFactory: BlockchainFactory
    private var cancelable = Set<AnyCancellable>()

    public var blockchains: AnyPublisher<ServerDictionary<BlockchainProvider>, Never> {
        return blockchainsSubject.eraseToAnyPublisher()
    }

    public func blockchain(with server: RPCServer) -> BlockchainProvider? {
        blockchainsSubject.value[safe: server]
    }

    public init(serversProvider: ServersProvidable,
                blockchainFactory: BlockchainFactory) {

        self.blockchainFactory = blockchainFactory
        self.serversProvider = serversProvider
    }

    public func start() {
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
