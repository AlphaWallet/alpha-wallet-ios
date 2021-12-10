//
//  WalletConnectSession.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 02.07.2020.
//

import UIKit
import WalletConnectSwift
import PromiseKit

enum WalletConnectError: Error {
    case connectionInvalid
    case invalidWCURL
    case connect(WalletConnectURL)
    case request(WalletConnectServer.Request.AnyError)
}

protocol WalletConnectServerDelegate: AnyObject {
    func server(_ server: WalletConnectServer, didConnect session: WalletConnectSession)
    func server(_ server: WalletConnectServer, shouldConnectFor connection: WalletConnectConnection, completion: @escaping (WalletConnectServer.ConnectionChoice) -> Void)
    func server(_ server: WalletConnectServer, action: WalletConnectServer.Action, request: WalletConnectRequest)
    func server(_ server: WalletConnectServer, didFail error: Error)
    func server(_ server: WalletConnectServer, tookTooLongToConnectToUrl url: WalletConnectURL)
}

typealias WalletConnectRequest = WalletConnectSwift.Request
typealias WalletConnectRequestID = WalletConnectSwift.RequestID

extension WalletConnectSession {
    var requester: DAppRequester {
        return .init(title: dAppInfo.peerMeta.name, url: dAppInfo.peerMeta.url)
    }

    var dappName: String {
        return dAppInfo.peerMeta.name
    }
    
    var dappNameShort: String {
        guard let approxDapName = dAppInfo.peerMeta.name.components(separatedBy: " ").first, approxDapName.nonEmpty else {
            return dAppInfo.peerMeta.name
        }

        return approxDapName
    }

    var dappIconUrl: URL? {
        dAppInfo.peerMeta.icons.first
    }

    var dappUrl: URL {
        dAppInfo.peerMeta.url
    }
}

class WalletConnectServer: NSObject {
    private static let connectionTimeout: TimeInterval = 10

    enum ConnectionChoice {
        case connect(RPCServer)
        case cancel

        var shouldProceed: Bool {
            switch self {
            case .connect:
                return true
            case .cancel:
                return false
            }
        }

        var server: RPCServer? {
            switch self {
            case .connect(let server):
                return server
            case .cancel:
                return nil
            }
        }
    }

    private enum Keys {
        static let server = "AlphaWallet"
    }

    private let walletMeta = Session.ClientMeta(name: Keys.server, description: nil, icons: [], url: URL(string: Constants.website)!)
    private let wallet: AlphaWallet.Address
    private var connectionTimeoutTimers: [WalletConnectURL: Timer] = .init()
    static var server: Server?
    //NOTE: We are using singleton server value because while every creation server object dones't release prev instances, WalletConnect meamory issue.
    private var server: Server {
        if let server = WalletConnectServer.server {
            return server
        } else {
            let server = Server(delegate: self)
            WalletConnectServer.server = server

            return server
        }
    }

    var urlToServer: [WalletConnectURL: RPCServer] {
        UserDefaults.standard.urlToServer
    }
    private var _sessions: Subscribable<[WalletConnectSession]> = Subscribable([])

    lazy var sessions: Subscribable<[WalletConnectSessionMappedToServer]> = {
        return _sessions.map { sessions -> [WalletConnectSessionMappedToServer] in
            return sessions.compactMap { session -> WalletConnectSessionMappedToServer? in
                //NOTE: Guard check to avoid empty sessions in the session list.
                guard session.dAppInfo.peerMeta.name.nonEmpty else { return nil }

                if let server = self.urlToServer[session.url] {
                    return (session, server)
                } else {
                    return nil
                }
            }
        }
    }()

    weak var delegate: WalletConnectServerDelegate?
    private lazy var requestHandler: RequestHandlerToAvoidMemoryLeak = { [weak self] in
        let handler = RequestHandlerToAvoidMemoryLeak()
        handler.delegate = self

        return handler
    }()

    init(wallet: AlphaWallet.Address) {
        self.wallet = wallet
        super.init()
        _sessions.value = server.openSessions()

        server.register(handler: requestHandler)
    }

    deinit {
        debug("[WalletConnect] WalletConnectServer.deinit")
        server.unregister(handler: requestHandler)
    }

    func connect(url: WalletConnectURL) throws {
        let timer = Timer.scheduledTimer(withTimeInterval: Self.connectionTimeout, repeats: false) { _ in
            let isStillWatching = self.connectionTimeoutTimers[url] != nil
            debug("WalletConnect app-enforced connection timer is up for: \(url.absoluteString) isStillWatching: \(isStillWatching)")
            if isStillWatching {
                //TODO be good if we can do `server.communicator.disconnect(from: url)` here on in the delegate. But `communicator` is not accessible
                self.delegate?.server(self, tookTooLongToConnectToUrl: url)
            } else {
                //no-op
            }
        }
        connectionTimeoutTimers[url] = timer

        try server.connect(to: url)
    }

