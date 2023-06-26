//
//  WalletConnectSession.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 02.07.2020.
//

import Foundation
import Combine
import AlphaWalletFoundation
import PromiseKit
import AlphaWalletCore

enum WalletConnectError: LocalizedError {
    case onlyForWatchWallet(address: AlphaWallet.Address)
    case walletsNotFound(addresses: [AlphaWallet.Address])
    case callbackIdMissing
    case connectionFailure(WalletConnectV1URL)
    case cancelled
    case delayedOperation
    case `internal`(JsonRpcError)

    init(error: PromiseError) {
        if let e = error.embedded as? JsonRpcError, e == .requestRejected {
            self = .cancelled
        } else if case PMKError.cancelled = error.embedded {
            self = .cancelled
        } else if let error = error.embedded as? JsonRpcError {
            self = .internal(error)
        } else if let error = error.embedded as? WalletConnectError {
            self = error
        } else {
            self = .internal(.init(code: -32051, message: error.embedded.localizedDescription))
        }
    }

    var asJsonRpcError: JsonRpcError {
        switch self {
        case .internal(let error):
            return error
        case .delayedOperation, .cancelled, .walletsNotFound, .onlyForWatchWallet, .callbackIdMissing, .connectionFailure:
            return .requestRejected
        }
    }

    var errorDescription: String? {
        switch self {
        case .internal(let error):
            return error.message
        case .callbackIdMissing, .connectionFailure:
            return R.string.localizable.walletConnectFailureTitle()
        case .onlyForWatchWallet:
            return R.string.localizable.walletConnectFailureMustNotBeWatchedWallet()
        case .walletsNotFound:
            return R.string.localizable.walletConnectFailureWalletsNotFound()
        case .delayedOperation, .cancelled:
            return nil
        }
    }
}

protocol WalletConnectResponder: AnyObject {
    func respond(_ response: AlphaWallet.WalletConnect.Response, request: AlphaWallet.WalletConnect.Session.Request) throws
}

protocol WalletConnectServer: WalletConnectResponder {
    var sessions: AnyPublisher<[AlphaWallet.WalletConnect.Session], Never> { get }

    var delegate: WalletConnectServerDelegate? { get set }

    func connect(url: AlphaWallet.WalletConnect.ConnectionUrl) throws
    func session(for topicOrUrl: AlphaWallet.WalletConnect.TopicOrUrl) -> AlphaWallet.WalletConnect.Session?
    func update(_ topicOrUrl: AlphaWallet.WalletConnect.TopicOrUrl, servers: [RPCServer]) throws
    func disconnect(_ topicOrUrl: AlphaWallet.WalletConnect.TopicOrUrl) throws
    func isConnected(_ topicOrUrl: AlphaWallet.WalletConnect.TopicOrUrl) -> Bool
}

protocol WalletConnectServerDelegate: AnyObject {

    func server(_ server: WalletConnectServer,
                didConnect session: AlphaWallet.WalletConnect.Session)

    func server(_ server: WalletConnectServer,
                shouldConnectFor proposal: AlphaWallet.WalletConnect.Proposal) -> AnyPublisher<AlphaWallet.WalletConnect.ProposalResponse, Never>

    func server(_ server: WalletConnectServer,
                action: AlphaWallet.WalletConnect.Action,
                request: AlphaWallet.WalletConnect.Session.Request,
                session: AlphaWallet.WalletConnect.Session)

    func server(_ server: WalletConnectServer,
                didFail error: Error)

    func server(_ server: WalletConnectServer,
                tookTooLongToConnectToUrl url: AlphaWallet.WalletConnect.ConnectionUrl)

    func server(_ server: WalletConnectServer, shouldAuthFor authRequest: AlphaWallet.WalletConnect.AuthRequest) -> AnyPublisher<AlphaWallet.WalletConnect.AuthRequestResponse, Never>
}
