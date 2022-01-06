//
//  WalletConnectServer2.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 09.11.2021.
//

import Foundation 

protocol WalletConnectServerProviderType {
    var sessionsSubscribable: Subscribable<[AlphaWallet.WalletConnect.Session]> { get }

    func register(service: WalletConnectServerType)
    func connect(url: AlphaWallet.WalletConnect.ConnectionUrl) throws

    func session(forIdentifier identifier: AlphaWallet.WalletConnect.SessionIdentifier) -> AlphaWallet.WalletConnect.Session?

    func updateSession(session: AlphaWallet.WalletConnect.Session, servers: [RPCServer]) throws
    func reconnectSession(session: AlphaWallet.WalletConnect.Session) throws
    func disconnectSession(session: AlphaWallet.WalletConnect.Session) throws
    func disconnectSession(sessions: [NFDSession]) throws
    func hasConnectedSession(session: AlphaWallet.WalletConnect.Session) -> Bool
}

extension WalletConnectServerProviderType {
    var sessions: [AlphaWallet.WalletConnect.Session] {
        return sessionsSubscribable.value ?? []
    }
}

class WalletConnectServerProvider: WalletConnectServerProviderType {

    weak var delegate: WalletConnectServerDelegate?

    var sessionsSubscribable: Subscribable<[AlphaWallet.WalletConnect.Session]> = .init(nil)

    private var services: [WalletConnectServerType] = []

    func register(service: WalletConnectServerType) {
        services.append(service)

        sessionsSubscribable.value = services.compactMap { $0.sessionsSubscribable.value }.flatMap { $0 }
        service.sessionsSubscribable.subscribe { [weak self] _ in
            guard let strongSelf = self else { return }

            strongSelf.sessionsSubscribable.value = strongSelf.services
                .compactMap { $0.sessionsSubscribable.value }
                .flatMap { $0 }
        }
    }

    func session(forIdentifier identifier: AlphaWallet.WalletConnect.SessionIdentifier) -> AlphaWallet.WalletConnect.Session? {
        return services.compactMap {
            $0.session(forIdentifier: identifier)
        }.first
    }

    func connect(url: AlphaWallet.WalletConnect.ConnectionUrl) throws {
        for each in services {
            try each.connect(url: url)
        }
    }

    func updateSession(session: AlphaWallet.WalletConnect.Session, servers: [RPCServer]) throws {
        for each in services {
            try each.updateSession(session: session, servers: servers)
        }
    }

    func reconnectSession(session: AlphaWallet.WalletConnect.Session) throws {
        for each in services {
            try each.reconnectSession(session: session)
        }
    }

    func disconnectSession(sessions: [NFDSession]) throws {
        for each in services {
            try each.disconnectSession(sessions: sessions)
        }
    }

    func disconnectSession(session: AlphaWallet.WalletConnect.Session) throws {
        for each in services {
            try each.disconnectSession(session: session)
        }
    }

    func hasConnectedSession(session: AlphaWallet.WalletConnect.Session) -> Bool {
        return services.contains(where: { $0.hasConnectedSession(session: session) })
    }
}
