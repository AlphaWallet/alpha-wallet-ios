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
        let transporter: RpcRequestTransporter
        //NOTE: batching isn't tested, might not working correctly
        let policy: DispatchPolicy = server.web3SwiftRpcNodeBatchSupportPolicy

        switch server.rpcSource(config: config) {
        case .http(let rpcHttpParams, let privateNetworkParams):
            let httpRpcRequestTransporter = HttpRpcRequestTransporter(
                server: server,
                rpcHttpParams: rpcHttpParams,
                networkService: BaseRpcNetworkService(server: server),
                analytics: analytics)
            httpRpcRequestTransporter.requestInterceptor = PrivateRpcUrlInterceptor(privateNetworkParams: privateNetworkParams)
            transporter = httpRpcRequestTransporter

        case .webSocket(let url, let privateNetworkParams):
            //NOTE: private networks are not supported, implement retry logic
            transporter = WebSocketRpcRequestTransporter(url: url, server: server)
        }

        return RpcBlockchainProvider(
            server: server,
            rpcRequestProvider: BatchSupportableRpcRequestDispatcher(transporter: transporter, policy: policy),
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
