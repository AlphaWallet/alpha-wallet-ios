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
    
    public var sessions: AnyPublisher<ServerDictionary<WalletSession>, Never> {
        return sessionsSubject.eraseToAnyPublisher()
    }

    public var activeSessions: ServerDictionary<WalletSession> {
        sessionsSubject.value
    }

    public init(config: Config, analytics: AnalyticsLogger) {
        self.config = config
        self.analytics = analytics
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
        cancelable.cancellAll()

        Just(config.enabledServers).merge(with: config.enabledServersPublisher)
            .removeDuplicates()
            .combineLatest(Just(wallet))
            .map { [config, analytics, sessionsSubject] servers, wallet -> ServerDictionary<WalletSession>in
                var sessions: ServerDictionary<WalletSession> = .init()

                for server in servers {
                    if let session = sessionsSubject.value[safe: server] {
                        sessions[server] = session
                    } else {
                        let session = WalletSession(account: wallet, server: server, config: config, analytics: analytics)
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
