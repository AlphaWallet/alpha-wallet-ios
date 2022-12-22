//
//  WalletConnectV2Types.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 11.11.2021.
//

import Foundation
import WalletConnectSwiftV2
import AlphaWalletFoundation

typealias SessionNamespace = WalletConnectSwiftV2.SessionNamespace
typealias Blockchain = WalletConnectSwiftV2.Blockchain
typealias CAIP10Account = WalletConnectSwiftV2.Account

struct WalletConnectV2Session: Codable {
    private (set) var namespaces: [String: SessionNamespace]
    let expiryDate: Date
    var requester: DAppRequester { .init(title: dapp.name, url: URL(string: dapp.url)) }
    let dapp: WalletConnectSwiftV2.AppMetadata
    let topicOrUrl: AlphaWallet.WalletConnect.TopicOrUrl

    var servers: [RPCServer] {
        let blockchains = Set(namespaces.values.flatMap { n in n.accounts.map { $0.blockchain.absoluteString } })
        return RPCServer.decodeEip155Array(values: blockchains)
    }

    init(session: WalletConnectSwiftV2.Session) {
        topicOrUrl = .topic(string: session.topic)
        dapp = session.peer
        namespaces = session.namespaces
        expiryDate = session.expiryDate
    }

    mutating func update(namespaces _namespaces: [String: SessionNamespace]) {
        namespaces = _namespaces
    } 
}

extension WalletSession {
    var capi10Account: CAIP10Account {
        return CAIP10Account(blockchain: .init(server.eip155)!, address: account.address.eip55String)!
    }
}

extension AlphaWallet.WalletConnect.Dapp {

    init(appMetadata metadata: WalletConnectSwiftV2.AppMetadata) {
        self.name = metadata.name
        self.description = metadata.description
        self.url = URL(string: metadata.url)!
        self.icons = metadata.icons.compactMap({ URL(string: $0) })
    }
}

extension AlphaWallet.WalletConnect.Session {

    init(multiServerSession session: WalletConnectV2Session) {
        topicOrUrl = session.topicOrUrl
        dapp = .init(appMetadata: session.dapp)
        namespaces = session.namespaces
        multipleServersSelection = .enabled
    }
}

typealias WalletConnectV2Request = WalletConnectSwiftV2.Request

extension WalletConnectV2Request {
    var rpcServer: RPCServer? { eip155URLCoder.decodeRPC(from: chainId.absoluteString) }
}
