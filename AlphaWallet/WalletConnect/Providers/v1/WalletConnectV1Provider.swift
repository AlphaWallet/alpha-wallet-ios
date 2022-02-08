//
//  WalletConnectV1Provider.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 09.11.2021.
//

import Foundation
import WalletConnectSwift
import AlphaWalletAddress
import PromiseKit

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

class WalletConnectV1Provider: WalletConnectServerType {
    static let connectionTimeout: TimeInterval = 10

    enum Keys {
        static let server = "AlphaWallet"
        static func generateStorageFileKey(wallet: AlphaWallet.Address) -> String {
            return "walletConnectSessions-v1-\(wallet.eip55String)"
        }
    }

    private let walletMeta = Session.ClientMeta(name: Keys.server, description: nil, icons: [Constants.iconUrl], url: URL(string: Constants.website)!)
    private let wallet: AlphaWallet.Address
    private var connectionTimeoutTimers: [WalletConnectV1URL: Timer] = .init()
    private lazy var server: Server = {
        return Server(delegate: self)
    }()

    lazy var sessionsSubscribable: Subscribable<[AlphaWallet.WalletConnect.Session]> = {
        return storage.valueSubscribable.map { sessions -> [AlphaWallet.WalletConnect.Session] in
            return sessions.map { .init(session: $0) }
        }
    }()

    private let storage: SubscribableFileStorage<[SingleServerWalletConnectSession]>
    weak var delegate: WalletConnectServerDelegate?
    private lazy var requestHandler: RequestHandlerToAvoidMemoryLeak = { [weak self] in
        let handler = RequestHandlerToAvoidMemoryLeak()
        handler.delegate = self

        return handler
    }()

    init(wallet: AlphaWallet.Address) {
        self.wallet = wallet
        self.storage = .init(fileName: Keys.generateStorageFileKey(wallet: wallet), defaultValue: [])

        server.register(handler: requestHandler)
    }

    deinit {
        debugLog("[WalletConnect] WalletConnectServer.deinit")
        server.unregister(handler: requestHandler)
    }

    func connect(url: AlphaWallet.WalletConnect.ConnectionUrl) throws {
        switch url {
        case .v1(let wcUrl):
            let timer = Timer.scheduledTimer(withTimeInterval: Self.connectionTimeout, repeats: false) { _ in
                let isStillWatching = self.connectionTimeoutTimers[wcUrl] != nil
                debugLog("WalletConnect app-enforced connection timer is up for: \(wcUrl.absoluteString) isStillWatching: \(isStillWatching)")
                if isStillWatching {
                    //TODO be good if we can do `server.communicator.disconnect(from: url)` here on in the delegate. But `communicator` is not accessible
                    self.delegate?.server(self, tookTooLongToConnectToUrl: url)
                } else {
                    //no-op
                }
            }
            connectionTimeoutTimers[wcUrl] = timer

            try server.connect(to: wcUrl)
        case .v2:
            break
        }
    }

    func session(forIdentifier identifier: AlphaWallet.WalletConnect.SessionIdentifier) -> AlphaWallet.WalletConnect.Session? {
        return storage.value.first(where: { $0.identifier == identifier }).flatMap { .init(session: $0) }
    }

    func updateSession(session: AlphaWallet.WalletConnect.Session, servers: [RPCServer]) throws {
        guard let index = storage.value.firstIndex(where: { $0 == session }), let server = servers.first else { return }
        storage.value[index].server = server

        let walletInfo = walletInfo(wallet, choice: .connect(server))
        try self.server.updateSession(storage.value[index].session, with: walletInfo)
    }

    func reconnectSession(session: AlphaWallet.WalletConnect.Session) throws {
        guard let nativeSession = storage.value.first(where: { $0 == session }) else { return }

        try server.reconnect(to: nativeSession.session)
    }

    func disconnectSession(sessions: [NFDSession]) throws {
        for each in sessions {
            guard let session = storage.value.first(where: { $0 == each.session }) else { continue }

            removeSession(for: session.session.url)
            storage.value.removeAll(where: { $0 == each.session })
            try server.disconnect(from: session.session)
        }
    }

    func disconnectSession(session: AlphaWallet.WalletConnect.Session) throws {
        guard let nativeSession = storage.value.first(where: { $0 == session }) else { return }
        //NOTE: for some reasons completion handler doesn't get called, when we do disconnect, for this we remove session before do disconnect
        removeSession(for: nativeSession.session.url)
        try server.disconnect(from: nativeSession.session)
    }

    func fulfill(_ callback: AlphaWallet.WalletConnect.Callback, request: AlphaWallet.WalletConnect.Session.Request) throws {
        switch request {
        case .v1(let request, _):
            guard let callbackId = request.id else { throw WalletConnectError.callbackIdMissing }

            let response = try Response(url: request.url, value: callback.value.hexEncoded, id: callbackId)
            server.send(response)
        case .v2:
            break
        }
    }

    func reject(_ request: AlphaWallet.WalletConnect.Session.Request) {
        switch request {
        case .v1(let request, _):
            server.send(.reject(request))
        case .v2:
            break
        }
    }

    func hasConnectedSession(session: AlphaWallet.WalletConnect.Session) -> Bool {
        guard let nativeSession = storage.value.first(where: { $0 == session }) else { return false }
        return server.openSessions().contains(where: { $0.dAppInfo.peerId == nativeSession.session.dAppInfo.peerId })
    }

