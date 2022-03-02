//
//  WalletConnectVvProvider.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 10.11.2021.
//

import Foundation
import WalletConnect
import WalletConnectUtils
import Combine

protocol NativeCryptoCurrencyPricesProvider: class {
    var nativeCryptoCurrencyPrices: ServerDictionary<Subscribable<Double>> { get }
}

class WalletConnectV2Provider: WalletConnectServer {

    private var pendingSessionProposal: Session.Proposal?
    private var client: WalletConnectClient = {
        let metadata = AppMetadata(
            name: Constants.WalletConnect.server,
            description: nil,
            url: Constants.WalletConnect.websiteUrl.absoluteString,
            icons: Constants.WalletConnect.icons)
        let projectId = Constants.Credentials.walletConnectProjectId
        let relayHost = Constants.WalletConnect.relayURL.host!

        return WalletConnectClient(metadata: metadata, projectId: projectId, relayHost: relayHost)
    }()
    private var pendingSessionStack: [Session.Proposal] = []

    lazy var sessionsSubscribable: Subscribable<[AlphaWallet.WalletConnect.Session]> = {
        storage.valueSubscribable.map { sessions -> [AlphaWallet.WalletConnect.Session] in
            return sessions.map { session -> AlphaWallet.WalletConnect.Session in
                .init(multiServerSession: session)
            }
        }
    }()
    private let storage: SubscribableFileStorage<[MultiServerWalletConnectSession]>
    weak var delegate: WalletConnectServerDelegate?

    enum Keys {
        static let storageFileKey = "walletConnectSessions-v2"
    }

    private let config: Config = Config()
    //NOTE: Since the connection url doesn't we are getting in `func connect(url: AlphaWallet.WalletConnect.ConnectionUrl) throws` isn't the same of what we got in
    //`SessionProposal` we are not able to manage connection timeout. As well as we are not able to mach topics of urls. connection timeout isn't supported for now for v2.
    private var sessionsSubject: CurrentValueSubject<ServerDictionary<WalletSession>, Never>
    private var cancelable = Set<AnyCancellable>()
    //NOTE: we support only single account session as WalletConnects request doesn't provide a wallets address to sign transaction or some other method, so we cant figure out wallet address to sign, so for now we use only active wallet session address
    init(sessionsSubject: CurrentValueSubject<ServerDictionary<WalletSession>, Never>, storage: SubscribableFileStorage<[MultiServerWalletConnectSession]> = .init(fileName: Keys.storageFileKey, defaultValue: [])) {
        self.sessionsSubject = sessionsSubject
        self.storage = storage
        client.delegate = self

        //NOTE: skip empty sessions event
        sessionsSubject
            .filter { !$0.isEmpty }
            .sink { [weak self] sessions in
                self?.reloadSessions(sessions: sessions)
            }.store(in: &cancelable)
    }

    private func reloadSessions(sessions: ServerDictionary<WalletSession>) {
        func allAccountsInEip155(sessionServers: [RPCServer]) -> [String] {
            let availableSessions: [WalletSession] = sessions.values.filter { sessionServers.contains($0.server) }
            let wallets = Set(sessions.values.map { $0.account })
            //NOTE: idelly here is going to be one wallet address
            return wallets.map { wallet -> [String] in
                availableSessions.map { eip155URLCoder.encode(rpcServer: $0.server, address: wallet.address) }
            }.flatMap { $0 }
        }

        for each in storage.value {
            let accounts = Set(allAccountsInEip155(sessionServers: each.servers).compactMap { Account($0) })
            guard !accounts.isEmpty else { return }

            try? client.update(topic: each.identifier.description, accounts: accounts)
        }
    }

    func connect(url: AlphaWallet.WalletConnect.ConnectionUrl) throws {
        guard case .v2(let uri) = url else { return }
        debugLog("[RESPONDER] Pairing to: \(uri.absoluteString)")
        try client.pair(uri: uri.absoluteString)
    }

    func updateSession(session: AlphaWallet.WalletConnect.Session, servers: [RPCServer]) throws {
        guard let index = storage.value.firstIndex(where: { $0.identifier == session.identifier }) else { return }

        var session = storage.value[index]
        let topic = session.identifier.description
        session.servers = servers
        storage.value[index] = session

        try client.upgrade(topic: topic, permissions: session.permissions)
    }

    func reconnectSession(session: AlphaWallet.WalletConnect.Session) throws {
        //no-op
    }

    func session(forIdentifier identifier: AlphaWallet.WalletConnect.SessionIdentifier) -> AlphaWallet.WalletConnect.Session? {
        return storage.value.first(where: { $0.identifier == identifier }).flatMap { .init(multiServerSession: $0) }
    }

