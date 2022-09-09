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
import AlphaWalletCore
import AlphaWalletFoundation

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

    lazy var sessions: AnyPublisher<[AlphaWallet.WalletConnect.Session], Never> = {
        return storage.publisher
            .map { $0.map { AlphaWallet.WalletConnect.Session(session: $0) } }
            .eraseToAnyPublisher()
    }()

    private let storage: Storage<[WalletConnectV1Session]>
    weak var delegate: WalletConnectServerDelegate?
    private lazy var requestHandler: RequestHandlerToAvoidMemoryLeak = { [weak self] in
        let handler = RequestHandlerToAvoidMemoryLeak()
        handler.delegate = self

        return handler
    }()
    private let serviceProvider: SessionsProvider
    private var cancelable = Set<AnyCancellable>()
    private let queue: DispatchQueue = .main

    init(serviceProvider: SessionsProvider, storage: Storage<[WalletConnectV1Session]> = .init(fileName: Keys.storageFileKey, defaultValue: [])) {
        self.serviceProvider = serviceProvider
        self.storage = storage

        server.register(handler: requestHandler)

        serviceProvider.sessions
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
        verboseLog("[WalletConnect] WalletConnectV1Provider.deinit")
        server.unregister(handler: requestHandler)
    }

    func connect(url: AlphaWallet.WalletConnect.ConnectionUrl) throws {
        guard case .v1(let wcUrl) = url else { return }
        let timer = Timer.scheduledTimer(withTimeInterval: Constants.WalletConnect.connectionTimeout, repeats: false) { _ in
            let isStillWatching = self.connectionTimeoutTimers[wcUrl] != nil
            debugLog("[WalletConnect] app-enforced connection timer is up for: \(wcUrl.absoluteString) isStillWatching: \(isStillWatching)")
            if isStillWatching {
                //TODO be good if we can do `server.communicator.disconnect(from: url)` here on in the delegate. But `communicator` is not accessible
                self.delegate?.server(self, tookTooLongToConnectToUrl: url)
            } else {
                //no-op
            }
        }
        connectionTimeoutTimers[wcUrl] = timer

        try server.connect(to: WCURL(wcUrl.absoluteString)!)
    }

    func session(for topicOrUrl: AlphaWallet.WalletConnect.TopicOrUrl) -> AlphaWallet.WalletConnect.Session? {
        return storage.value.first(where: { $0.topicOrUrl == topicOrUrl }).flatMap { .init(session: $0) }
    }

    func update(_ topicOrUrl: AlphaWallet.WalletConnect.TopicOrUrl, servers: [RPCServer]) throws {
        guard let index = storage.value.firstIndex(where: { $0.topicOrUrl == topicOrUrl }), let server = servers.first else { return }
        let namespaces = namespaces(for: server)
        storage.value[index] = .init(session: storage.value[index].session, namespaces: namespaces)

        let wallets = Array(Set(serviceProvider.activeSessions.values.map { $0.account.address.eip55String }))
        let walletInfo = walletInfo(choice: .connect(server), wallets: wallets)
        try self.server.updateSession(storage.value[index].session, with: walletInfo)
    }

    func reconnect(_ topicOrUrl: AlphaWallet.WalletConnect.TopicOrUrl) throws {
        guard let nativeSession = storage.value.first(where: { $0.topicOrUrl == topicOrUrl }) else { return }

        try server.reconnect(to: nativeSession.session)
    }

    func disconnectSession(sessions: [NFDSession]) throws {
        for each in sessions {
            guard let session = storage.value.first(where: { $0.topicOrUrl == each.session.topicOrUrl }) else { continue }

            removeSession(for: .init(url: session.session.url))

            try server.disconnect(from: session.session)
        }
    }

    func disconnect(_ topicOrUrl: AlphaWallet.WalletConnect.TopicOrUrl) throws {
        guard let nativeSession = storage.value.first(where: { $0.topicOrUrl == topicOrUrl }) else { return }
        //NOTE: for some reasons completion handler doesn't get called, when we do disconnect, for this we remove session before do disconnect
        removeSession(for: .init(url: nativeSession.session.url))
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

    func isConnected(_ topicOrUrl: AlphaWallet.WalletConnect.TopicOrUrl) -> Bool {
        guard let nativeSession = storage.value.first(where: { $0.topicOrUrl == topicOrUrl }) else { return false }
        return server.openSessions().contains(where: { $0.dAppInfo.peerId == nativeSession.session.dAppInfo.peerId })
    }

    private func walletInfo(choice: AlphaWallet.WalletConnect.ProposalResponse, wallets: [String]) -> Session.WalletInfo {
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
        infoLog("[WalletConnect] handler request: \(request.method) url: \(request.url.absoluteString)")

        queue.async { [weak self] in
            guard let strongSelf = self else { return }

            guard let session = strongSelf.storage.value.first(where: { $0.topicOrUrl == .url(url: .init(url: request.url)) }) else {
                return strongSelf.server.send(.reject(request))
            }

            WalletConnectRequestConverter()
                .convert(request: request, session: session)
                .map { AlphaWallet.WalletConnect.Action(type: $0) }
                .done { action in
                    strongSelf.delegate?.server(strongSelf, action: action, request: .v1(request: request, server: session.server), session: .init(session: session))
                }.catch { error in
                    strongSelf.delegate?.server(strongSelf, didFail: error)
                    //NOTE: we need to reject request if there is some arrays
                    strongSelf.server.send(.reject(request))
                }
        }
    }

    func handler(_ handler: RequestHandlerToAvoidMemoryLeak, canHandle request: WalletConnectV1Request) -> Bool {
        infoLog("[WalletConnect] canHandle: \(request.method) url: \(request.url.absoluteString)")
        return true
    }
}

