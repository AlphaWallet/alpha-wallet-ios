//
//  WalletConnectVvProvider.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 10.11.2021.
//

import Foundation
import WalletConnectUtils
import Combine
import WalletConnectSign
import AlphaWalletFoundation

class WalletConnectV2Provider: WalletConnectServer {

    private var currentProposal: WalletConnectSign.Session.Proposal?
    private var pendingProposals: [WalletConnectSign.Session.Proposal] = []
    private let metadata = AppMetadata(name: Constants.WalletConnect.server, description: "", url: Constants.WalletConnect.websiteUrl.absoluteString, icons: Constants.WalletConnect.icons)
    private let storage = WalletConnectV2Storage()
    private let config: Config = Config()
    //NOTE: Since the connection url doesn't we are getting in `func connect(url: AlphaWallet.WalletConnect.ConnectionUrl) throws` isn't the same of what we got in
    //`SessionProposal` we are not able to manage connection timeout. As well as we are not able to mach topics of urls. connection timeout isn't supported for now for v2.
    private var serviceProvider: SessionsProvider
    private var cancelable = Set<AnyCancellable>()
    private let queue: DispatchQueue = .main

    weak var delegate: WalletConnectServerDelegate?
    lazy var sessions: AnyPublisher<[AlphaWallet.WalletConnect.Session], Never> = {
        return storage.sessions
            .map { $0.map { AlphaWallet.WalletConnect.Session(multiServerSession: $0) } }
            .eraseToAnyPublisher()
    }()
    private lazy var client: Sign = {
        Sign.configure(Sign.Config(metadata: metadata, projectId: Constants.Credentials.walletConnectProjectId))
        return .instance
    }()

    //NOTE: we support only single account session as WalletConnects request doesn't provide a wallets address to sign transaction or some other method, so we cant figure out wallet address to sign, so for now we use only active wallet session address
    init(serviceProvider: SessionsProvider) {
        self.serviceProvider = serviceProvider

        //NOTE: skip empty sessions event
        serviceProvider.sessions.filter { !$0.isEmpty }
            .sink { [weak self] sessions in
                self?.reloadSessions(sessions: sessions)
            }.store(in: &cancelable)

        client.sessionProposalPublisher
            .receive(on: queue)
            .sink { proposal in
                self.didReceive(proposal: proposal)
            }.store(in: &cancelable)

        client.sessionRequestPublisher
            .receive(on: queue)
            .sink { request in
                self.didReceive(request: request)
            }.store(in: &cancelable)

        client.sessionDeletePublisher
            .receive(on: queue)
            .sink { request in
                self.didDelete(topic: request.0, reason: request.1)
            }.store(in: &cancelable)

        client.sessionSettlePublisher
            .receive(on: queue)
            .sink { session in
                self.didSettle(session: session)
            }.store(in: &cancelable)

        client.sessionUpdatePublisher
            .receive(on: queue)
            .sink { data in
                self.didUpgrade(topic: data.sessionTopic, namespaces: data.namespaces)
            }.store(in: &cancelable)
    }

    private func reloadSessions(sessions: ServerDictionary<WalletSession>) {
        for each in storage.all() {
            let accounts = Set(sessions.values.map { $0.capi10Account })
            guard let session = try? storage.update(each.topicOrUrl, accounts: accounts) else { continue }

            Task { try await client.update(topic: each.topicOrUrl.description, namespaces: session.namespaces) }
        }
    }

    func connect(url: AlphaWallet.WalletConnect.ConnectionUrl) throws {
        guard case .v2(let uri) = url else { return }
        infoLog("[WalletConnect2] Pairing to: \(uri.absoluteString)")
        Task { try await client.pair(uri: uri.absoluteString) }
    }

    func update(_ topicOrUrl: AlphaWallet.WalletConnect.TopicOrUrl, servers: [RPCServer]) throws {
        guard let session = try? storage.update(topicOrUrl, servers: servers) else { return }

        Task { try await client.update(topic: topicOrUrl.description, namespaces: session.namespaces) }
    }

    func reconnect(_ topicOrUrl: AlphaWallet.WalletConnect.TopicOrUrl) throws {
        //no-op
    }

    func session(for topicOrUrl: AlphaWallet.WalletConnect.TopicOrUrl) -> AlphaWallet.WalletConnect.Session? {
        let session = try? storage.session(for: topicOrUrl)
        return session.flatMap { .init(multiServerSession: $0) }
    }

