//
//  WalletConnectV2Types.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 11.11.2021.
//

import Foundation
import WalletConnect

struct MultiServerWalletConnectSession: Codable, SessionIdentifiable {
    var dapp: AppMetadata
    private (set) var blockchains: Set<String>
    var methods: Set<String>
    let identifier: AlphaWallet.WalletConnect.SessionIdentifier

    var requester: DAppRequester {
        return .init(title: dapp.name, url: dapp.url.flatMap({ URL(string: $0) }))
    }

    var permissions: SessionPermissions {
        return .init(blockchains: blockchains, methods: methods)
    }

    var servers: [RPCServer] {
        get {
            return RPCServer.decodeEip155Array(values: blockchains)
        }
        set {
            blockchains = Set(newValue.compactMap { $0.eip155 })
        }
    }

    init(session: Session) {
        self.identifier = .topic(string: session.topic)
        self.dapp = session.peer
        self.blockchains = session.permissions.blockchains
        self.methods = session.permissions.methods
    }

    mutating func update(session: Session) {
        self.dapp = session.peer
        self.blockchains = session.permissions.blockchains
        self.methods = session.permissions.methods
    }

    mutating func update(permissions: SessionType.Permissions) {
        let permissions = permissions.decodedValue

        self.blockchains = permissions.blockchain.chains
        self.methods = permissions.jsonrpc.methods
    }
}

private extension SessionType.Permissions {
    //NOTE: Bridge to WalletConnectV2 permissions as the are internal
    struct PermissionsBridge: Codable {
        public struct Blockchain: Codable, Equatable {
            fileprivate(set) var chains: Set<String>

            public init(chains: Set<String>) {
                self.chains = chains
            }
        }

        public struct JSONRPC: Codable, Equatable {
            fileprivate(set) var methods: Set<String>

            public init(methods: Set<String>) {
                self.methods = methods
            }
        }

        let blockchain: Blockchain
        let jsonrpc: JSONRPC

        static var empty: PermissionsBridge = .init(blockchain: Blockchain(chains: []), jsonrpc: JSONRPC(methods: []))
    }

    var decodedValue: PermissionsBridge {
        guard let data = try? JSONEncoder().encode(self) else {
            return .empty
        }
        guard let decoded = try? JSONDecoder().decode(PermissionsBridge.self, from: data) else {
            return .empty
        }
        return decoded
    }
}

extension AlphaWallet.WalletConnect.Dapp {

    init(appMetadata metadata: AppMetadata) {
        self.name = metadata.name ?? ""
        self.description = metadata.description
        self.url = metadata.url.flatMap({ URL(string: $0) })!
        self.icons = metadata.icons.flatMap({ $0.compactMap({ URL(string: $0) }) }) ?? []
    }
}

extension AlphaWallet.WalletConnect.Session {

    init(multiServerSession session: MultiServerWalletConnectSession) {
        identifier = session.identifier
        servers = session.servers
        dapp = .init(appMetadata: session.dapp)
        methods = Array(session.methods)
        isMultipleServersEnabled = true
    }
}

enum WalletConnectV2ProviderError: Error {
    case connectionIsAlreadyPending
}

typealias WalletConnectV2Request = SessionRequest

extension WalletConnectV2Request {
    var rpcServer: RPCServer? {
        guard let chainId = chainId else { return nil }
        if let server = eip155URLCoder.decodeRPC(from: chainId) {
            return server
        } else if let value = Int(string: chainId) {
            return RPCServer(chainID: value)
        } else {
            return nil
        }
    }
}

public enum ResponseError: Int, Error {
    case invalidJSON = -32700
    case invalidRequest = -32600
    case methodNotFound = -32601
    case invalidParams = -32602
    case internalError = -32603

    case errorResponse = -32010
    case requestRejected = -32050

    public var message: String {
        switch self {
        case .invalidJSON: return "Parse error"
        case .invalidRequest: return "Invalid Request"
        case .methodNotFound: return "Method not found"
        case .invalidParams: return "Invalid params"
        case .internalError: return "Internal error"
        case .errorResponse: return "Error response"
        case .requestRejected: return "Request rejected"
        }
    }
}

extension SessionRequest {

    func rejected(error: ResponseError) -> JsonRpcResponseTypes {
        let response = JSONRPCErrorResponse(id: request.id, error: .init(code: error.code, message: error.message))
        return .error(response)
    }

    func value(data value: Data) -> JsonRpcResponseTypes {
        let response = JSONRPCResponse<AnyCodable>(id: request.id, result: AnyCodable(value.hexEncoded))
        return .response(response)
    }
}
