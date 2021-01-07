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

protocol WalletConnectServerDelegate: class {
    func server(_ server: WalletConnectServer, shouldConnectFor connection: WalletConnectConnection, completion: @escaping (WalletConnectServer.ConnectionChoice) -> Void)
    func server(_ server: WalletConnectServer, action: WalletConnectServer.Action, request: WalletConnectRequest)
    func server(_ server: WalletConnectServer, didFail error: Error)
}

typealias WalletConnectRequest = WalletConnectSwift.Request

typealias WalletConnectRequestID = WalletConnectSwift.RequestID

extension WalletConnectSession {
    var requester: DAppRequester {
        return .init(title: dAppInfo.peerMeta.name, url: dAppInfo.peerMeta.url)
    }
}

class WalletConnectServer {
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
    private lazy var server: Server = Server(delegate: self)
    private let wallet: AlphaWallet.Address

    var urlToServer: [WCURL: RPCServer] = .init()
    var sessions: Subscribable<[WalletConnectSession]> = Subscribable([])

    weak var delegate: WalletConnectServerDelegate?

    init(wallet: AlphaWallet.Address) {
        self.wallet = wallet
        sessions.value = server.openSessions()
        server.register(handler: self)
    }

    func connect(url: WalletConnectURL) throws {
        try server.connect(to: url)
    }

    func reconnect(session: Session) throws {
        try server.reconnect(to: session)
    }

    func disconnect(session: Session) throws {
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

extension WalletConnectServer: RequestHandler {

    func canHandle(request: WalletConnectSwift.Request) -> Bool {
        return true
    }

    func handle(request: WalletConnectSwift.Request) {
        DispatchQueue.main.async {
            guard let delegate = self.delegate, let id = request.id else { return }

            self.convert(request: request).map { type -> Action in
                return .init(id: id, url: request.url, type: type)
            }.done { action in
                delegate.server(self, action: action, request: request)
            }.catch { error in
                delegate.server(self, didFail: error)
            }
        }
    }

    private func convert(request: WalletConnectSwift.Request) -> Promise<Action.ActionType> {
        guard let sessions = sessions.value else { return .init(error: WalletConnectError.connectionInvalid) }
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
    func server(_ server: Server, didFailToConnect url: WalletConnectURL) {
        DispatchQueue.main.async {
            guard var sessions = self.sessions.value, let delegate = self.delegate else { return }

            if let index = sessions.firstIndex(where: { $0.url.absoluteString == url.absoluteString }) {
                sessions.remove(at: index)
            }
            self.refresh(sessions: sessions)

            delegate.server(self, didFail: WalletConnectError.connect(url))
        }
    }

    private func refresh(sessions value: [Session]) {
        sessions.value = value
    }

    func server(_ server: Server, shouldStart session: Session, completion: @escaping (Session.WalletInfo) -> Void) {
        DispatchQueue.main.async {
            if let delegate = self.delegate {
                let connection = WalletConnectConnection(dAppInfo: session.dAppInfo, url: session.url)

                delegate.server(self, shouldConnectFor: connection) { [weak self] choice in
                    guard let strongSelf = self else { return }
                    let info = strongSelf.walletInfo(strongSelf.wallet, choice: choice)
                    strongSelf.urlToServer[session.url] = choice.server
                    completion(info)
                }
            } else {
                let info = self.walletInfo(self.wallet, choice: .cancel)
                completion(info)
            }
        }
    }

    func server(_ server: Server, didConnect session: Session) {
        DispatchQueue.main.async {
            guard var sessions = self.sessions.value else { return }
            if let index = sessions.firstIndex(where: { $0.dAppInfo.peerId == session.dAppInfo.peerId }) {
                sessions[index] = session
            } else {
                sessions.append(session)
            }
            UserDefaults.standard.walletConnectSessions = sessions
            self.refresh(sessions: sessions)
        }
    }

    func server(_ server: Server, didDisconnect session: Session) {
        DispatchQueue.main.async {
            guard var sessions = self.sessions.value else { return }
            if let index = sessions.firstIndex(where: { $0.dAppInfo.peerId == session.dAppInfo.peerId }) {
                //TODO should we remove by WCURL instead? Is that safer?
                sessions.remove(at: index)
            }
            UserDefaults.standard.walletConnectSessions = sessions
            self.refresh(sessions: sessions)
        }
    }
}

struct WalletConnectConnection {
    let url: WCURL
    let name: String
    let icon: URL?
    let server: RPCServer?

    init(dAppInfo info: Session.DAppInfo, url: WCURL) {
        self.url = url
        name = info.peerMeta.name
        icon = info.peerMeta.icons.first
        server = info.chainId.flatMap { .init(chainID: $0) }
    }
}
