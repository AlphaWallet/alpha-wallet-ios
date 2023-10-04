//
//  SwitchChainRequestConfiguration.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 30.08.2022.
//

import Foundation
import AlphaWalletBrowser

public enum SwitchChainRequestConfiguration {
    case promptAndSwitchToExistingServerInBrowser(existingServer: RPCServer)
    case promptAndAddAndActivateServer(customChain: WalletAddEthereumChainObject, customChainId: Int)
    case promptAndActivateExistingServer(existingServer: RPCServer)
}

public enum SwitchChainRequestResponse {
    case action(Int)
    case canceled
}
