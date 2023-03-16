//
//  WalletConnectV1Provider.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 09.11.2021.
//

import Foundation
import WalletConnectSwift
import AlphaWalletAddress
import Combine
import AlphaWalletFoundation
import AlphaWalletLogger

class WalletConnectV1Provider: WalletConnectServer {

    private let client: WalletConnectV1Client
    private let storage: WalletConnectV1Storage
    private let caip10AccountProvidable: CAIP10AccountProvidable
    private var cancelable = Set<AnyCancellable>()
    private let decoder: WalletConnectRequestDecoder
    private let config: Config

    var sessions: AnyPublisher<[AlphaWallet.WalletConnect.Session], Never> {
        return storage.publisher
            .map { $0.map { AlphaWallet.WalletConnect.Session(session: $0) } }
            .eraseToAnyPublisher()
    }
    weak var delegate: WalletConnectServerDelegate?

    init(caip10AccountProvidable: CAIP10AccountProvidable,
         client: WalletConnectV1Client,
         storage: WalletConnectV1Storage,
         decoder: WalletConnectRequestDecoder,
         config: Config) {

        self.config = config
        self.decoder = decoder
        self.client = client
        self.caip10AccountProvidable = caip10AccountProvidable
        self.storage = storage
        client.delegate = self

        caip10AccountProvidable
            .accounts
            .sink { [weak self] in self?.reloadSessions(accounts: $0) }
            .store(in: &cancelable)

        for each in storage.value {
            try? client.reconnect(to: each.session)
        }
    }

    deinit {
        verboseLog("[WalletConnect] WalletConnectV1Provider.deinit")
    }

    private func reloadSessions(accounts: Set<CAIP10Account>) {
        verboseLog("[WalletConnect] reload sessions with: \(accounts)")
        var sessionsToDelete: [Session] = []

        for (index, each) in storage.value.enumerated() {
            do {
                if accounts.isEmpty {
                    sessionsToDelete += [each.session]
                } else {
                    guard let blockchain = Blockchain(each.server.eip155) else { return }

                    if accounts.contains(where: { $0.blockchain == blockchain }) {
                        let data = try caip10AccountProvidable.namespaces(for: each.server)
                        let session = each.session.updatingWalletInfo(with: data.accounts, chainId: data.server.chainID)
                        storage.value[index] = .init(session: session, namespaces: data.namespaces)

                        try client.updateSession(session, with: session.walletInfo!)
                    } else if let account = accounts.first, let server = Eip155UrlCoder.decodeRpc(from: account.blockchain.absoluteString) {
                        let data = try caip10AccountProvidable.namespaces(for: server)
                        let session = each.session.updatingWalletInfo(with: data.accounts, chainId: data.server.chainID)

                        storage.value[index] = .init(session: session, namespaces: data.namespaces)
                        try client.updateSession(session, with: session.walletInfo!)
                    } else {

                        sessionsToDelete += [each.session]
                    }
                }
            } catch {
                verboseLog("[WalletConnect] failure to reload session: \(each.topicOrUrl)")
            }
        }

        for each in sessionsToDelete {
            removeSession(for: .init(url: each.url))

            try? client.disconnect(from: each)
        }
    }

    func connect(url: AlphaWallet.WalletConnect.ConnectionUrl) throws {
        guard case .v1(let wcUrl) = url else { return }

        try client.connect(to: WCURL(wcUrl.absoluteString)!)
    }

    func session(for topicOrUrl: AlphaWallet.WalletConnect.TopicOrUrl) -> AlphaWallet.WalletConnect.Session? {
        return storage.value.first(where: { $0.topicOrUrl == topicOrUrl }).flatMap { .init(session: $0) }
    }

    func update(_ topicOrUrl: AlphaWallet.WalletConnect.TopicOrUrl, servers: [RPCServer]) throws {
        guard let index = storage.value.firstIndex(where: { $0.topicOrUrl == topicOrUrl }), let server = servers.first else { return }
        let data = try caip10AccountProvidable.namespaces(for: server)

        let session = storage.value[index].session.updatingWalletInfo(with: data.accounts, chainId: data.server.chainID)
        storage.value[index] = .init(session: session, namespaces: data.namespaces)

        try client.updateSession(session, with: session.walletInfo!)
    }

    func disconnect(_ topicOrUrl: AlphaWallet.WalletConnect.TopicOrUrl) throws {
        guard let nativeSession = storage.value.first(where: { $0.topicOrUrl == topicOrUrl }) else { return }
        //NOTE: for some reasons completion handler doesn't get called, when we do disconnect, for this we remove session before do disconnect
        removeSession(for: .init(url: nativeSession.session.url))
        try client.disconnect(from: nativeSession.session)
    }

    func respond(_ response: AlphaWallet.WalletConnect.Response, request: AlphaWallet.WalletConnect.Session.Request) throws {
        guard case .v1(let request, _) = request else { return }
        guard let callbackId = request.id else { throw WalletConnectError.callbackIdMissing }

        switch response {
        case .value(let value):
            let response = try Response(url: request.url, value: value.flatMap { $0.hexEncoded }, id: callbackId)
            client.send(response)
        case .error(let code, let message):
            let response = try Response(url: request.url, errorCode: code, message: message, id: callbackId)
            client.send(response)
        }
    }

