//
//  WalletConnectV2Types.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 11.11.2021.
//

import Foundation
import WalletConnect 

typealias WalletConnectV2URI = WalletConnectURI

struct MultiServerWalletConnectSession: Codable, SessionIdentifiable {
    var dapp: AppMetadata
    private (set) var blockchains: Set<String>
    var methods: Set<String>
    let identifier: AlphaWallet.WalletConnect.SessionIdentifier

    var requester: DAppRequester {
        return .init(title: dapp.name, url: dapp.url.flatMap({ URL(string: $0) }))
    }

    var permissions: Session.Permissions {
        return .init(blockchains: blockchains, methods: methods)
    }

    var servers: [RPCServer] {
        get {
            return RPCServer.decodeEip155Array(values: blockchains)
        }
        set {
            blockchains = Set(newValue.compactMap { $0.eip155 })
        }
    }

    init(session: Session) {
        self.identifier = .topic(string: session.topic)
        self.dapp = session.peer
        self.blockchains = session.permissions.blockchains
        self.methods = session.permissions.methods
    }

    mutating func update(session: Session) {
        self.dapp = session.peer
        self.blockchains = session.permissions.blockchains
        self.methods = session.permissions.methods
    }

    mutating func update(permissions: Session.Permissions) {
        self.blockchains = permissions.blockchains
        self.methods = permissions.methods
    }
}

extension AlphaWallet.WalletConnect.Dapp {

    init(appMetadata metadata: AppMetadata) {
        self.name = metadata.name ?? ""
        self.description = metadata.description
        self.url = metadata.url.flatMap({ URL(string: $0) })!
        self.icons = metadata.icons.flatMap({ $0.compactMap({ URL(string: $0) }) }) ?? []
    }
}

extension AlphaWallet.WalletConnect.Session {

    init(multiServerSession session: MultiServerWalletConnectSession) {
        identifier = session.identifier
        servers = session.servers
        dapp = .init(appMetadata: session.dapp)
        methods = Array(session.methods)
        isMultipleServersEnabled = true
    }
}

enum WalletConnectV2ProviderError: Error {
    case connectionIsAlreadyPending
}

typealias WalletConnectV2Request = Request

extension WalletConnectV2Request {
    var rpcServer: RPCServer? {
        guard let chainId = chainId else { return nil }
        if let server = eip155URLCoder.decodeRPC(from: chainId) {
            return server
        } else if let value = Int(chainId, radix: 10) {
            return RPCServer(chainID: value)
        } else {
            return nil
        }
    }
}
