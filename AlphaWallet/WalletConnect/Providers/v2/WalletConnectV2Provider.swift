//
//  WalletConnectVvProvider.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 10.11.2021.
//

import Foundation
import WalletConnect

class WalletConnectV2Provider: WalletConnectServerType {

    private var pendingSessionProposal: Session.Proposal?
    private lazy var client: WalletConnectClient = {
        let metadata = AppMetadata(
            name: WalletConnectV1Provider.Keys.server,
            description: nil,
            url: Constants.website,
            icons: [Constants.iconUrl.absoluteString])
        let projectId = Constants.Credentials.walletConnectProjectId
        let relayHost = Constants.walletConnectRelayURL.host!

        let client = WalletConnectClient(metadata: metadata, projectId: projectId, isController: true, relayHost: relayHost)

        return client
    }()
    private var pendingSessinonStack: [Session.Proposal] = []

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
    private let sessions: ServerDictionary<WalletSession>
    private let config: Config = Config()
    //NOTE: Since the connection url doesn't we are getting in `func connect(url: AlphaWallet.WalletConnect.ConnectionUrl) throws` isn't the same of what we got in
    //`SessionProposal` we are not able to manage connection timeout. As well as we are not able to mach topics of urls. connection timeout isn't supported for now for v2.
    init(sessions: ServerDictionary<WalletSession>) {
        self.sessions = sessions
        self.storage = .init(fileName: Keys.storageFileKey, defaultValue: [])
        client.delegate = self
    }

    func connect(url: AlphaWallet.WalletConnect.ConnectionUrl) throws {
        switch url {
        case .v2(let uri):
            debugLog("[RESPONDER] Pairing to: \(uri.absoluteString)")

            try client.pair(uri: uri.absoluteString)
        case .v1:
            break
        }
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

        client.disconnect(topic: storage.value[index].identifier.description, reason: .init(code: 0, message: "disconnect"))
        storage.value.remove(at: index)
    }

    func hasConnectedSession(session: AlphaWallet.WalletConnect.Session) -> Bool {
        return client.getSettledSessions().contains(where: { $0.topic == session.identifier.description })
    }

    func fulfill(_ callback: AlphaWallet.WalletConnect.Callback, request: AlphaWallet.WalletConnect.Session.Request) throws {
        switch request {
        case .v2(let request):
            client.respond(topic: request.topic, response: request.value(data: callback.value))
        case .v1:
            break
        }
    }

    func reject(_ request: AlphaWallet.WalletConnect.Session.Request) {
        switch request {
        case .v2(let request):
            return client.respond(topic: request.topic, response: request.rejected(error: .requestRejected))
        case .v1:
            break
        }
    }
}

extension AlphaWallet.WalletConnect.SessionProposal {

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
            return pendingSessinonStack.append(sessionProposal)
        }

        didReceivePrivate(sessionProposal: sessionProposal, completion: { [weak self] in
            guard let strongSelf = self, let nextPensingSessionProposal = strongSelf.pendingSessinonStack.popLast() else {
                return
            }

            strongSelf.didReceive(sessionProposal: nextPensingSessionProposal)
        })
    }

    func didReceive(sessionRequest: Request) {
        debugLog("[RESPONDER] WC: Did receive session request")

        func reject(sessionRequest: Request) {
            debugLog("[RESPONDER] WC: Did reject session proposal: \(sessionRequest)")
            client.respond(topic: sessionRequest.topic, response: sessionRequest.rejected(error: .requestRejected))
        }
        //NOTE: guard check to avoid passing unacceptable rpc server,(when requested server is disabled)
        //FIXME: update with ability ask user for enabled disaled server
        guard let server = sessionRequest.rpcServer, config.enabledServers.contains(server) else {
            return client.respond(topic: sessionRequest.topic, response: sessionRequest.rejected(error: .invalidRequest))
        }

        DispatchQueue.main.async { [weak self] in
            guard let strongSelf = self else { return }

            guard let session = strongSelf.storage.value.first(where: { $0.identifier == .topic(string: sessionRequest.topic) }) else {
                return reject(sessionRequest: sessionRequest)
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
                    reject(sessionRequest: sessionRequest)
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

    func didUpdate(sessionTopic: String, accounts: Set<String>) {
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
            client.reject(proposal: sessionProposal, reason: Reason(code: 0, message: "reject"))
            completion()
        }

        DispatchQueue.main.async { [weak self] in
            guard let strongSelf = self else { return }

            guard let delegate = strongSelf.delegate else {
                return reject(sessionProposal: sessionProposal)
            }

            do {
                try strongSelf.validatePendingProposal(sessionProposal)

                strongSelf.pendingSessionProposal = sessionProposal

                let sessionRequest: AlphaWallet.WalletConnect.SessionProposal = .init(sessionProposal: sessionProposal)
                delegate.server(strongSelf, shouldConnectFor: sessionRequest) { response in
                    guard response.shouldProceed else {
                        strongSelf.pendingSessionProposal = .none
                        return reject(sessionProposal: sessionProposal)
                    }

                    let accounts = strongSelf.sessions.values.filter {
                        sessionRequest.servers.contains($0.server)
                    }.map {
                        eip155URLCoder.encode(rpcServer: $0.server, address: $0.account.address)
                    }

                    debugLog("[RESPONDER] WC: Did accept session proposal: \(sessionProposal) accounts: \(Set(accounts))")
                    strongSelf.client.approve(proposal: sessionProposal, accounts: Set(accounts))
                    strongSelf.pendingSessionProposal = .none

                    completion()
                }
            } catch {
                delegate.server(strongSelf, didFail: error)
                //NOTE: for now we dont throw any error, just rejecting connection proposal
                return reject(sessionProposal: sessionProposal)
            }
        }
    }

    //NOTE: Throws an error in case when `sessionProposal` contains mainnets as well as testnets
    private func validatePendingProposal(_ sessionProposal: Session.Proposal) throws {
        struct MixedMainnetsOrTestnetsError: Error {}

        let servers = RPCServer.decodeEip155Array(values: sessionProposal.permissions.blockchains)
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
