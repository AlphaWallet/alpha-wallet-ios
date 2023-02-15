//
//  WalletConnectV2Storage.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 30.05.2022.
//

import Foundation
import Combine
import WalletConnectSwiftV2
import AlphaWalletCore
import AlphaWalletFoundation

class WalletConnectV2Storage {
    enum WalletConnectStorageError: Error {
        case sessionNotFound
    }

    enum Keys {
        static let storageFileKey = "walletConnectSessions-v2"
    }

    private lazy var storage: Storage<[WalletConnectV2Session]> = .init(fileName: Keys.storageFileKey, defaultValue: [])

    var sessions: AnyPublisher<[WalletConnectV2Session], Never> { storage.publisher }

    func all() -> [WalletConnectV2Session] {
        storage.value
    }
    
    func session(for topicOrUrl: AlphaWallet.WalletConnect.TopicOrUrl) throws -> WalletConnectV2Session {
        let index = try indexOf(topicOrUrl)

        return storage.value[index]
    }

    func remove(for topicOrUrl: AlphaWallet.WalletConnect.TopicOrUrl) {
        guard let index = try? indexOf(topicOrUrl) else { return }
        storage.value.remove(at: index)
    }

    func addOrUpdate(session: WalletConnectSwiftV2.Session) {
        if let index = try? indexOf(.topic(string: session.topic)) {
            storage.value[index].update(namespaces: session.namespaces)
        } else {
            //NOTE: this case shouldn't happend as we passing through connect method and save all needed data
            storage.value.append(.init(session: session))
        }
    }

    func contains(_ topicOrUrl: AlphaWallet.WalletConnect.TopicOrUrl) -> Bool {
        let index = try? indexOf(topicOrUrl)
        return index != nil
    }

    @discardableResult func update(_ topicOrUrl: AlphaWallet.WalletConnect.TopicOrUrl, namespaces: [String: SessionNamespace]) throws -> WalletConnectV2Session {
        let index = try indexOf(topicOrUrl)

        var session = storage.value[index]
        session.update(namespaces: namespaces)
        storage.value[index] = session

        return storage.value[index]
    }

    @discardableResult func update(_ topicOrUrl: AlphaWallet.WalletConnect.TopicOrUrl, servers: [RPCServer]) throws -> WalletConnectV2Session {
        let session = try session(for: topicOrUrl)
        let namespaces = session.namespaces.mapValues { namespace -> SessionNamespace in
            let blockchains = servers.compactMap { server in Blockchain(server.eip155) }
            let accounts = Set(blockchains.flatMap { blockchain in
                namespace.accounts.compactMap { account in Account(blockchain: blockchain, address: account.address) }
            })

            return SessionNamespace(accounts: accounts, methods: namespace.methods, events: namespace.events)
        }

        return try update(topicOrUrl, namespaces: namespaces)
    }

    @discardableResult func update(_ topicOrUrl: AlphaWallet.WalletConnect.TopicOrUrl, accounts: Set<CAIP10Account>) throws -> WalletConnectV2Session {
        let session = try session(for: topicOrUrl)

        let namespaces = session.namespaces.mapValues { SessionNamespace(accounts: accounts, methods: $0.methods, events: $0.events) }

        return try update(topicOrUrl, namespaces: namespaces)
    }

    @discardableResult private func indexOf(_ topicOrUrl: AlphaWallet.WalletConnect.TopicOrUrl) throws -> Int {
        guard let index = storage.value.firstIndex(where: { $0.topicOrUrl == topicOrUrl }) else {
            throw WalletConnectStorageError.sessionNotFound
        }
        return index
    }

}
