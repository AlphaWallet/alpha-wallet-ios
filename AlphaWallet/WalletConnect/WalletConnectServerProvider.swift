//
//  WalletConnectServer2.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 09.11.2021.
//

import Foundation
import Combine
import CombineExt
import AlphaWalletFoundation

protocol WalletConnectServerProviderType: WalletConnectResponder {
    var sessions: AnyPublisher<[AlphaWallet.WalletConnect.Session], Never> { get }

    func register(service: WalletConnectServer)
    func connect(url: AlphaWallet.WalletConnect.ConnectionUrl) throws

    func session(for topicOrUrl: AlphaWallet.WalletConnect.TopicOrUrl) -> AlphaWallet.WalletConnect.Session?

    func update(_ topicOrUrl: AlphaWallet.WalletConnect.TopicOrUrl, servers: [RPCServer]) throws
    func reconnect(_ topicOrUrl: AlphaWallet.WalletConnect.TopicOrUrl) throws
    func disconnect(_ topicOrUrl: AlphaWallet.WalletConnect.TopicOrUrl) throws
    func disconnectSession(sessions: [NFDSession]) throws
    func isConnected(_ topicOrUrl: AlphaWallet.WalletConnect.TopicOrUrl) -> Bool
}

class WalletConnectServerProvider: NSObject, WalletConnectServerProviderType {
    weak var delegate: WalletConnectServerDelegate?

    @Published private var services: [WalletConnectServer] = []
    private (set) lazy var sessions: AnyPublisher<[AlphaWallet.WalletConnect.Session], Never> = {
        return $services
            .flatMap { $0.map { $0.sessions }.combineLatest() }
            .map { $0.flatMap { $0 } }
            .eraseToAnyPublisher()
    }()

    func register(service: WalletConnectServer) {
        services.append(service)
    }

    func session(for topicOrUrl: AlphaWallet.WalletConnect.TopicOrUrl) -> AlphaWallet.WalletConnect.Session? {
        return services.compactMap { $0.session(for: topicOrUrl) }.first
    }

    func respond(_ response: AlphaWallet.WalletConnect.Response, request: AlphaWallet.WalletConnect.Session.Request) throws {
        for each in services {
            try each.respond(response, request: request)
        }
    }

    func connect(url: AlphaWallet.WalletConnect.ConnectionUrl) throws {
        for each in services {
            try each.connect(url: url)
        }
    }

    func update(_ topicOrUrl: AlphaWallet.WalletConnect.TopicOrUrl, servers: [RPCServer]) throws {
        for each in services {
            try each.update(topicOrUrl, servers: servers)
        }
    }

    func reconnect(_ topicOrUrl: AlphaWallet.WalletConnect.TopicOrUrl) throws {
        for each in services {
            try each.reconnect(topicOrUrl)
        }
    }

    func disconnectSession(sessions: [NFDSession]) throws {
        for each in services {
            try each.disconnectSession(sessions: sessions)
        }
    }

    func disconnect(_ topicOrUrl: AlphaWallet.WalletConnect.TopicOrUrl) throws {
        for each in services {
            try each.disconnect(topicOrUrl)
        }
    }

    func isConnected(_ topicOrUrl: AlphaWallet.WalletConnect.TopicOrUrl) -> Bool {
        return services.contains(where: { $0.isConnected(topicOrUrl) })
    }
}
