//
//  SwitchChainRequestConfiguration.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 30.08.2022.
//

import Foundation

enum SwitchChainRequestConfiguration {
    case promptAndSwitchToExistingServerInBrowser(existingServer: RPCServer)
    case promptAndAddAndActivateServer(customChain: WalletAddEthereumChainObject, customChainId: Int)
    case promptAndActivateExistingServer(existingServer: RPCServer)
}

enum SwitchChainRequestResponse {
    case action(Int)
    case canceled
}
