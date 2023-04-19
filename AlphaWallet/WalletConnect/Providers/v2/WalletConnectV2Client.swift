//
//  WalletConnectV2Client.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 07.01.2023.
//

import Foundation
import WalletConnectSign
import WalletConnectSigner
import AlphaWalletFoundation
import Starscream
import Combine
import AlphaWalletWeb3
import Web3Wallet
import AlphaWalletLogger

extension WebSocket: WebSocketConnecting { }

struct SocketFactory: WebSocketFactory {
    func create(with url: URL) -> WebSocketConnecting {
        return WebSocket(url: url)
    }
}

struct DefaultEthereumSignerFactory: SignerFactory {
    func createEthereumSigner() -> WalletConnectSigner.EthereumSigner {
        Web3Signer()
    }
}

struct Web3Signer: WalletConnectSigner.EthereumSigner {
    enum SignerError: Error {
        case recoverPubKeyFailure
    }

    func sign(message: Data, with key: Data) throws -> WalletConnectSigner.EthereumSignature {
        let hash = message.sha3(.keccak256)
        let signature = try EthereumSigner().sign(hash: hash, withPrivateKey: key)
        return WalletConnectSigner.EthereumSignature(v: signature[64], r: signature[0 ..< 32].bytes, s: signature[32 ..< 64].bytes)
    }

    func recoverPubKey(signature: WalletConnectSigner.EthereumSignature, message: Data) throws -> Data {
        guard let data = Web3.Utils.recoverPublicKey(message: message, v: signature.v, r: signature.r, s: signature.s) else {
            throw SignerError.recoverPubKeyFailure
        }
        return data
    }

    func keccak256(_ data: Data) -> Data {
        return data.sha3(.keccak256)
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

    private lazy var client: Web3WalletClient = {
        Networking.configure(projectId: Constants.Credentials.walletConnectProjectId, socketFactory: SocketFactory())
        Web3Wallet.configure(metadata: metadata, signerFactory: DefaultEthereumSignerFactory())
        return Web3Wallet.instance
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
        Sign.instance.sessionDeletePublisher
            .receive(on: queue)
            .eraseToAnyPublisher()
    }

    var sessionSettlePublisher: AnyPublisher<Session, Never> {
        Sign.instance.sessionSettlePublisher
            .receive(on: queue)
            .eraseToAnyPublisher()
    }

    var sessionUpdatePublisher: AnyPublisher<(sessionTopic: String, namespaces: [String: SessionNamespace]), Never> {
        Sign.instance.sessionUpdatePublisher
            .receive(on: queue)
            .eraseToAnyPublisher()
    }

    func getSessions() -> [Session] {
        client.getSessions()
    }

    func connect(uri: WalletConnectURI) {
        Task(priority: .high) {
            do {
                try await Pair.instance.pair(uri: uri)
            } catch {
                infoLog("[WalletConnect2] \(#function) failure with error: \(error)")
            }
        }
    }

    func update(topic: String, namespaces: [String: SessionNamespace]) {
        Task {
            do {
                try await client.update(topic: topic, namespaces: namespaces)
            } catch {
                infoLog("[WalletConnect2] \(#function) failure with error: \(error)")
            }
        }
    }

    func disconnect(topic: String) {
        Task {
            do {
                try await client.disconnect(topic: topic)
            } catch {
                infoLog("[WalletConnect2] \(#function) failure with error: \(error)")
            }
        }
    }

    func respond(topic: String, requestId: RPCID, response: RPCResult) {
        Task {
            do {
                try await client.respond(topic: topic, requestId: requestId, response: response)
            } catch {
                infoLog("[WalletConnect2] \(#function) failure with error: \(error)")
            }
        }
    }

    func reject(proposalId: String, reason: RejectionReason) {
        Task {
            do {
                try await client.reject(proposalId: proposalId, reason: reason)
            } catch {
                infoLog("[WalletConnect2] \(#function) failure with error: \(error)")
            }
        }
    }

    func approve(proposalId: String, namespaces: [String: SessionNamespace]) {
        Task {
            do {
                try await client.approve(proposalId: proposalId, namespaces: namespaces)
            } catch {
                infoLog("[WalletConnect2] \(#function) failure with error: \(error)")
            }
        }
    }
}