    func updateSession(session: Session, server: RPCServer) throws {
        let walletInfo = walletInfo(wallet, choice: .connect(server))
        try self.server.updateSession(session, with: walletInfo)
        set(server: server, for: session.url)
        refresh(sessions: _sessions.value ?? [])
    }

    func reconnect(session: Session) throws {
        try server.reconnect(to: session)
    }

    func disconnect(session: Session) throws {
        //NOTE: for some reasons completion handler doesn't get called, when we do disconnect, for this we remove session before do disconnect
        removeSession(for: session.url)
        try server.disconnect(from: session)
    }

    func fulfill(_ callback: Callback, request: WalletConnectSwift.Request) throws {
        let response = try Response(url: callback.url, value: callback.value.hexEncoded, id: callback.id)
        server.send(response)
    }

    func reject(_ request: WalletConnectRequest) {
        server.send(.reject(request))
    }

    func hasConnected(session: Session) -> Bool {
        return server.openSessions().contains(where: {
            $0.dAppInfo.peerId == session.dAppInfo.peerId
        })
    }

    private func peerId(approved: Bool) -> String {
        return approved ? UUID().uuidString : String()
    }

    private func walletInfo(_ wallet: AlphaWallet.Address, choice: WalletConnectServer.ConnectionChoice) -> Session.WalletInfo {
        return Session.WalletInfo(
                approved: choice.shouldProceed,
                accounts: [wallet.eip55String],
                //When there's no server (because user chose to cancel), it shouldn't matter whether the fallback (mainnet) is enabled
                chainId: choice.server?.chainID ?? RPCServer.main.chainID,
                peerId: peerId(approved: choice.shouldProceed),
                peerMeta: walletMeta
        )
    }
}

protocol WalletConnectServerRequestHandlerDelegate: AnyObject {
    func handler(_ handler: RequestHandlerToAvoidMemoryLeak, request: WalletConnectSwift.Request)
    func handler(_ handler: RequestHandlerToAvoidMemoryLeak, canHandle request: WalletConnectSwift.Request) -> Bool
}

//NOTE: if we manually pass `self` link to WalletConnect server it causes memory leak and object doesn't get deleted.
class RequestHandlerToAvoidMemoryLeak {
    weak var delegate: WalletConnectServerRequestHandlerDelegate?
}

extension RequestHandlerToAvoidMemoryLeak: RequestHandler {

    func canHandle(request: WalletConnectSwift.Request) -> Bool {
        guard let delegate = delegate else { return false }

        return delegate.handler(self, canHandle: request)
    }

    func handle(request: WalletConnectSwift.Request) {
        guard let delegate = delegate else { return }

        return delegate.handler(self, request: request)
    }
}

extension WalletConnectServer: WalletConnectServerRequestHandlerDelegate {

    func handler(_ handler: RequestHandlerToAvoidMemoryLeak, request: WalletConnectSwift.Request) {
        debug("WalletConnect handler request: \(request.method) url: \(request.url.absoluteString)")
        DispatchQueue.main.async { [weak self] in
            guard let strongSelf = self else { return }
            guard let delegate = strongSelf.delegate, let id = request.id else { return }

            strongSelf.convert(request: request).map { type -> Action in
                return .init(id: id, url: request.url, type: type)
            }.done { action in
                delegate.server(strongSelf, action: action, request: request)
            }.catch { error in
                delegate.server(strongSelf, didFail: error)
                //NOTE: we need to reject request if there is some arrays
                strongSelf.reject(request)
            }
        }
    }

    func handler(_ handler: RequestHandlerToAvoidMemoryLeak, canHandle request: WalletConnectSwift.Request) -> Bool {
        debug("WalletConnect canHandle: \(request.method) url: \(request.url.absoluteString)")
        return true
    }

