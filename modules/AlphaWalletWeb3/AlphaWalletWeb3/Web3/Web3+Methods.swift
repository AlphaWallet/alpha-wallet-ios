//
//  Web3+Methods.swift
//  web3swift
//
//  Created by Alexander Vlasov on 21.12.2017.
//  Copyright © 2017 Bankex Foundation. All rights reserved.
//

import Foundation

public enum JSONRPCmethod: Encodable {
    case gasPrice
    case blockNumber
    case getNetwork
    case sendRawTransaction
    case sendTransaction
    case estimateGas
    case call
    case getTransactionCount
    case getBalance
    case getCode
    case getStorageAt
    case getTransactionByHash
    case getTransactionReceipt
    case getAccounts
    case getBlockByHash
    case getBlockByNumber
    case personalSign
    case unlockAccount
    case getLogs
    case custom(String, params: Int)
    
    public var requiredNumOfParameters: Int {
        switch self {
        case .call:
            return 2
        case .getTransactionCount:
            return 2
        case .getBalance:
            return 2
        case .getStorageAt:
            return 2
        case .getCode:
            return 2
        case .getBlockByHash:
            return 2
        case .getBlockByNumber:
            return 2
        case .gasPrice:
            return 0
        case .blockNumber:
            return 0
        case .getNetwork:
            return 0
        case .getAccounts:
            return 0
        case .custom(_, let params):
            return params
        default:
            return 1
        }
    }

    public var rawValue: String {
        switch self {
        case .gasPrice: return "eth_gasPrice"
        case .blockNumber: return "eth_blockNumber"
        case .getNetwork: return "net_version"
        case .sendRawTransaction: return "eth_sendRawTransaction"
        case .sendTransaction: return "eth_sendTransaction"
        case .estimateGas: return "eth_estimateGas"
        case .call: return "eth_call"
        case .getTransactionCount: return "eth_getTransactionCount"
        case .getBalance: return "eth_getBalance"
        case .getCode: return "eth_getCode"
        case .getStorageAt: return "eth_getStorageAt"
        case .getTransactionByHash: return "eth_getTransactionByHash"
        case .getTransactionReceipt: return "eth_getTransactionReceipt"
        case .getAccounts: return "eth_accounts"
        case .getBlockByHash: return "eth_getBlockByHash"
        case .getBlockByNumber: return "eth_getBlockByNumber"
        case .personalSign: return "eth_sign"
        case .unlockAccount: return "personal_unlockAccount"
        case .getLogs: return "eth_getLogs"
        case .custom(let value, _): return value
        }
    }
}

extension JSONRPCmethod: Equatable {
    public static func == (lhs: JSONRPCmethod, rhs: JSONRPCmethod) -> Bool {
        return lhs.rawValue == rhs.rawValue && lhs.requiredNumOfParameters == rhs.requiredNumOfParameters
    }
}
