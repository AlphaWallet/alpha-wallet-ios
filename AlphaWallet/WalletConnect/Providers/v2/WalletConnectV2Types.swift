//
//  WalletConnectV2Types.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 11.11.2021.
//

import Foundation
import Auth
import WalletConnectSign
import AlphaWalletFoundation

typealias SessionNamespace = WalletConnectSign.SessionNamespace
typealias Blockchain = WalletConnectSign.Blockchain
typealias CAIP10Account = WalletConnectSign.Account

struct WalletConnectV2Session: Codable {
    private (set) var namespaces: [String: SessionNamespace]
    let expiryDate: Date
    var requester: DAppRequester { .init(title: dapp.name, url: URL(string: dapp.url)) }
    let dapp: WalletConnectSign.AppMetadata
    let topicOrUrl: AlphaWallet.WalletConnect.TopicOrUrl

    var servers: [RPCServer] {
        let blockchains = Set(namespaces.values.flatMap { n in n.accounts.map { $0.blockchain.absoluteString } })
        return RPCServer.decodeEip155Array(values: blockchains)
    }

    init(session: WalletConnectSign.Session) {
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

    init(appMetadata metadata: WalletConnectSign.AppMetadata) {
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

typealias WalletConnectV2Request = WalletConnectSign.Request

extension WalletConnectV2Request {
    var rpcServer: RPCServer? { Eip155UrlCoder.decodeRpc(from: chainId.absoluteString) }
}

typealias WalletConnectAuthRequest = AuthRequest