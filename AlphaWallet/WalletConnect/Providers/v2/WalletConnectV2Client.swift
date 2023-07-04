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

struct MyCryptoProvider: WalletConnectSigner.CryptoProvider {
    enum SignerError: Error {
        case recoverPubKeyFailure
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
    var sessionProposalPublisher: AnyPublisher<(proposal: Session.Proposal, context: VerifyContext?), Never> { get }
    var sessionRequestPublisher: AnyPublisher<(request: Request, context: VerifyContext?), Never> { get }
    var sessionDeletePublisher: AnyPublisher<(String, Reason), Never> { get }
    var sessionSettlePublisher: AnyPublisher<Session, Never> { get }
    var sessionUpdatePublisher: AnyPublisher<(sessionTopic: String, namespaces: [String: SessionNamespace]), Never> { get }
    var authRequestPublisher: AnyPublisher<(request: AuthRequest, context: VerifyContext?), Never> { get }

    func getSessions() -> [Session]
    func connect(uri: WalletConnectURI)
    func update(topic: String, namespaces: [String: SessionNamespace])
    func disconnect(topic: String)
    func respond(topic: String, requestId: RPCID, response: RPCResult)
    func reject(proposalId: String, reason: RejectionReason)
    func approve(proposalId: String, namespaces: [String: SessionNamespace])
    func approve(authRequest request: AuthRequest)
    func reject(authRequest: AuthRequest)
}

final class WalletConnectV2NativeClient: WalletConnectV2Client {
    private let keystore: Keystore
    private let queue: DispatchQueue = .main
    private let metadata = AppMetadata(
        name: Constants.WalletConnect.server,
        description: "",
        url: Constants.WalletConnect.websiteUrl.absoluteString,
        icons: Constants.WalletConnect.icons)

    private lazy var client: Web3WalletClient = {
        Networking.configure(projectId: Constants.Credentials.walletConnectProjectId, socketFactory: SocketFactory())
        Web3Wallet.configure(metadata: metadata, crypto: MyCryptoProvider())
        return Web3Wallet.instance
    }()

    init(keystore: Keystore) {
        self.keystore = keystore
    }

    var sessionProposalPublisher: AnyPublisher<(proposal: Session.Proposal, context: VerifyContext?), Never> {
        client.sessionProposalPublisher
            .receive(on: queue)
            .eraseToAnyPublisher()
    }

    var authRequestPublisher: AnyPublisher<(request: AuthRequest, context: VerifyContext?), Never> {
        client.authRequestPublisher
            .receive(on: queue)
            .eraseToAnyPublisher()
    }

    var sessionRequestPublisher: AnyPublisher<(request: Request, context: VerifyContext?), Never> {
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

    func approve(authRequest request: AuthRequest) {
        switch keystore.currentWallet?.type {
        case .real(let address), .hardware(let address):
            Task {
                do {
                    let (cacaoSignature, account) = try await functional.signForAuth(authRequest: request, address: address, keystore: keystore)
                    try await Web3Wallet.instance.respond(requestId: request.id, signature: cacaoSignature, from: account)
                } catch {
                    //TODO show error to user
                }
            }
        case .watch:
            //TODO watch wallet. Should show an error message to user
            break
        case .none:
            preconditionFailure("Should always have an active wallet")
        }
    }

    func reject(authRequest request: AuthRequest) {
        Task {
            try? await Web3Wallet.instance.reject(requestId: request.id)
        }
    }

    enum functional {}
}

fileprivate extension WalletConnectV2NativeClient.functional {
    static func signForAuth(authRequest request: AuthRequest, address: AlphaWallet.Address, keystore: Keystore) async throws -> (CacaoSignature, Account) {
        struct EncodingError: Error {
            let errorDescription: String?
        }
        guard let blockchain = Blockchain("eip155:1") else { throw EncodingError(errorDescription: "Failed to encode blockchain") }
        guard let account: Account = Account(blockchain: blockchain, address: address.eip55String) else { throw EncodingError(errorDescription: "Failed to encode account") }
        let payload = try request.payload.cacaoPayload(address: account.address)
        let messageFormatter = SIWECacaoFormatter()
        let message: String = try messageFormatter.formatMessage(from: payload)
        guard let messageData = message.data(using: .utf8) else { throw EncodingError(errorDescription: "Failed to encode message as `Data`") }
        switch await keystore.signMessageData(messageData.prefixed, for: address, prompt: R.string.localizable.keystoreAccessKeySign()) {
        case .success(let signature):
            let cacaoSignature = CacaoSignature(t: .eip191, s: signature.hexEncoded)
            return (cacaoSignature, account)
        case .failure(let error):
            throw error
        }
    }
}
