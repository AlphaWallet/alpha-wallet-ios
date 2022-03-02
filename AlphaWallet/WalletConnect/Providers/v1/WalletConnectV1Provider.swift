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
import Combine

class WalletConnectV1Provider: WalletConnectServer {
    enum Keys {
        static let storageFileKey = "walletConnectSessions-v1"
    }

    private let walletMeta: Session.ClientMeta = {
        let client = Session.ClientMeta(
            name: Constants.WalletConnect.server,
            description: nil,
            icons: Constants.WalletConnect.icons.compactMap { URL(string: $0) },
            url: Constants.WalletConnect.websiteUrl
        )
        return client
    }()
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
    private let sessionsSubject: CurrentValueSubject<ServerDictionary<WalletSession>, Never>
    private var cancelable = Set<AnyCancellable>()

    init(sessionsSubject: CurrentValueSubject<ServerDictionary<WalletSession>, Never>, storage: SubscribableFileStorage<[SingleServerWalletConnectSession]> = .init(fileName: Keys.storageFileKey, defaultValue: [])) {
        self.sessionsSubject = sessionsSubject
        self.storage = storage

        server.register(handler: requestHandler)

        sessionsSubject
            .filter { !$0.isEmpty }
            .sink { [weak self] sessions in
                guard let strongSelf = self else { return }
                let wallets = Array(Set(sessions.values.map { $0.account.address.eip55String }))

                for each in strongSelf.storage.value {
                    let walletInfo = strongSelf.walletInfo(choice: .connect(each.server), wallets: wallets)
                    try? strongSelf.server.updateSession(each.session, with: walletInfo)
                }
            }.store(in: &cancelable)
    }

    deinit {
        debugLog("[WalletConnect] WalletConnectV1Provider.deinit")
        server.unregister(handler: requestHandler)
    }

    func connect(url: AlphaWallet.WalletConnect.ConnectionUrl) throws {
        guard case .v1(let wcUrl) = url else { return }
        let timer = Timer.scheduledTimer(withTimeInterval: Constants.WalletConnect.connectionTimeout, repeats: false) { _ in
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
    }

    func session(forIdentifier identifier: AlphaWallet.WalletConnect.SessionIdentifier) -> AlphaWallet.WalletConnect.Session? {
        return storage.value.first(where: { $0.identifier == identifier }).flatMap { .init(session: $0) }
    }

    func updateSession(session: AlphaWallet.WalletConnect.Session, servers: [RPCServer]) throws {
        guard let index = storage.value.firstIndex(where: { $0 == session }), let server = servers.first else { return }
        storage.value[index].server = server
        let wallets = Array(Set(sessionsSubject.value.values.map { $0.account.address.eip55String }))
        let walletInfo = walletInfo(choice: .connect(server), wallets: wallets)
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

            try server.disconnect(from: session.session)
        }
    }

    func disconnectSession(session: AlphaWallet.WalletConnect.Session) throws {
        guard let nativeSession = storage.value.first(where: { $0 == session }) else { return }
        //NOTE: for some reasons completion handler doesn't get called, when we do disconnect, for this we remove session before do disconnect
        removeSession(for: nativeSession.session.url)
        try server.disconnect(from: nativeSession.session)
    }

    func respond(_ response: AlphaWallet.WalletConnect.Response, request: AlphaWallet.WalletConnect.Session.Request) throws {
        guard case .v1(let request, _) = request else { return }
        guard let callbackId = request.id else { throw WalletConnectError.callbackIdMissing }
        switch response {
        case .value(let value):
            let response = try Response(url: request.url, value: value.flatMap { $0.hexEncoded }, id: callbackId)
            server.send(response)
        case .error(let code, let message):
            let response = try Response(url: request.url, errorCode: code, message: message, id: callbackId)
            server.send(response)
        }
    }

    func hasConnectedSession(session: AlphaWallet.WalletConnect.Session) -> Bool {
        guard let nativeSession = storage.value.first(where: { $0 == session }) else { return false }
        return server.openSessions().contains(where: { $0.dAppInfo.peerId == nativeSession.session.dAppInfo.peerId })
    }

    private func walletInfo(choice: AlphaWallet.WalletConnect.SessionProposalResponse, wallets: [String]) -> Session.WalletInfo {
        func peerId(approved: Bool) -> String {
            return approved ? UUID().uuidString : String()
        }

        return Session.WalletInfo(
            approved: choice.shouldProceed,
            accounts: wallets,
            //When there's no server (because user chose to cancel), it shouldn't matter whether the fallback (mainnet) is enabled
            chainId: choice.server?.chainID ?? Config().anyEnabledServer().chainID,
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

            WalletConnectRequestConverter()
                .convert(request: request, session: session)
                .map { type -> AlphaWallet.WalletConnect.Action in
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
            self.delegate?.server(self, didFail: WalletConnectError.connectionFailure(url))
        }
    }

    func server(_ server: Server, shouldStart session: Session, completion: @escaping (Session.WalletInfo) -> Void) {
        connectionTimeoutTimers[session.url] = nil
        let wallets = Array(Set(sessionsSubject.value.values.map { $0.account.address.eip55String }))

        DispatchQueue.main.async {
            if let delegate = self.delegate {
                let sessionProposal = AlphaWallet.WalletConnect.SessionProposal(dAppInfo: session.dAppInfo, url: session.url)

                delegate.server(self, shouldConnectFor: sessionProposal) { [weak self] choice in
                    guard let strongSelf = self, let server = choice.server else { return }

                    let info = strongSelf.walletInfo(choice: choice, wallets: wallets)
                    if let index = strongSelf.storage.value.firstIndex(where: { $0 == session }) {
                        strongSelf.storage.value[index] = .init(session: session, server: server)
                    } else {
                        strongSelf.storage.value.append(.init(session: session, server: server))
                    }
                    completion(info)
                }
            } else {
                let info = self.walletInfo(choice: .cancel, wallets: wallets)
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
