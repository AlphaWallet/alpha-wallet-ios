//
//  WalletConnectV1Client.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 06.01.2023.
//

import Foundation
import WalletConnectSwift
import AlphaWalletFoundation
import AlphaWalletLogger

protocol WalletConnectV1ClientDelegate: AnyObject {
    func server(_ server: Server, didReceiveRequest: Request)
    func server(_ server: Server, tookTooLongToConnectToUrl url: WCURL)
    func server(_ server: Server, didFailToConnect url: WCURL)
    func server(_ server: Server, shouldStart session: Session, completion: @escaping (Session.WalletInfo?) -> Void)
    func server(_ server: Server, didConnect session: Session)
    func server(_ server: Server, didDisconnect session: Session)
    func server(_ server: Server, didUpdate session: Session)
}

protocol WalletConnectV1Client: AnyObject {
    var delegate: WalletConnectV1ClientDelegate? { get set }

    func updateSession(_ session: Session, with walletInfo: Session.WalletInfo) throws
    func connect(to url: WCURL) throws
    func reconnect(to session: Session) throws
    func disconnect(from session: Session) throws
    func send(_ response: Response)
    func send(_ request: Request)
    func openSessions() -> [Session]
}

final class WalletConnectV1NativeClient: WalletConnectV1Client {
    enum ClientError: Error {
        case connectionTimeout
        case serverError(Error)
    }
    static let walletMeta: Session.ClientMeta = {
        let client = Session.ClientMeta(
            name: Constants.WalletConnect.server,
            description: nil,
            icons: Constants.WalletConnect.icons.compactMap { URL(string: $0) },
            url: Constants.WalletConnect.websiteUrl
        )
        return client
    }()
    private var walletInfoForCancellation: Session.WalletInfo {
        Session.WalletInfo(
            approved: false,
            accounts: [],
            //When there's no server (because user chose to cancel), it shouldn't matter whether the fallback (mainnet) is enabled
            chainId: RPCServer.main.chainID,
            peerId: String(),
            peerMeta: WalletConnectV1NativeClient.walletMeta)
    }

    private lazy var server = Server(delegate: self)
    private let queue: DispatchQueue = .main
    private lazy var requestHandler: RequestHandlerToAvoidMemoryLeak = { [weak self] in
        let handler = RequestHandlerToAvoidMemoryLeak()
        handler.delegate = self

        return handler
    }()
    private var connectionTimeoutTimers: [WCURL: Timer] = .init()

    var connectionTimeout: TimeInterval = 10
    weak var delegate: WalletConnectV1ClientDelegate?

    init() {
        server.register(handler: requestHandler)
    }

    deinit {
        server.unregister(handler: requestHandler)
    }

    func register(_ requestHandler: RequestHandler) {
        server.register(handler: requestHandler)
    }

    func unregister(_ requestHandler: RequestHandler) {
        server.unregister(handler: requestHandler)
    }

    func updateSession(_ session: Session, with walletInfo: Session.WalletInfo) throws {
        try server.updateSession(session, with: walletInfo)
    }

    func connect(to url: WCURL) throws {
        let timer = Timer.scheduledTimer(withTimeInterval: connectionTimeout, repeats: false) { _ in
            let isStillWatching = self.connectionTimeoutTimers[url] != nil
            debugLog("[WalletConnect] app-enforced connection timer is up for: \(url.absoluteString) isStillWatching: \(isStillWatching)")
            if isStillWatching {
                //TODO be good if we can do `server.communicator.disconnect(from: url)` here on in the delegate. But `communicator` is not accessible
                self.delegate?.server(self.server, tookTooLongToConnectToUrl: url)
            } else {
                //no-op
            }
        }
        connectionTimeoutTimers[url] = timer

        try server.connect(to: url)
    }

    func reconnect(to session: Session) throws {
        try server.reconnect(to: session)
    }

    func disconnect(from session: Session) throws {
        try server.disconnect(from: session)
    }

    func send(_ response: Response) {
        server.send(response)
    }

    func send(_ request: Request) {
        server.send(request)
    }

    func openSessions() -> [Session] {
        server.openSessions()
    }
}

extension WalletConnectV1NativeClient: WalletConnectV1ServerRequestHandlerDelegate {

    func handler(_ handler: RequestHandlerToAvoidMemoryLeak, request: WalletConnectV1Request) {
        queue.async {
            self.delegate?.server(self.server, didReceiveRequest: request)
        }
    }

    func handler(_ handler: RequestHandlerToAvoidMemoryLeak, canHandle request: WalletConnectV1Request) -> Bool {
        return true
    }
}

extension WalletConnectV1NativeClient: ServerDelegate {
    func server(_ server: Server, didFailToConnect url: WCURL) {
        queue.async {
            self.connectionTimeoutTimers[url] = nil
            self.delegate?.server(server, didFailToConnect: url)
        }
    }

    func server(_ server: Server, shouldStart session: Session, completion: @escaping (Session.WalletInfo) -> Void) {
        queue.async {
            self.connectionTimeoutTimers[session.url] = nil
            self.delegate?.server(server, shouldStart: session, completion: { info in
                completion(info ?? self.walletInfoForCancellation)
            })
        }
    }

    func server(_ server: Server, didConnect session: Session) {
        queue.async {
            self.delegate?.server(server, didConnect: session)
        }
    }

    func server(_ server: Server, didDisconnect session: Session) {
        queue.async {
            self.delegate?.server(server, didDisconnect: session)
        }
    }

    func server(_ server: Server, didUpdate session: Session) {
        queue.async {
            self.delegate?.server(server, didUpdate: session)
        }
    }
}

extension Session {
    func updatingWalletInfo(with accounts: [String], chainId: Int) -> Session {
        guard let walletInfo = walletInfo else {
            let walletInfo = Session.WalletInfo(
                approved: true,
                accounts: accounts,
                chainId: chainId,
                peerId: UUID().uuidString,
                peerMeta: WalletConnectV1NativeClient.walletMeta)

            return Session(url: url, dAppInfo: dAppInfo, walletInfo: walletInfo)
        }

        let newWalletInfo = Session.WalletInfo(
            approved: walletInfo.approved,
            accounts: accounts,
            chainId: chainId,
            peerId: walletInfo.peerId,
            peerMeta: walletInfo.peerMeta)

        let dAppInfo = DAppInfo(
            peerId: dAppInfo.peerId,
            peerMeta: dAppInfo.peerMeta,
            chainId: chainId,
            approved: dAppInfo.approved)

        return Session(url: url, dAppInfo: dAppInfo, walletInfo: newWalletInfo)
    }
}
