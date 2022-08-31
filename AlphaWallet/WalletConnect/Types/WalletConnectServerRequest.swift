//
//  Request.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 28.10.2020.
//

import Foundation 
import AlphaWalletFoundation

extension WalletConnectV1Request: PositionedJSONRPC_2_0_RequestType { }

extension AlphaWallet.WalletConnect {

    enum ResponseError: Error {
        case invalidJSON
        case invalidRequest
        case methodNotFound
        case invalidParams
        case internalError
        case errorResponse
        case requestRejected
        case unsupportedChain(chainId: String)
        case custom(code: Int, message: String)

        public var code: Int {
            switch self {
            case .invalidJSON: return -32700
            case .invalidRequest: return -32600
            case .methodNotFound: return -32601
            case .invalidParams: return -32602
            case .internalError: return -32603
            case .errorResponse: return -32010
            case .requestRejected: return -32050
            case .unsupportedChain: return 4902
            case .custom(let code, _): return code
            }
        }

        public var message: String {
            switch self {
            case .invalidJSON: return "Parse error"
            case .invalidRequest: return "Invalid Request"
            case .methodNotFound: return "Method not found"
            case .invalidParams: return "Invalid params"
            case .internalError: return "Internal error"
            case .errorResponse: return "Error response"
            case .requestRejected: return "Request rejected"
            case .unsupportedChain(let chainId): return "Unrecognized chain ID \(chainId). Try adding the chain using wallet_addEthereumChain first."
            case .custom(_, let message): return message
            }
        }
    }

    enum Request {
        case signTransaction(_ transaction: RawTransactionBridge)
        case sign(address: AlphaWallet.Address, message: String)
        case signPersonalMessage(address: AlphaWallet.Address, message: String)
        case signTypedData(address: AlphaWallet.Address, data: EIP712TypedData)
        case signTypedMessage(data: [EthTypedData])
        case sendTransaction(_ transaction: RawTransactionBridge)
        case sendRawTransaction(_ value: String)
        case getTransactionCount(_ filter: String)
        case walletSwitchEthereumChain(WalletSwitchEthereumChainObject)
        case walletAddEthereumChain(WalletAddEthereumChainObject)
        case custom(request: PositionedJSONRPC_2_0_RequestType)
        case unknown
    }
}

extension AlphaWallet.WalletConnect {
    
    struct RequestDecoder {
        enum Keys: String, CaseIterable {
            case sign = "eth_sign"
            case personalSign = "personal_sign"
            case signTypedData = "eth_signTypedData"
            case signTransaction = "eth_signTransaction"
            case sendTransaction = "eth_sendTransaction"
            case sendRawTransaction = "eth_sendRawTransaction"
            case getTransactionCount = "eth_getTransactionCount"
            case walletSwitchEthereumChain = "wallet_switchEthereumChain"
            case walletAddEthereumChain = "wallet_addEthereumChain"
        }

        static func decode(from request: PositionedJSONRPC_2_0_RequestType) throws -> AlphaWallet.WalletConnect.Request {
            switch Keys(rawValue: request.method) {
            case .personalSign:
                let addressRawValue = try request.parameter(of: String.self, at: 1)
                let data = try request.parameter(of: String.self, at: 0)

                guard let address = AlphaWallet.Address(string: addressRawValue) else { throw ResponseError.invalidRequest }

                return .signPersonalMessage(address: address, message: data)
            case .sign:
                let addressRawValue = try request.parameter(of: String.self, at: 0)
                let data = try request.parameter(of: String.self, at: 1)

                guard let address = AlphaWallet.Address(string: addressRawValue) else { throw ResponseError.invalidRequest }

                return .sign(address: address, message: data)
            case .signTransaction:
                let data = try request.parameter(of: RawTransactionBridge.self, at: 0)

                return .signTransaction(data)
            case .signTypedData:
                do {
                    let addressRawValue = try request.parameter(of: String.self, at: 0)
                    let rawValue = try request.parameter(of: String.self, at: 1)

                    guard let address = AlphaWallet.Address(string: addressRawValue), let data = rawValue.data(using: .utf8) else { throw ResponseError.invalidRequest }

                    let typed = try JSONDecoder().decode(EIP712TypedData.self, from: data)
                    return .signTypedData(address: address, data: typed)
                } catch {
                    let rawValue = try request.parameter(of: String.self, at: 1)
                    guard let data = rawValue.data(using: .utf8) else { throw ResponseError.invalidRequest }

                    let typed = try JSONDecoder().decode([EthTypedData].self, from: data)
                    return .signTypedMessage(data: typed)
                }
            case .sendTransaction:
                let data = try request.parameter(of: RawTransactionBridge.self, at: 0)

                return .sendTransaction(data)
            case .sendRawTransaction:
                let data = try request.parameter(of: String.self, at: 0)

                return .sendRawTransaction(data)
            case .getTransactionCount:
                let data = try request.parameter(of: String.self, at: 0)

                return .getTransactionCount(data)
            case .walletSwitchEthereumChain:
                let data = try request.parameter(of: WalletSwitchEthereumChainObject.self, at: 0)
                return .walletSwitchEthereumChain(data)
            case .walletAddEthereumChain:
                let data = try request.parameter(of: WalletAddEthereumChainObject.self, at: 0)
                return .walletAddEthereumChain(data)
            case .none:
                return .custom(request: request)
            }
        }
    }
}