    private func walletInfo(_ wallet: AlphaWallet.Address, choice: AlphaWallet.WalletConnect.SessionProposalResponse) -> Session.WalletInfo {
        func peerId(approved: Bool) -> String {
            return approved ? UUID().uuidString : String()
        }

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

extension WalletConnectV1Provider: WalletConnectV1ServerRequestHandlerDelegate {

    func handler(_ handler: RequestHandlerToAvoidMemoryLeak, request: WalletConnectV1Request) {
        debugLog("WalletConnect handler request: \(request.method) url: \(request.url.absoluteString)")

        DispatchQueue.main.async { [weak self] in
            guard let strongSelf = self else { return }

            guard let session = strongSelf.storage.value.first(where: { $0 == request.url }) else {
                return strongSelf.server.send(.reject(request))
            }

            WalletConnectRequestConverter().convert(request: request, session: session).map { type -> AlphaWallet.WalletConnect.Action in
                return .init(type: type)
            }.done { action in
                strongSelf.delegate?.server(strongSelf, action: action, request: .v1(request: request, server: session.server), session: .init(session: session))
            }.catch { error in
                strongSelf.delegate?.server(strongSelf, didFail: error)
                //NOTE: we need to reject request if there is some arrays
                strongSelf.server.send(.reject(request))
            }
        }
    }

    func handler(_ handler: RequestHandlerToAvoidMemoryLeak, canHandle request: WalletConnectV1Request) -> Bool {
        debugLog("WalletConnect canHandle: \(request.method) url: \(request.url.absoluteString)")
        return true
    }
}

extension WalletConnectV1Provider: ServerDelegate {

    private func removeSession(for url: WalletConnectV1URL) {
        storage.value.removeAll(where: { $0 == url })
    }

    func server(_ server: Server, didFailToConnect url: WalletConnectV1URL) {
        debugLog("WalletConnect didFailToConnect: \(url)")
        DispatchQueue.main.async {
            self.connectionTimeoutTimers[url] = nil
            self.removeSession(for: url)
            self.delegate?.server(self, didFail: WalletConnectError.connect(url))
        }
    }

    func server(_ server: Server, shouldStart session: Session, completion: @escaping (Session.WalletInfo) -> Void) {
        connectionTimeoutTimers[session.url] = nil

        DispatchQueue.main.async {
            if let delegate = self.delegate {
                let sessionProposal = AlphaWallet.WalletConnect.SessionProposal(dAppInfo: session.dAppInfo, url: session.url)

                delegate.server(self, shouldConnectFor: sessionProposal) { [weak self] choice in
                    guard let strongSelf = self, let server = choice.server else { return }

                    let info = strongSelf.walletInfo(strongSelf.wallet, choice: choice)
                    if let index = strongSelf.storage.value.firstIndex(where: { $0 == session }) {
                        strongSelf.storage.value[index] = .init(session: session, server: server)
                    } else {
                        strongSelf.storage.value.append(.init(session: session, server: server))
                    }
                    completion(info)
                }
            } else {
                let info = self.walletInfo(self.wallet, choice: .cancel)
                completion(info)
            }
        }
    }

    @discardableResult private func addOrUpdateSession(session: Session) -> SingleServerWalletConnectSession {
        let nativeSession: SingleServerWalletConnectSession
        if let index = storage.value.firstIndex(where: { $0 == session }) {
            var sessionToUpdate = storage.value[index]
            sessionToUpdate.updateSession(session)
            nativeSession = sessionToUpdate

            storage.value[index] = sessionToUpdate
        } else {
            let server = session.dAppInfo.chainId.flatMap({ RPCServer(chainID: $0) }) ?? Config().anyEnabledServer()
            nativeSession = .init(session: session, server: server)

            storage.value.append(nativeSession)
        }
        return nativeSession
    }

    func server(_ server: Server, didUpdate session: Session) {
        debugLog("WalletConnect didUpdate: \(session.url.absoluteString)")
        DispatchQueue.main.async {
            self.addOrUpdateSession(session: session)
        }
    }

    func server(_ server: Server, didConnect session: Session) {
        debugLog("WalletConnect didConnect: \(session.url.absoluteString)")
        DispatchQueue.main.async {
            let nativeSession: SingleServerWalletConnectSession = self.addOrUpdateSession(session: session)
            if let delegate = self.delegate {
                delegate.server(self, didConnect: .init(session: nativeSession))
            }
        }
    }

    func server(_ server: Server, didDisconnect session: Session) {
        DispatchQueue.main.async {
            self.removeSession(for: session.url)
        }
    }
}

fileprivate extension WalletConnectRequestConverter {
    func convert(request: WalletConnectV1Request, session: SingleServerWalletConnectSession) -> Promise<AlphaWallet.WalletConnect.Action.ActionType> {
        return convert(request: .v1(request: request, server: session.server), requester: session.session.requester)
    }
}

fileprivate extension AlphaWallet.WalletConnect.Session {
    init(session: SingleServerWalletConnectSession) {
        identifier = session.identifier
        servers = [session.server]
        dapp = .init(dAppInfo: session.session.dAppInfo)
        methods = []
        isMultipleServersEnabled = false
    }
}
