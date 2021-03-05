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
            case signTypedMessageV3(EIP712TypedData)
            case signTransaction(UnconfirmedTransaction)
            case sendTransaction(UnconfirmedTransaction)
            case typedMessage([EthTypedData])
            case sendRawTransaction(String)
            case getTransactionCount(String)
            case unknown
        }

        let id: WalletConnectRequestID
        let url: WalletConnectURL
        let type: ActionType
    }

    struct Callback {
        let id: WalletConnectRequestID
        let url: WalletConnectURL
        let value: Data
    }
}
