//
//  WalletConnectV1Session.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 09.02.2022.
//

import Foundation
import WalletConnectSwift
import AlphaWalletFoundation

struct WalletConnectV1Session: Codable {
    let topicOrUrl: AlphaWallet.WalletConnect.TopicOrUrl
    let session: WalletConnectSwift.Session
    let namespaces: [String: SessionNamespace]

    var server: RPCServer {
        let blockchains = Set(namespaces.values.flatMap { n in n.accounts.map { $0.blockchain.absoluteString } })
        return RPCServer.decodeEip155Array(values: blockchains).first!
    }

    init(session: WalletConnectSwift.Session, namespaces: [String: SessionNamespace]) {
        self.topicOrUrl = .url(url: .init(url: session.url))
        self.session = session
        self.namespaces = namespaces
    }
}

extension WalletConnectV1Session: Equatable {
    static func == (lsh: WalletConnectV1Session, rsh: WalletConnectV1Session) -> Bool {
        return lsh.topicOrUrl == rsh.topicOrUrl
    }
}
