//
//  SaveOperationType.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 30.08.2022.
//

import Foundation

enum SaveOperationType {
    case add
    case edit(CustomRPC)

    var customRpc: CustomRPC {
        switch self {
        case .add:
            return CustomRPC.blank
        case .edit(let customRpc):
            return customRpc
        }
    }
}

extension CustomRPC {
    static let blank: CustomRPC = CustomRPC(chainID: 0, nativeCryptoTokenName: nil, chainName: "", symbol: nil, rpcEndpoint: "", explorerEndpoint: nil, etherscanCompatibleType: .unknown, isTestnet: false)
}
