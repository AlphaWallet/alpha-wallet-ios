//
//  SwitchChainRequestViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 23.09.2021.
//

import Foundation
import AlphaWalletFoundation

struct SwitchChainRequestViewModel {
    let title: String = R.string.localizable.switchChainRequestTitle()
    let configuration: SwitchChainRequestConfiguration

    var description: String {
        switch configuration {
        case .promptAndSwitchToExistingServerInBrowser(let existingServer):
            return R.string.localizable.addCustomChainSwitchToExisting(existingServer.displayName, existingServer.chainID)
        case .promptAndAddAndActivateServer(let customChain, let customChainId):
            return R.string.localizable.addCustomChainAddAndSwitch(customChain.chainName ?? R.string.localizable.addCustomChainUnnamed(), customChainId)
        case .promptAndActivateExistingServer(let existingServer):
            return R.string.localizable.addCustomChainEnableExisting(existingServer.displayName, existingServer.chainID)
        }
    }

    var actionButtonTitle: String {
        switch configuration {
        case .promptAndSwitchToExistingServerInBrowser:
            // Switch & Reload
            return R.string.localizable.switchChainRequestActionSwitchReload()
        case .promptAndAddAndActivateServer:
            // Add, Switch & Reload Mainnet
            return R.string.localizable.switchChainRequestActionAddSwitchReload(R.string.localizable.settingsEnabledNetworksMainnet())
        case .promptAndActivateExistingServer:
            // Enable, Switch & Reload
            return R.string.localizable.switchChainRequestActionEnableSwitchReload()
        }
    }

    var additionalButtonTitle: String {
        R.string.localizable.switchChainRequestActionAddSwitchReload(R.string.localizable.settingsEnabledNetworksTestnet())
    }
}