    func disconnectSession(sessions: [NFDSession]) throws {
        for each in sessions {
            let session = each.session
            guard let index = storage.value.firstIndex(where: { $0.identifier == session.identifier }) else { continue }

            //NOTE: all servers are match - disconnect session at all
            if Set(session.servers) == Set(each.serversToDisconnect) {
                storage.value.remove(at: index)

                client.disconnect(topic: session.identifier.description, reason: .init(code: 0, message: "disconnect"))
            } else {
                let leftServers = session.servers.filter { !each.serversToDisconnect.contains($0) }
                storage.value[index].servers = leftServers

                try client.upgrade(topic: session.identifier.description, permissions: storage.value[index].permissions)
            }
        }
    }

    func disconnectSession(session: AlphaWallet.WalletConnect.Session) throws {
        guard let index = storage.value.firstIndex(where: { $0.identifier == session.identifier }) else { return }
        let topic = storage.value[index].identifier.description
        client.disconnect(topic: topic, reason: .init(code: 0, message: "disconnect"))
        storage.value.remove(at: index)
    }

    func hasConnectedSession(session: AlphaWallet.WalletConnect.Session) -> Bool {
        return client.getSettledSessions().contains(where: { $0.topic == session.identifier.description })
    }

    func respond(_ response: AlphaWallet.WalletConnect.Response, request: AlphaWallet.WalletConnect.Session.Request) throws {
        guard case .v2(let request) = request else { return }
        switch response {
        case .value(let value):
            let payload = JSONRPCResponse<AnyCodable>(id: request.id, result: .init(value?.hexEncoded))

            client.respond(topic: request.topic, response: .response(payload))
        case .error(let code, let message):
            let response = JSONRPCErrorResponse(id: request.id, error: .init(code: code, message: message))

            client.respond(topic: request.topic, response: .error(response))
        }
    } 
}

fileprivate extension AlphaWallet.WalletConnect.SessionProposal {

    init(sessionProposal: Session.Proposal) {
        let appMetadata = sessionProposal.proposer

        self.name = appMetadata.name ?? ""
        self.dappUrl = appMetadata.url.flatMap({ URL(string: $0) })!
        self.description = appMetadata.description
        self.iconUrl = appMetadata.icons?.first.flatMap({ URL(string: $0) })
        self.servers = RPCServer.decodeEip155Array(values: sessionProposal.permissions.blockchains)
        methods = Array(sessionProposal.permissions.methods)
        isServerEditingAvailable = nil
    }
}

extension WalletConnectV2Provider: WalletConnectClientDelegate {

    func didReceive(sessionProposal: Session.Proposal) {
        guard pendingSessionProposal == nil else {
            return pendingSessionStack.append(sessionProposal)
        }

        didReceivePrivate(sessionProposal: sessionProposal, completion: { [weak self] in
            guard let strongSelf = self, let nextPendingSessionProposal = strongSelf.pendingSessionStack.popLast() else {
                return
            }

            strongSelf.didReceive(sessionProposal: nextPendingSessionProposal)
        })
    }

    func didReceive(sessionRequest: Request) {
        debugLog("[RESPONDER] WC: Did receive session request")

        func reject(sessionRequest: Request, error: AlphaWallet.WalletConnect.ResponseError) {
            debugLog("[RESPONDER] WC: Did reject session proposal: \(sessionRequest) with error: \(error.message)")

            let response = JSONRPCErrorResponse(id: sessionRequest.id, error: .init(code: error.code, message: error.message))
            client.respond(topic: sessionRequest.topic, response: .error(response))
        }
        //NOTE: guard check to avoid passing unacceptable rpc server,(when requested server is disabled)
        //FIXME: update with ability ask user for enabled disaled server
        guard let server = sessionRequest.rpcServer, config.enabledServers.contains(server) else {
            return reject(sessionRequest: sessionRequest, error: .internalError)
        }

        DispatchQueue.main.async { [weak self] in
            guard let strongSelf = self else { return }

            guard let session = strongSelf.storage.value.first(where: { $0.identifier == .topic(string: sessionRequest.topic) }) else {
                return reject(sessionRequest: sessionRequest, error: .requestRejected)
            }

            let request: AlphaWallet.WalletConnect.Session.Request = .v2(request: sessionRequest)
            WalletConnectRequestConverter()
                .convert(request: request, requester: session.requester)
                .map { type -> AlphaWallet.WalletConnect.Action in
                    return .init(type: type)
                }.done { action in
                    strongSelf.delegate?.server(strongSelf, action: action, request: request, session: .init(multiServerSession: session))
                }.catch { error in
                    strongSelf.delegate?.server(strongSelf, didFail: error)
                    //NOTE: we need to reject request if there is some arrays
                    reject(sessionRequest: sessionRequest, error: .requestRejected)
                }
        }
    }

    func didReceive(sessionResponse: Response) {
        debugLog("[RESPONDER] WC: Did receive session response")
    }

    func didDelete(sessionTopic: String, reason: Reason) {
        debugLog("[RESPONDER] WC: Did receive session delete")

        DispatchQueue.main.async { [weak self] in
            guard let strongSelf = self else { return }

            if let index = strongSelf.storage.value.firstIndex(where: { $0.identifier == .topic(string: sessionTopic) }) {
                strongSelf.storage.value.remove(at: index)
            }
        }
    }