    private func convert(request: WalletConnectSwift.Request) -> Promise<Action.ActionType> {
        debug("WalletConnect convert request: \(request.method) url: \(request.url.absoluteString)")
        guard let sessions = _sessions.value else { return .init(error: WalletConnectError.connectionInvalid) }
        guard let session = sessions.first(where: { $0.url == request.url }) else { return .init(error: WalletConnectError.connectionInvalid) }
        guard let rpcServer = urlToServer[request.url] else { return .init(error: WalletConnectError.connectionInvalid) }
        let token = TokensDataStore.token(forServer: rpcServer)
        let transactionType: TransactionType = .dapp(token, session.requester)

        do {
            switch try Request(request: request) {
            case .sign(_, let message):
                return .value(.signMessage(message))
            case .signPersonalMessage(_, let message):

                return .value(.signPersonalMessage(message))
            case .signTransaction(let data):
                let data = UnconfirmedTransaction(transactionType: transactionType, bridge: data)

                return .value(.signTransaction(data))
            case .signTypedMessage(let data):
                return .value(.typedMessage(data))
            case .signTypedData(_, let data):

                return .value(.signTypedMessageV3(data))
            case .sendTransaction(let data):
                let data = UnconfirmedTransaction(transactionType: transactionType, bridge: data)

                return .value(.sendTransaction(data))
            case .sendRawTransaction(let rawValue):

                return .value(.sendRawTransaction(rawValue))
            case .unknown:

                return .value(.unknown)
            case .getTransactionCount(let filter):

                return .value(.getTransactionCount(filter))
            }
        } catch let error {
            return .init(error: error)
        }
    }
}

extension WalletConnectServer: ServerDelegate {

    func server(_ server: Server, didFailToConnect url: WCURL) {
        debug("WalletConnect didFailToConnect: \(url)")
        DispatchQueue.main.async {
            guard let delegate = self.delegate else { return }

            self.removeSession(for: url)
            delegate.server(self, didFail: WalletConnectError.connect(url))
        }
    }

    func server(_ server: Server, shouldStart session: Session, completion: @escaping (Session.WalletInfo) -> Void) {
        connectionTimeoutTimers[session.url] = nil

        DispatchQueue.main.async {
            if let delegate = self.delegate {
                let connection = WalletConnectConnection(dAppInfo: session.dAppInfo, url: session.url)

                delegate.server(self, shouldConnectFor: connection) { [weak self] choice in
                    guard let strongSelf = self else { return }

                    let info = strongSelf.walletInfo(strongSelf.wallet, choice: choice)
                    strongSelf.set(server: choice.server, for: session.url)

                    completion(info)
                }
            } else {
                let info = self.walletInfo(self.wallet, choice: .cancel)
                completion(info)
            }
        }
    }

    func server(_ server: Server, didConnect session: Session) {
        debug("WalletConnect didConnect: \(session.url.absoluteString)")
        DispatchQueue.main.async {
            self.addOrUpdateSession(session: session)
        }
    }

    func server(_ server: Server, didDisconnect session: Session) {
        DispatchQueue.main.async {
            self.removeSession(for: session.url)
        }
    }

    private func addOrUpdateSession(session: Session) {
        guard var sessions = _sessions.value else { return }
        if let index = sessions.firstIndex(where: { $0.dAppInfo.peerId == session.dAppInfo.peerId }) {
            sessions[index] = session
        } else {
            sessions.append(session)
        }

        UserDefaults.standard.walletConnectSessions = sessions
        refresh(sessions: sessions)
    }

    func server(_ server: Server, didUpdate session: Session) {
        debug("WalletConnect didUpdate: \(session.url.absoluteString)")
        DispatchQueue.main.async {
            self.addOrUpdateSession(session: session)
        }
    }

    private func removeSession(for url: WalletConnectURL) {
        guard var sessions = _sessions.value else { return }

        if let index = sessions.firstIndex(where: { $0.url.absoluteString == url.absoluteString }) {
            set(server: nil, for: sessions[index].url)
            sessions.remove(at: index)
        }

        UserDefaults.standard.walletConnectSessions = sessions
        refresh(sessions: sessions)
    }

    private func refresh(sessions value: [Session]) {
        _sessions.value = value
    }

    private func set(server: RPCServer?, for url: WalletConnectURL) {
        var urlToServer = UserDefaults.standard.urlToServer

        if let server = server {
            urlToServer[url] = server
        } else {
            urlToServer.removeValue(forKey: url)
        }

        UserDefaults.standard.urlToServer = urlToServer
    }
}

struct WalletConnectConnection {
    let url: WalletConnectURL
    let name: String
    let iconUrl: URL?
    let server: RPCServer?
    let dappUrl: URL

    init(dAppInfo info: Session.DAppInfo, url: WalletConnectURL) {
        self.url = url
        name = info.peerMeta.name
        dappUrl = info.peerMeta.url
        iconUrl = info.peerMeta.icons.first
        server = info.chainId.flatMap { .init(chainID: $0) }
    }
}
