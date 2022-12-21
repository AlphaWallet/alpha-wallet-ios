//
//  SessionsProvider.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 08.07.2022.
//

import Foundation
import Combine

open class SessionsProvider {
    private let sessionsSubject: CurrentValueSubject<ServerDictionary<WalletSession>, Never> = .init(.init())
    private let config: Config
    private var cancelable = Set<AnyCancellable>()
    private let analytics: AnalyticsLogger
    private let rpcApiProvider: RpcApiProvider
    
    public var sessions: AnyPublisher<ServerDictionary<WalletSession>, Never> {
        return sessionsSubject.eraseToAnyPublisher()
    }

    public var activeSessions: ServerDictionary<WalletSession> {
        sessionsSubject.value
    }

    public init(config: Config, analytics: AnalyticsLogger, rpcApiProvider: RpcApiProvider) {
        self.config = config
        self.analytics = analytics
        self.rpcApiProvider = rpcApiProvider
    }

    public func set(activeSessions: ServerDictionary<WalletSession>) {
        sessionsSubject.send(activeSessions)
    }

    public func start(sessions: AnyPublisher<ServerDictionary<WalletSession>, Never>) {
        cancelable.cancellAll()

        sessions.assign(to: \.value, on: sessionsSubject)
            .store(in: &cancelable)
    }

    public func start(wallet: Wallet) {
        Just(config.enabledServers)
            .merge(with: config.enabledServersPublisher)//subscribe for servers changing so not active providers can handle changes too
            .removeDuplicates()
            .combineLatest(Just(wallet))
            .map { [config, analytics, sessionsSubject, rpcApiProvider] servers, wallet -> ServerDictionary<WalletSession>in
                var sessions: ServerDictionary<WalletSession> = .init()

                for server in servers {
                    if let session = sessionsSubject.value[safe: server] {
                        sessions[server] = session
                    } else {
                        let nodeApiProvider: NodeApiProvider
                        switch server.rpcSource(config: config) {
                        case .http(let rpcHttpParams, let privateNetworkParams):
                            let rpcNodeApiProvider = NodeRpcApiProvider(
                                rpcApiProvider: rpcApiProvider,
                                server: server,
                                rpcHttpParams: rpcHttpParams)
                            rpcNodeApiProvider.requestInterceptor = PrivateRpcNodeInterceptor(server: server, privateNetworkParams: privateNetworkParams)
                            nodeApiProvider = rpcNodeApiProvider

                        case .webSocket(let url, let privateNetworkParams):
                            nodeApiProvider = WebSocketNodeApiProvider(url: url)
                        }

                        let blockchainProvider: BlockchainProvider = RpcBlockchainProvider(
                            server: server,
                            account: wallet,
                            nodeApiProvider: nodeApiProvider,
                            analytics: analytics,
                            params: .defaultParams(for: server))

                        let session = WalletSession(
                            account: wallet,
                            server: server,
                            config: config,
                            analytics: analytics,
                            blockchainProvider: blockchainProvider)
                        
                        sessions[server] = session
                    }
                }
                return sessions
            }.assign(to: \.value, on: sessionsSubject, ownership: .weak)
            .store(in: &cancelable)
    }

    public func session(for server: RPCServer) -> WalletSession? {
        sessionsSubject.value[safe: server]
    }
}
