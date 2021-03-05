//
//  Request.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 28.10.2020.
//

import Foundation
import WalletConnectSwift

extension WalletConnectServer {

    enum Request {

        enum AnyError: Error {
            case invalid
        }

        private enum Keys: String {
            case sign = "eth_sign"
            case personalSign = "personal_sign"
            case signTypedData = "eth_signTypedData"
            case signTransaction = "eth_signTransaction"
            case sendTransaction = "eth_sendTransaction"
            case sendRawTransaction = "eth_sendRawTransaction"
            case getTransactionCount = "eth_getTransactionCount"
        }

        case signTransaction(_ transaction: RawTransactionBridge)
        case sign(address: AlphaWallet.Address, message: String)
        case signPersonalMessage(address: AlphaWallet.Address, message: String)
        case signTypedData(address: AlphaWallet.Address, data: EIP712TypedData)
        case signTypedMessage(data: [EthTypedData])
        case sendTransaction(_ transaction: RawTransactionBridge)
        case sendRawTransaction(_ value: String)
        case getTransactionCount(_ filter: String)
        case unknown

        init(request: WalletConnectSwift.Request) throws {
            switch Keys(rawValue: request.method) {
            case .personalSign:
                let addressRawValue = try request.parameter(of: String.self, at: 1)
                let data = try request.parameter(of: String.self, at: 0)

                guard let address = AlphaWallet.Address(string: addressRawValue) else { throw AnyError.invalid }

                self = .signPersonalMessage(address: address, message: data)
            case .sign:
                let addressRawValue = try request.parameter(of: String.self, at: 0)
                let data = try request.parameter(of: String.self, at: 1)

                guard let address = AlphaWallet.Address(string: addressRawValue) else { throw AnyError.invalid }

                self = .sign(address: address, message: data)
            case .signTransaction:
                let data = try request.parameter(of: RawTransactionBridge.self, at: 0)

                self = .signTransaction(data)
            case .signTypedData:
                do {
                    let addressRawValue = try request.parameter(of: String.self, at: 0)
                    let rawValue = try request.parameter(of: String.self, at: 1)

                    guard let address = AlphaWallet.Address(string: addressRawValue), let data = rawValue.data(using: .utf8) else { throw AnyError.invalid }

                    let typed = try JSONDecoder().decode(EIP712TypedData.self, from: data)
                    self = .signTypedData(address: address, data: typed)
                } catch {
                    let rawValue = try request.parameter(of: String.self, at: 1)
                    guard let data = rawValue.data(using: .utf8) else { throw AnyError.invalid }

                    let typed = try JSONDecoder().decode([EthTypedData].self, from: data)
                    self = .signTypedMessage(data: typed)
                }
            case .sendTransaction:
                let data = try request.parameter(of: RawTransactionBridge.self, at: 0)

                self = .sendTransaction(data)
            case .sendRawTransaction:
                let data = try request.parameter(of: String.self, at: 0)

                self = .sendRawTransaction(data)
            case .getTransactionCount:
                let data = try request.parameter(of: String.self, at: 0)

                self = .getTransactionCount(data)
            case .none:
                self = .unknown
            }
        }
    }
}
