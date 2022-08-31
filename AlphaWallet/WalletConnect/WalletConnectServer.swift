//
//  WalletConnectSession.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 02.07.2020.
//

import Foundation
import Combine
import AlphaWalletFoundation

enum WalletConnectError: Error {
    case callbackIdMissing
    case connectionFailure(WalletConnectV1URL)
}

protocol WalletConnectResponder {
    func respond(_ response: AlphaWallet.WalletConnect.Response, request: AlphaWallet.WalletConnect.Session.Request) throws
}

protocol WalletConnectServer: WalletConnectResponder {
    var sessions: AnyPublisher<[AlphaWallet.WalletConnect.Session], Never> { get }

    var delegate: WalletConnectServerDelegate? { get set }

    func connect(url: AlphaWallet.WalletConnect.ConnectionUrl) throws
    func session(for topicOrUrl: AlphaWallet.WalletConnect.TopicOrUrl) -> AlphaWallet.WalletConnect.Session?
    func reconnect(_ topicOrUrl: AlphaWallet.WalletConnect.TopicOrUrl) throws
    func update(_ topicOrUrl: AlphaWallet.WalletConnect.TopicOrUrl, servers: [RPCServer]) throws
    func disconnect(_ topicOrUrl: AlphaWallet.WalletConnect.TopicOrUrl) throws
    func disconnectSession(sessions: [NFDSession]) throws
    func isConnected(_ topicOrUrl: AlphaWallet.WalletConnect.TopicOrUrl) -> Bool
}

protocol WalletConnectServerDelegate: AnyObject {
    func server(_ server: WalletConnectServer, didConnect session: AlphaWallet.WalletConnect.Session)
    func server(_ server: WalletConnectServer, shouldConnectFor proposal: AlphaWallet.WalletConnect.Proposal, completion: @escaping (AlphaWallet.WalletConnect.ProposalResponse) -> Void)
    func server(_ server: WalletConnectServer, action: AlphaWallet.WalletConnect.Action, request: AlphaWallet.WalletConnect.Session.Request, session: AlphaWallet.WalletConnect.Session)
    func server(_ server: WalletConnectServer, didFail error: Error)
    func server(_ server: WalletConnectServer, tookTooLongToConnectToUrl url: AlphaWallet.WalletConnect.ConnectionUrl)
}
