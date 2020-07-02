//
//  WalletConnectActionType.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 30.10.2020.
//

import Foundation

extension WalletConnectServer {

    struct Action {
        
        enum ActionType {
            case signMessage(String)
            case signPersonalMessage(String)
            case signTypedMessage(EIP712TypedData)
            case signTransaction(UnconfirmedTransaction)
            case sendTransaction(UnconfirmedTransaction)
            case sendRawTransaction(String)
            case getTransactionCount(String)
            case unknown
        }

        let id: WalletConnectRequestID
        let url: WalletConnectURL
        let type: ActionType
    }

    struct Callback {

        enum Value {
            case signTransaction(Data)
            case sentTransaction(Data)
            case signMessage(Data)
            case signPersonalMessage(Data)
            case signTypedMessage(Data)
            case getTransactionCount(Data)

            var object: String {
                switch self {
                case .signTransaction(let data):
                    return data.hexEncoded
                case .sentTransaction(let data):
                    return data.hexEncoded
                case .signMessage(let data):
                    return data.hexEncoded
                case .signPersonalMessage(let data):
                    return data.hexEncoded
                case .signTypedMessage(let data):
                    return data.hexEncoded
                case .getTransactionCount(let data):
                    return data.hexEncoded
                }
            }
        }

        let id: WalletConnectRequestID
        let url: WalletConnectURL
        let value: Value
    }
}