extension WalletConnectV1Provider: ServerDelegate {
    private func removeSession(for url: WalletConnectV1URL) {
        storage.value.removeAll(where: { $0.topicOrUrl == .url(url: url) })
    }

    func server(_ server: Server, didFailToConnect url: WCURL) {
        let url = WalletConnectV1URL(url: url)
        infoLog("[WalletConnect] didFailToConnect: \(url)")
        queue.async {
            self.connectionTimeoutTimers[url] = nil
            self.removeSession(for: url)
            self.delegate?.server(self, didFail: WalletConnectError.connectionFailure(url))
        }
    }

    func server(_ server: Server, shouldStart session: Session, completion: @escaping (Session.WalletInfo) -> Void) {
        connectionTimeoutTimers[.init(url: session.url)] = nil
        let wallets = Array(Set(serviceProvider.activeSessions.values.map { $0.account.address.eip55String }))

        queue.async {
            if let delegate = self.delegate {
                let sessionProposal = AlphaWallet.WalletConnect.Proposal(dAppInfo: session.dAppInfo)

                delegate.server(self, shouldConnectFor: sessionProposal) { [weak self] choice in
                    guard let strongSelf = self, let server = choice.server else { return }

                    let info = strongSelf.walletInfo(choice: choice, wallets: wallets)
                    let namespaces = strongSelf.namespaces(for: server)
                    if let index = strongSelf.storage.value.firstIndex(where: { $0.topicOrUrl == session.topicOrUrl }) {
                        strongSelf.storage.value[index] = .init(session: session, namespaces: namespaces)
                    } else {
                        strongSelf.storage.value.append(.init(session: session, namespaces: namespaces))
                    }
                    completion(info)
                }
            } else {
                let info = self.walletInfo(choice: .cancel, wallets: wallets)
                completion(info)
            }
        }
    }

    private func namespaces(for server: RPCServer?) -> [String: SessionNamespace] {
        let accounts = Set(serviceProvider.activeSessions.values.compactMap { _session -> CAIP10Account? in
            let server = server ?? _session.server
            guard let blockchain = Blockchain(server.eip155) else { return nil }

            return CAIP10Account(blockchain: blockchain, address: _session.account.address.eip55String)
        })
        return ["eip155": SessionNamespace(accounts: accounts, methods: [], events: [], extensions: [])]
    }

    @discardableResult private func addOrUpdateSession(session: Session) -> WalletConnectV1Session {
        let nativeSession: WalletConnectV1Session
        if let index = storage.value.firstIndex(where: { $0.topicOrUrl == session.topicOrUrl }) {
            let sessionToUpdate = storage.value[index]
            nativeSession = .init(session: session, namespaces: sessionToUpdate.namespaces)

            storage.value[index] = nativeSession
        } else {
            let server = session.dAppInfo.chainId.flatMap({ RPCServer(chainID: $0) }) ?? Config().anyEnabledServer()
            let namespaces = namespaces(for: server)
            nativeSession = .init(session: session, namespaces: namespaces)

            storage.value.append(nativeSession)
        }

        return nativeSession
    }

    func server(_ server: Server, didUpdate session: Session) {
        infoLog("[WalletConnect] didUpdate: \(session.url.absoluteString)")
        queue.async {
            self.addOrUpdateSession(session: session)
        }
    }

    func server(_ server: Server, didConnect session: Session) {
        infoLog("[WalletConnect] didConnect: \(session.url.absoluteString)")
        queue.async {
            let nativeSession: WalletConnectV1Session = self.addOrUpdateSession(session: session)
            if let delegate = self.delegate {
                delegate.server(self, didConnect: .init(session: nativeSession))
            }
        }
    }

    func server(_ server: Server, didDisconnect session: Session) {
        queue.async {
            self.removeSession(for: .init(url: session.url))
        }
    }
}

fileprivate extension WalletConnectRequestConverter {
    func convert(request: WalletConnectV1Request, session: WalletConnectV1Session) -> Promise<AlphaWallet.WalletConnect.Action.ActionType> {
        return convert(request: .v1(request: request, server: session.server), requester: session.session.requester)
    }
}

fileprivate extension AlphaWallet.WalletConnect.Session {
    init(session: WalletConnectV1Session) {
        topicOrUrl = session.topicOrUrl
        dapp = .init(dAppInfo: session.session.dAppInfo)
        multipleServersSelection = .disabled
        namespaces = session.namespaces
    }
}
