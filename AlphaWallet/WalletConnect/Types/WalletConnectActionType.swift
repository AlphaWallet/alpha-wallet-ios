//
//  WalletConnectActionType.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 30.10.2020.
//

import Foundation
import AlphaWalletFoundation

extension AlphaWallet.WalletConnect {

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
            case walletSwitchEthereumChain(WalletSwitchEthereumChainObject)
            case walletAddEthereumChain(WalletAddEthereumChainObject)
            case unknown
        }

        let type: ActionType
    }

    enum Response: CustomStringConvertible {
        case value(Data?)
        case error(code: Int, message: String)

        init(data: Data?) {
            self = .value(data)
        }

        init(code: Int, message: String) {
            self = .error(code: code, message: message)
        }

        init(error: AlphaWallet.WalletConnect.ResponseError) {
            self = .error(code: error.code, message: error.message)
        }

        var description: String {
            switch self {
            case .value(let data):
                return "{value: {data: \(String(describing: data ?? .init()))}}"
            case .error(let code, let message):
                return "{error: {code: \(code), message: \(message)}}"
            }
        }
    }
}
