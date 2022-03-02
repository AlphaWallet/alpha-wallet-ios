//
//  WalletConnectSession.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 02.07.2020.
//

import Foundation

enum WalletConnectError: Error {
    case callbackIdMissing
    case connectionFailure(WalletConnectV1URL)
}

protocol WalletConnectResponder {
    func respond(_ response: AlphaWallet.WalletConnect.Response, request: AlphaWallet.WalletConnect.Session.Request) throws
}

protocol WalletConnectServer: WalletConnectResponder {
    var sessionsSubscribable: Subscribable<[AlphaWallet.WalletConnect.Session]> { get }
    var delegate: WalletConnectServerDelegate? { get set }

    func connect(url: AlphaWallet.WalletConnect.ConnectionUrl) throws
    func session(forIdentifier identifier: AlphaWallet.WalletConnect.SessionIdentifier) -> AlphaWallet.WalletConnect.Session?
    func reconnectSession(session: AlphaWallet.WalletConnect.Session) throws
    func updateSession(session: AlphaWallet.WalletConnect.Session, servers: [RPCServer]) throws
    func disconnectSession(session: AlphaWallet.WalletConnect.Session) throws
    func disconnectSession(sessions: [NFDSession]) throws
    func hasConnectedSession(session: AlphaWallet.WalletConnect.Session) -> Bool
}

protocol WalletConnectServerDelegate: AnyObject {
    func server(_ server: WalletConnectServer, didConnect session: AlphaWallet.WalletConnect.Session)
    func server(_ server: WalletConnectServer, shouldConnectFor sessionProposal: AlphaWallet.WalletConnect.SessionProposal, completion: @escaping (AlphaWallet.WalletConnect.SessionProposalResponse) -> Void)
    func server(_ server: WalletConnectServer, action: AlphaWallet.WalletConnect.Action, request: AlphaWallet.WalletConnect.Session.Request, session: AlphaWallet.WalletConnect.Session)
    func server(_ server: WalletConnectServer, didFail error: Error)
    func server(_ server: WalletConnectServer, tookTooLongToConnectToUrl url: AlphaWallet.WalletConnect.ConnectionUrl)
}