    func isConnected(_ topicOrUrl: AlphaWallet.WalletConnect.TopicOrUrl) -> Bool {
        guard let nativeSession = storage.value.first(where: { $0.topicOrUrl == topicOrUrl }) else { return false }
        return client.openSessions().contains(where: { $0.dAppInfo.peerId == nativeSession.session.dAppInfo.peerId })
    }
}

extension WalletConnectV1Provider: WalletConnectV1ClientDelegate {

    func server(_ server: Server, didReceiveRequest request: WalletConnectV1Request) {
        infoLog("[WalletConnect] handler request: \(request.method) url: \(request.url.absoluteString)")

        guard let session = storage.value.first(where: { $0.topicOrUrl == .url(url: .init(url: request.url)) }) else {
            return client.send(.reject(request))
        }
        do {
            let action = AlphaWallet.WalletConnect.Action(type: try decoder.decode(request: request, session: session))
            delegate?.server(self, action: action, request: .v1(request: request, server: session.server), session: .init(session: session))
        } catch let error as JsonRpcError {
            delegate?.server(self, didFail: error)
            //NOTE: we need to reject request if there is some arrays
            client.send(.reject(request))
        } catch {
            //no-op
        }
    }

    private func removeSession(for url: WalletConnectV1URL) {
        storage.value.removeAll(where: { $0.topicOrUrl == .url(url: url) })
    }

    func server(_ server: Server, tookTooLongToConnectToUrl url: WCURL) {
        delegate?.server(self, tookTooLongToConnectToUrl: .v1(wcUrl: WalletConnectV1URL(url: url)))
    }

    func server(_ server: Server, didFailToConnect url: WCURL) {
        let url = WalletConnectV1URL(url: url)
        infoLog("[WalletConnect] didFailToConnect: \(url)")
        removeSession(for: url)
        delegate?.server(self, didFail: WalletConnectError.connectionFailure(url))
    }

    func server(_ server: Server, shouldStart session: Session, completion: @escaping (Session.WalletInfo?) -> Void) {
        if let delegate = self.delegate {
            let sessionProposal = AlphaWallet.WalletConnect.Proposal(dAppInfo: session.dAppInfo)

            delegate.server(self, shouldConnectFor: sessionProposal)
                .sink { [weak self, caip10AccountProvidable] response in
                    guard let strongSelf = self else { return }

                    guard let server = response.server else {
                        completion(nil)
                        return
                    }

                    guard let data = try? caip10AccountProvidable.namespaces(for: server) else {
                        completion(nil)
                        return
                    }

                    let session = session.updatingWalletInfo(with: data.accounts, chainId: data.server.chainID)

                    if let index = strongSelf.storage.value.firstIndex(where: { $0.topicOrUrl == session.topicOrUrl }) {
                        strongSelf.storage.value[index] = .init(session: session, namespaces: data.namespaces)
                    } else {
                        strongSelf.storage.value.append(.init(session: session, namespaces: data.namespaces))
                    }

                    completion(session.walletInfo!)
                }.store(in: &cancelable)
        } else {
            completion(nil)
        }
    }

    @discardableResult private func addOrUpdateSession(session: Session) throws -> WalletConnectV1Session {
        let nativeSession: WalletConnectV1Session
        if let index = storage.value.firstIndex(where: { $0.topicOrUrl == session.topicOrUrl }) {
            let sessionToUpdate = storage.value[index]
            nativeSession = .init(session: session, namespaces: sessionToUpdate.namespaces)

            storage.value[index] = nativeSession
        } else {
            let server = session.dAppInfo.chainId.flatMap({ RPCServer(chainID: $0) }) ?? Config().anyEnabledServer()
            let data = try caip10AccountProvidable.namespaces(for: server)

            let session = session.updatingWalletInfo(with: data.accounts, chainId: data.server.chainID)
            nativeSession = .init(session: session, namespaces: data.namespaces)

            storage.value.append(nativeSession)
        }

        return nativeSession
    }

    func server(_ server: Server, didUpdate session: Session) {
        infoLog("[WalletConnect] didUpdate: \(session.url.absoluteString)")
        _ = try? addOrUpdateSession(session: session)
    }

    func server(_ server: Server, didConnect session: Session) {
        infoLog("[WalletConnect] didConnect: \(session.url.absoluteString)")
        guard let nativeSession: WalletConnectV1Session = try? addOrUpdateSession(session: session) else { return }
        delegate?.server(self, didConnect: .init(session: nativeSession))
    }

    func server(_ server: Server, didDisconnect session: Session) {
        removeSession(for: .init(url: session.url))
    }
}

fileprivate extension WalletConnectRequestDecoder {
    func decode(request: WalletConnectV1Request, session: WalletConnectV1Session) throws -> AlphaWallet.WalletConnect.Action.ActionType {
        return try decode(request: .v1(request: request, server: session.server))
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
