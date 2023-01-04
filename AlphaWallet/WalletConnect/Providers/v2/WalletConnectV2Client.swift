//
//  WalletConnectV2Client.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 07.01.2023.
//

import Foundation
import WalletConnectSwiftV2
import AlphaWalletFoundation
import Starscream
import Combine

extension WebSocket: WebSocketConnecting { }

struct SocketFactory: WebSocketFactory {
    func create(with url: URL) -> WebSocketConnecting {
        return WebSocket(url: url)
    }
}

protocol WalletConnectV2Client: AnyObject {
    var sessionProposalPublisher: AnyPublisher<Session.Proposal, Never> { get }
    var sessionRequestPublisher: AnyPublisher<Request, Never> { get }
    var sessionDeletePublisher: AnyPublisher<(String, Reason), Never> { get }
    var sessionSettlePublisher: AnyPublisher<Session, Never> { get }
    var sessionUpdatePublisher: AnyPublisher<(sessionTopic: String, namespaces: [String: SessionNamespace]), Never> { get }

    func getSessions() -> [Session]
    func connect(uri: WalletConnectURI)
    func update(topic: String, namespaces: [String: SessionNamespace])
    func disconnect(topic: String)
    func respond(topic: String, requestId: RPCID, response: RPCResult)
    func reject(proposalId: String, reason: RejectionReason)
    func approve(proposalId: String, namespaces: [String: SessionNamespace])
}

final class WalletConnectV2NativeClient: WalletConnectV2Client {
    private let queue: DispatchQueue = .main
    private let metadata = AppMetadata(
        name: Constants.WalletConnect.server,
        description: "",
        url: Constants.WalletConnect.websiteUrl.absoluteString,
        icons: Constants.WalletConnect.icons)

    private lazy var client: SignClient = {
        Networking.configure(projectId: Constants.Credentials.walletConnectProjectId, socketFactory: SocketFactory())
        Pair.configure(metadata: metadata)
        return Sign.instance
    }()

    var sessionProposalPublisher: AnyPublisher<Session.Proposal, Never> {
        client.sessionProposalPublisher
            .receive(on: queue)
            .eraseToAnyPublisher()
    }

    var sessionRequestPublisher: AnyPublisher<Request, Never> {
        client.sessionRequestPublisher
            .receive(on: queue)
            .eraseToAnyPublisher()
    }

    var sessionDeletePublisher: AnyPublisher<(String, Reason), Never> {
        client.sessionDeletePublisher
            .receive(on: queue)
            .eraseToAnyPublisher()
    }

    var sessionSettlePublisher: AnyPublisher<Session, Never> {
        client.sessionSettlePublisher
            .receive(on: queue)
            .eraseToAnyPublisher()
    }

    var sessionUpdatePublisher: AnyPublisher<(sessionTopic: String, namespaces: [String: SessionNamespace]), Never> {
        client.sessionUpdatePublisher
            .receive(on: queue)
            .eraseToAnyPublisher()
    }

    func getSessions() -> [Session] {
        client.getSessions()
    }

    func connect(uri: WalletConnectURI) {
        Task(priority: .high) { try await Pair.instance.pair(uri: uri) }
    }

    func update(topic: String, namespaces: [String: SessionNamespace]) {
        Task { try await client.update(topic: topic, namespaces: namespaces) }
    }

    func disconnect(topic: String) {
        Task { try await client.disconnect(topic: topic) }
    }

    func respond(topic: String, requestId: RPCID, response: RPCResult) {
        Task { try await client.respond(topic: topic, requestId: requestId, response: response) }
    }

    func reject(proposalId: String, reason: RejectionReason) {
        Task { try await client.reject(proposalId: proposalId, reason: reason) }
    }

    func approve(proposalId: String, namespaces: [String: SessionNamespace]) {
        Task { try await client.approve(proposalId: proposalId, namespaces: namespaces) }
    }
}
