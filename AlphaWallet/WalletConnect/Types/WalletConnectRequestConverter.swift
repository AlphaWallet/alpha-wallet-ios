//
//  WalletConnectRequestDecoder.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 09.11.2021.
//

import Foundation
import PromiseKit
import WalletConnectSwift
import AlphaWalletFoundation

struct WalletConnectRequestDecoder {

    func decode(request: AlphaWallet.WalletConnect.Session.Request) -> Promise<AlphaWallet.WalletConnect.Action.ActionType> {
        guard let server: RPCServer = request.server else {
            return .init(error: WalletConnectRequestDecoder.sessionRequestRPCServerMissing)
        }
        infoLog("[WalletConnect] convert request: \(request.method) url: \(request.description)")

        let data: AlphaWallet.WalletConnect.Request
        do {
            data = try AlphaWallet.WalletConnect.Request(request: request)
        } catch let error {
            return .init(error: error)
        }

        switch data {
        case .sign(_, let message):
            return .value(.signMessage(message))
        case .signPersonalMessage(_, let message):
            return .value(.signPersonalMessage(message))
        case .signTransaction(let bridgeTransaction):
            do {
                let transaction = try TransactionType.prebuilt(server).buildAnyDappTransaction(bridgeTransaction: bridgeTransaction)
                return .value(.signTransaction(transaction))
            } catch {
                return .init(error: error)
            }
        case .signTypedMessage(let data):
            return .value(.typedMessage(data))
        case .signTypedData(_, let data):
            return .value(.signTypedMessageV3(data))
        case .sendTransaction(let bridgeTransaction):
            do {
                let transaction = try TransactionType.prebuilt(server).buildAnyDappTransaction(bridgeTransaction: bridgeTransaction)
                return .value(.sendTransaction(transaction))
            } catch {
                return .init(error: error)
            }
        case .sendRawTransaction(let rawValue):
            return .value(.sendRawTransaction(rawValue))
        case .unknown:
            return .value(.unknown)
        case .getTransactionCount(let filter):
            return .value(.getTransactionCount(filter))
        case .walletSwitchEthereumChain(let data):
            return .value(.walletSwitchEthereumChain(data))
        case .walletAddEthereumChain(let data):
            return .value(.walletAddEthereumChain(data))
        case .custom:
            return .init(error: WalletConnectRequestDecoder.unsupportedMethod)
        }
    }

    enum WalletConnectRequestDecoder: Error {
        case sessionRequestRPCServerMissing
        case unsupportedMethod
    }
}

protocol PositionedJSONRPC_2_0_RequestType {
    var method: String { get }

    func parameter<T: Decodable>(of type: T.Type, at position: Int) throws -> T
}

extension AlphaWallet.WalletConnect.Request {

    init(request: AlphaWallet.WalletConnect.Session.Request) throws {
        switch request {
        case .v2(let request):
            let bridgePayload = try AlphaWallet.WalletConnect.Request.PositionedJSONRPC_2_0_Request(request: request)
            self = try AlphaWallet.WalletConnect.RequestDecoder.decode(from: bridgePayload)
        case .v1(let request, _):
            self = try AlphaWallet.WalletConnect.RequestDecoder.decode(from: request)
        }
    }

    /// Bridge wrapper for  json rpc request, implemented in same way as for v1 of wallet connect
    private struct PositionedJSONRPC_2_0_Request: PositionedJSONRPC_2_0_RequestType {
        let method: String

        private let payload: JSONRPC_2_0.Request
        private let request: WalletConnectV2Request

        init(request: WalletConnectV2Request) throws {
            let data = try JSONEncoder().encode(request.params)
            let values = try JSONDecoder().decode([JSONRPC_2_0.ValueType].self, from: data)
            let parameters = JSONRPC_2_0.Request.Params.positional(values)

            self.method = request.method

            let id: JSONRPC_2_0.IDType
            switch request.id {
            case .left(let string):
                id = .string(string)
            case .right(let int):
                id = .int(int)
            }
            self.payload = JSONRPC_2_0.Request(method: request.method, params: parameters, id: id)
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
