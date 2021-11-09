//
//  WalletConnectSession.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 02.07.2020.
//

import Foundation

enum WalletConnectError: Error {
    case connectionInvalid
    case invalidWCURL
    case callbackIdMissing
    case sessionMissing
    case connect(WalletConnectV1URL)
    case request(AlphaWallet.WalletConnect.Request.AnyError)
    case unsupported
}

protocol WalletConnectResponder {
    func fulfill(_ callback: AlphaWallet.WalletConnect.Callback, request: AlphaWallet.WalletConnect.Session.Request) throws
    func reject(_ request: AlphaWallet.WalletConnect.Session.Request)
}

protocol UpdateableSessionServerType: class {
    func updateSession(session: AlphaWallet.WalletConnect.Session, servers: [RPCServer]) throws
}

protocol ReconnectableSessionServerType: class {
    func reconnectSession(session: AlphaWallet.WalletConnect.Session) throws
}

protocol WalletConnectServerType: WalletConnectResponder, UpdateableSessionServerType {
    var sessionsSubscribable: Subscribable<[AlphaWallet.WalletConnect.Session]> { get }
    var delegate: WalletConnectServerDelegate? { get set }

    func connect(url: AlphaWallet.WalletConnect.ConnectionUrl) throws
    func session(forIdentifier identifier: AlphaWallet.WalletConnect.SessionIdentifier) -> AlphaWallet.WalletConnect.Session?
    
    func reconnectSession(session: AlphaWallet.WalletConnect.Session) throws
    func disconnectSession(session: AlphaWallet.WalletConnect.Session) throws
    func disconnectSession(sessions: [NFDSession]) throws
    func hasConnectedSession(session: AlphaWallet.WalletConnect.Session) -> Bool
}

protocol WalletConnectServerDelegate: AnyObject {
    func server(_ server: WalletConnectServerType, didConnect session: AlphaWallet.WalletConnect.Session)
    func server(_ server: WalletConnectServerType, shouldConnectFor sessionProposal: AlphaWallet.WalletConnect.SessionProposal, completion: @escaping (AlphaWallet.WalletConnect.SessionProposalResponse) -> Void)
    func server(_ server: WalletConnectServerType, action: AlphaWallet.WalletConnect.Action, request: AlphaWallet.WalletConnect.Session.Request, session: AlphaWallet.WalletConnect.Session)
    func server(_ server: WalletConnectServerType, didFail error: Error)
    func server(_ server: WalletConnectServerType, tookTooLongToConnectToUrl url: AlphaWallet.WalletConnect.ConnectionUrl)
}
