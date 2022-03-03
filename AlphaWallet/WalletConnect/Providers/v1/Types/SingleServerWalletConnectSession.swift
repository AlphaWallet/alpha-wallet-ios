//
//  SingleServerWalletConnectSession.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 09.02.2022.
//

import Foundation
import WalletConnectSwift

struct SingleServerWalletConnectSession: Codable, SessionIdentifiable, Equatable {
    let identifier: AlphaWallet.WalletConnect.SessionIdentifier
    var session: WalletConnectSwift.Session
    var server: RPCServer

    init(session: WalletConnectSwift.Session, server: RPCServer) {
        self.identifier = .url(url: session.url)
        self.session = session
        self.server = server
    }

    mutating func updateSession(_ session: WalletConnectSwift.Session) {
        self.session = session
    }

    static func == (lsh: SingleServerWalletConnectSession, rsh: SingleServerWalletConnectSession) -> Bool {
        return lsh.identifier == rsh.identifier
    }

    static func == (lsh: SingleServerWalletConnectSession, rsh: WalletConnectV1URL) -> Bool {
        return lsh.identifier.description == rsh.absoluteString
    }

    static func == (lsh: SingleServerWalletConnectSession, rsh: AlphaWallet.WalletConnect.Session) -> Bool {
        return lsh.identifier.description == rsh.identifier.description
    }

    static func == (lsh: SingleServerWalletConnectSession, rsh: Session) -> Bool {
        return lsh.identifier.description == rsh.url.absoluteString
    }
}
