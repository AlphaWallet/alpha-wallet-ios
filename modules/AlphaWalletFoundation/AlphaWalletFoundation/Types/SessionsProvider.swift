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
    private let blockchainsProvider: BlockchainsProvider
    private let analytics: AnalyticsLogger

    public var sessions: AnyPublisher<ServerDictionary<WalletSession>, Never> {
        return sessionsSubject.eraseToAnyPublisher()
    }

    public var activeSessions: ServerDictionary<WalletSession> {
        sessionsSubject.value
    }

    public init(config: Config, analytics: AnalyticsLogger, blockchainsProvider: BlockchainsProvider) {
        self.config = config
        self.analytics = analytics
        self.blockchainsProvider = blockchainsProvider
    }

    public func start(wallet: Wallet) {
        blockchainsProvider
            .blockchains
            .map { [sessionsSubject, config, analytics] blockchains -> ServerDictionary<WalletSession>in
                var sessions: ServerDictionary<WalletSession> = .init()

                for blockchain in blockchains.values {
                    if let session = sessionsSubject.value[safe: blockchain.server] {
                        sessions[blockchain.server] = session
                    } else {
                        sessions[blockchain.server] = WalletSession(
                            account: wallet,
                            server: blockchain.server,
                            config: config,
                            analytics: analytics,
                            blockchainProvider: blockchain)
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
