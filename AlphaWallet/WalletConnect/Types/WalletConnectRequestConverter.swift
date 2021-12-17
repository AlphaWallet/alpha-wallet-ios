//
//  WalletConnectRequestConverter.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 09.11.2021.
//

import Foundation
import PromiseKit
import WalletConnectSwift

struct WalletConnectRequestConverter {

    func convert(request: AlphaWallet.WalletConnect.Session.Request, requester: DAppRequester) -> Promise<AlphaWallet.WalletConnect.Action.ActionType> {
        guard let rpcServer: RPCServer = request.server else {
            return .init(error: WalletConnectRequestConverter.sessionRequestRPCServerMissing)
        }
        debug("WalletConnect convert request: \(request.method) url: \(request.topicOrURLString)")

        let token = TokensDataStore.token(forServer: rpcServer)
        let data: AlphaWallet.WalletConnect.Request
        do {
            switch request {
            case .v2(let request):
                let bridgePayload = try AlphaWallet.WalletConnect.Request.PositionedJSONRPC_2_0_Request(request: request)
                data = try AlphaWallet.WalletConnect.Request(request: bridgePayload)
            case .v1(let request, _):
                data = try AlphaWallet.WalletConnect.Request(request: request)
            }
        } catch let error {
            return .init(error: error)
        }

        switch data {
        case .sign(_, let message):
            return .value(.signMessage(message))
        case .signPersonalMessage(_, let message):
            return .value(.signPersonalMessage(message))
        case .signTransaction(let data):
            let data = UnconfirmedTransaction(transactionType: .dapp(token, requester), bridge: data)
            return .value(.signTransaction(data))
        case .signTypedMessage(let data):
            return .value(.typedMessage(data))
        case .signTypedData(_, let data):

            return .value(.signTypedMessageV3(data))
        case .sendTransaction(let data):
            let data = UnconfirmedTransaction(transactionType: .dapp(token, requester), bridge: data)
            return .value(.sendTransaction(data))
        case .sendRawTransaction(let rawValue):
            return .value(.sendRawTransaction(rawValue))
        case .unknown:
            return .value(.unknown)
        case .getTransactionCount(let filter):
            return .value(.getTransactionCount(filter))
        }
    }

    enum WalletConnectRequestConverter: Error {
        case sessionRequestRPCServerMissing
    }
}

protocol PositionedJSONRPC_2_0_RequestType {
    var method: String { get }

    func parameter<T: Decodable>(of type: T.Type, at position: Int) throws -> T
}

extension AlphaWallet.WalletConnect.Request {
    /// Bridge wrapper for  json rpc request, implemented in same way as for v1 of wallet connect
    struct PositionedJSONRPC_2_0_Request: PositionedJSONRPC_2_0_RequestType {
        let method: String

        private let payload: JSONRPC_2_0.Request
        private let request: WalletConnectV2Request

        init(request: WalletConnectV2Request) throws {
            let data = try JSONEncoder().encode(request.request.params)
            let values = try JSONDecoder().decode([JSONRPC_2_0.ValueType].self, from: data)
            let parameters = JSONRPC_2_0.Request.Params.positional(values)

            self.method = request.request.method
            self.payload = JSONRPC_2_0.Request(method: request.request.method, params: parameters, id: JSONRPC_2_0.IDType.int(request.request.id))
            self.request = request
        }

        public func parameter<T: Decodable>(of type: T.Type, at position: Int) throws -> T {
            guard let params = payload.params else {
                throw RequestError.parametersDoNotExist
            }
            switch params {
            case .named:
                throw RequestError.positionalParametersDoNotExist
            case .positional(let values):
                if position >= values.count {
                    throw RequestError.parameterPositionOutOfBounds
                }
                return try values[position].decode(to: type)
            }
        }
    }
}