    func disconnectSession(sessions: [NFDSession]) throws {
        for each in sessions {
            let topicOrUrl = each.session.topicOrUrl
            guard storage.contains(topicOrUrl) else { continue }

            //NOTE: all servers are match - disconnect session at all
            if Set(each.session.servers) == Set(each.serversToDisconnect) {
                storage.remove(for: topicOrUrl)

                Task { try await client.disconnect(topic: topicOrUrl.description, reason: .init(code: 0, message: "disconnect")) }
            } else {
                let leftServers = each.session.servers.filter { !each.serversToDisconnect.contains($0) }
                let session = try storage.update(topicOrUrl, servers: leftServers)

                Task { try await client.update(topic: topicOrUrl.description, namespaces: session.namespaces) }
            }
        }
    }

    func disconnect(_ topicOrUrl: AlphaWallet.WalletConnect.TopicOrUrl) throws {
        guard storage.contains(topicOrUrl) else { return }

        storage.remove(for: topicOrUrl)
        Task { try await client.disconnect(topic: topicOrUrl.description, reason: .init(code: 0, message: "disconnect")) }
    }

    func isConnected(_ topicOrUrl: AlphaWallet.WalletConnect.TopicOrUrl) -> Bool {
        return Sign.instance.getSessions().contains(where: { $0.topic == topicOrUrl.description })
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

    private func didReceive(proposal: WalletConnectSign.Session.Proposal) {
        guard currentProposal == nil else {
            return pendingProposals.append(proposal)
        }

        _didReceive(proposal: proposal, completion: { [weak self] in
            guard let strongSelf = self, let next = strongSelf.pendingProposals.popLast() else { return }
            strongSelf.didReceive(proposal: next)
        })
    }

    private func reject(request: WalletConnectSign.Request, error: AlphaWallet.WalletConnect.ResponseError) {
        infoLog("[WalletConnect2] WC: Did reject session proposal: \(request) with error: \(error.message)")

        let response = JSONRPCErrorResponse(id: request.id, error: .init(code: error.code, message: error.message))
        client.respond(topic: request.topic, response: .error(response))
    }

    private func didReceive(request: WalletConnectSign.Request) {
        infoLog("[WalletConnect2] WC: Did receive session request")

        //NOTE: guard check to avoid passing unacceptable rpc server,(when requested server is disabled)
        //FIXME: update with ability ask user for enabled disaled server
        guard let server = request.rpcServer, config.enabledServers.contains(server) else {
            return reject(request: request, error: .internalError)
        }

        DispatchQueue.main.async { [weak self] in
            guard let strongSelf = self else { return }

            guard let session = try? strongSelf.storage.session(for: .topic(string: request.topic)) else {
                return strongSelf.reject(request: request, error: .requestRejected)
            }

            let requestV2: AlphaWallet.WalletConnect.Session.Request = .v2(request: request)
            WalletConnectRequestConverter()
                .convert(request: requestV2, requester: session.requester)
                .map { AlphaWallet.WalletConnect.Action(type: $0) }
                .done { action in
                    strongSelf.delegate?.server(strongSelf, action: action, request: requestV2, session: .init(multiServerSession: session))
                }.catch { error in
                    strongSelf.delegate?.server(strongSelf, didFail: error)
                    //NOTE: we need to reject request if there is some arrays
                    strongSelf.reject(request: request, error: .requestRejected)
                }
        }
    }

    private func didDelete(topic: String, reason: WalletConnectSign.Reason) {
        infoLog("[WalletConnect2] WC: Did receive session delete")
        storage.remove(for: .topic(string: topic))
    }

    private func didUpgrade(topic: String, namespaces: [String: SessionNamespace]) {
        infoLog("[WalletConnect2] WC: Did receive session upgrate")

        _ = try? storage.update(.topic(string: topic), namespaces: namespaces)
    }

    private func didSettle(session: WalletConnectSign.Session) {

        infoLog("[WalletConnect2] WC: Did settle session")
        for each in client.getSessions() {
            storage.addOrUpdate(session: each)
        }
    }

    private func _didReceive(proposal: WalletConnectSign.Session.Proposal, completion: @escaping () -> Void) {
        infoLog("[WalletConnect2] WC: Did receive session proposal")

        func reject(proposal: WalletConnectSign.Session.Proposal) {
            infoLog("[WalletConnect2] WC: Did reject session proposal: \(proposal)")
            client.reject(proposal: proposal, reason: .disapprovedChains)
            completion()
        }

        DispatchQueue.main.async { [weak self] in
            guard let strongSelf = self else { return }

            guard let delegate = strongSelf.delegate else {
                reject(proposal: proposal)
                return
            }

            do {
                try WalletConnectV2Provider.validateProposalForMixedMainnetOrTestnet(proposal)

                delegate.server(strongSelf, shouldConnectFor: .init(proposal: proposal)) { response in
                    do {
                        guard response.shouldProceed else {
                            strongSelf.currentProposal = .none
                            reject(proposal: proposal)
                            return
                        }

                        let sessionNamespaces = try strongSelf.validateProposalForSupportingBlockchains(proposal)

                        try strongSelf.client.approve(proposalId: proposal.id, namespaces: sessionNamespaces)
                        strongSelf.currentProposal = .none

                        completion()
                    } catch {
                        delegate.server(strongSelf, didFail: error)
                        //NOTE: for now we dont throw any error, just rejecting connection proposal
                        reject(proposal: proposal)
                        return
                    }
                }
            } catch {
                delegate.server(strongSelf, didFail: error)
                //NOTE: for now we dont throw any error, just rejecting connection proposal
                reject(proposal: proposal)
                return
            }
        }
    }

    //NOTE: Throws an error in case when `sessionProposal` contains mainnets as well as testnets
    private static func validateProposalForMixedMainnetOrTestnet(_ proposal: WalletConnectSign.Session.Proposal) throws {
        struct MixedMainnetsOrTestnetsError: Error {}
        for namespace in proposal.requiredNamespaces.values {
            let blockchains = Set(namespace.chains.map { $0.absoluteString })
            let servers = RPCServer.decodeEip155Array(values: blockchains)
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

    private func validateProposalForSupportingBlockchains(_ proposal: WalletConnectSign.Session.Proposal) throws -> [String: SessionNamespace] {
        struct BlockchainValidationError: Error {}

        func accountForSupportedBlockchain(for blockchain: Blockchain) -> WalletConnectSign.Account? {
            guard let server = eip155URLCoder.decodeRPC(from: blockchain.absoluteString) else { return nil }
            guard serviceProvider.activeSessions.contains(where: { $0.value.server == server }) else { return nil }

            return WalletConnectSign.Account(blockchain.absoluteString + ":\(account)")
        }

        let account = serviceProvider.activeSessions.anyValue.account.address.eip55String

        var sessionNamespaces = [String: SessionNamespace]()
        for each in proposal.requiredNamespaces {
            let caip2Namespace = each.key
            let proposalNamespace = each.value
            let accounts = Set(proposalNamespace.chains.compactMap { accountForSupportedBlockchain(for: $0) })

            let extensions: [SessionNamespace.Extension]? = proposalNamespace.extensions?.map { element in
                let accounts = Set(element.chains.compactMap { accountForSupportedBlockchain(for: $0) })

                return SessionNamespace.Extension(accounts: accounts, methods: element.methods, events: element.events)
            }

            if accounts.isEmpty {
                continue
            }

            let sessionNamespace = SessionNamespace(accounts: accounts, methods: proposalNamespace.methods, events: proposalNamespace.events, extensions: extensions)
            sessionNamespaces[caip2Namespace] = sessionNamespace
        }

        if sessionNamespaces.isEmpty {
            throw BlockchainValidationError()
        }

        return sessionNamespaces
    }
}

fileprivate extension AlphaWallet.WalletConnect.Proposal {

    init(proposal: WalletConnectSign.Session.Proposal) {
        name = proposal.proposer.name
        dappUrl = URL(string: proposal.proposer.url)!
        description = proposal.proposer.description
        iconUrl = proposal.proposer.icons.compactMap({ URL(string: $0) }).first
        servers = proposal.requiredNamespaces.values.flatMap { RPCServer.decodeEip155Array(values: Set($0.chains.map { $0.absoluteString }) ) }
        methods = Array(proposal.requiredNamespaces.values.flatMap { $0.methods })
        serverEditing = .notSupporting
    }
}