    func didUpgrade(sessionTopic: String, permissions: Session.Permissions) {
        debugLog("[RESPONDER] WC: Did receive session upgrate")

        DispatchQueue.main.async { [weak self] in
            guard let strongSelf = self else { return }

            if let index = strongSelf.storage.value.firstIndex(where: { $0.identifier == .topic(string: sessionTopic) }) {
                strongSelf.storage.value[index].update(permissions: permissions)
            }
        }
    }

    func didUpdate(sessionTopic: String, accounts: Set<Account>) {
        debugLog("[RESPONDER] WC: Did receive session update")
    }

    func didSettle(session: Session) {
        debugLog("[RESPONDER] WC: Did settle session")
        DispatchQueue.main.async { [weak self] in
            guard let strongSelf = self else { return }

            for each in strongSelf.client.getSettledSessions() {
                if let index = strongSelf.storage.value.firstIndex(where: { $0.identifier == .topic(string: each.topic) }) {
                    strongSelf.storage.value[index].update(session: each)
                } else {
                    //NOTE: this case shouldn't happend as we passing through connect method and save all needed data
                    strongSelf.storage.value.append(.init(session: each))
                }
            }
        }
    }

    func didSettle(pairing: Pairing) {
        debugLog("[RESPONDER] WC: Did sattle pairing topic")
    }

    func didReceive(notification: Session.Notification, sessionTopic: String) {
        debugLog("[RESPONDER] WC: Did receive notification")
    }

    func didReject(pendingSessionTopic: String, reason: Reason) {
        debugLog("[RESPONDER] WC: Did reject session reason: \(reason)")
    }

    func didUpdate(pairingTopic: String, appMetadata: AppMetadata) {
        debugLog("[RESPONDER] WC: Did update pairing topic")
    }

    private func didReceivePrivate(sessionProposal: Session.Proposal, completion: @escaping () -> Void) {
        debugLog("[RESPONDER] WC: Did receive session proposal")

        func reject(sessionProposal: Session.Proposal) {
            debugLog("[RESPONDER] WC: Did reject session proposal: \(sessionProposal)")
            client.reject(proposal: sessionProposal, reason: RejectionReason.disapprovedChains)
            completion()
        }

        DispatchQueue.main.async { [weak self] in
            guard let strongSelf = self else { return }

            guard let delegate = strongSelf.delegate else {
                reject(sessionProposal: sessionProposal)
                return
            }

            do {
                try WalletConnectV2Provider.validatePendingProposal(sessionProposal)

                strongSelf.pendingSessionProposal = sessionProposal

                let sessionRequest: AlphaWallet.WalletConnect.SessionProposal = .init(sessionProposal: sessionProposal)
                delegate.server(strongSelf, shouldConnectFor: sessionRequest) { response in
                    guard response.shouldProceed else {
                        strongSelf.pendingSessionProposal = .none
                        reject(sessionProposal: sessionProposal)
                        return
                    }

                    let accounts = strongSelf.allAccountsInEip155(sessionServers: sessionRequest.servers)
                    let accountSet = Set(accounts.compactMap { Account($0) })
                    debugLog("[RESPONDER] WC: Did accept session proposal: \(sessionProposal) accounts: \(accountSet)")
                    guard !accountSet.isEmpty else {
                        strongSelf.pendingSessionProposal = .none
                        reject(sessionProposal: sessionProposal)
                        return
                    }

                    strongSelf.client.approve(proposal: sessionProposal, accounts: accountSet)
                    strongSelf.pendingSessionProposal = .none

                    completion()
                }
            } catch {
                delegate.server(strongSelf, didFail: error)
                //NOTE: for now we dont throw any error, just rejecting connection proposal
                reject(sessionProposal: sessionProposal)
                return
            }
        }
    }

    private func allAccountsInEip155(sessionServers: [RPCServer]) -> [String] {
        let availableSessions: [WalletSession] = sessionsSubject.value.values.filter { sessionServers.contains($0.server) }
        let wallets = Set(availableSessions.map { $0.account })

        return wallets.map { wallet -> [String] in
            availableSessions.map {
                eip155URLCoder.encode(rpcServer: $0.server, address: wallet.address)
            }
        }.flatMap { $0 }
    }

    //NOTE: Throws an error in case when `sessionProposal` contains mainnets as well as testnets
    private static func validatePendingProposal(_ proposal: Session.Proposal) throws {
        struct MixedMainnetsOrTestnetsError: Error {}

        let servers = RPCServer.decodeEip155Array(values: proposal.permissions.blockchains)
        let allAreTestnets = servers.allSatisfy { $0.isTestnet }
        if allAreTestnets {
            //no-op
        } else {
            let allAreMainnets = servers.allSatisfy { !$0.isTestnet }
            if allAreMainnets {
                //no-op
            } else {
                throw MixedMainnetsOrTestnetsError()
            }
        }
    }
}
