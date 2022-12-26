//
//  SessionsProvider.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 08.07.2022.
//

import Foundation
import Combine

public protocol SessionFactory {
    func buildSession(server: RPCServer, wallet: Wallet) -> WalletSession
}

public final class BaseSessionFactory: SessionFactory {
    private let config: Config
    private let rpcApiProvider: RpcApiProvider
    private let analytics: AnalyticsLogger

    public init(config: Config, rpcApiProvider: RpcApiProvider, analytics: AnalyticsLogger) {
        self.config = config
        self.rpcApiProvider = rpcApiProvider
        self.analytics = analytics
    }

    public func buildSession(server: RPCServer, wallet: Wallet) -> WalletSession {
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
            nodeApiProvider = WebSocketNodeApiProvider(url: url, server: server)
        }

        let blockchainProvider: BlockchainProvider = RpcBlockchainProvider(
            server: server,
            account: wallet,
            nodeApiProvider: nodeApiProvider,
            analytics: analytics,
            params: .defaultParams(for: server))

        return WalletSession(
            account: wallet,
            server: server,
            config: config,
            analytics: analytics,
            blockchainProvider: blockchainProvider)
    }
}

open class SessionsProvider {
    private let sessionsSubject: CurrentValueSubject<ServerDictionary<WalletSession>, Never> = .init(.init())
    private let config: Config
    private var cancelable = Set<AnyCancellable>()
    private let factory: SessionFactory

    public var sessions: AnyPublisher<ServerDictionary<WalletSession>, Never> {
        return sessionsSubject.eraseToAnyPublisher()
    }

    public var activeSessions: ServerDictionary<WalletSession> {
        sessionsSubject.value
    }

    public init(config: Config, factory: SessionFactory) {
        self.config = config
        self.factory = factory
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
            .map { [sessionsSubject, factory] servers, wallet -> ServerDictionary<WalletSession>in
                var sessions: ServerDictionary<WalletSession> = .init()

                for server in servers {
                    if let session = sessionsSubject.value[safe: server] {
                        sessions[server] = session
                    } else {
                        sessions[server] = factory.buildSession(server: server, wallet: wallet)
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
