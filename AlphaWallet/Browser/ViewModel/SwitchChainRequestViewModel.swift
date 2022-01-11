//
//  SwitchChainRequestViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 23.09.2021.
//

import UIKit

enum SwitchChainRequestConfiguration {
    case promptAndSwitchToExistingServerInBrowser(existingServer: RPCServer)
    case promptAndAddAndActivateServer(customChain: WalletAddEthereumChainObject, customChainId: Int)
    case promptAndActivateExistingServer(existingServer: RPCServer)
}

enum SwitchChainRequestResponse {
    case action(Int)
    case canceled
}

struct SwitchChainRequestViewModel {
    let title: String = R.string.localizable.switchChainRequestTitle(preferredLanguages: Languages.preferred())
    let configuration: SwitchChainRequestConfiguration

    var description: String {
        switch configuration {
        case .promptAndSwitchToExistingServerInBrowser(let existingServer):
            return R.string.localizable.addCustomChainSwitchToExisting(existingServer.displayName, existingServer.chainID)
        case .promptAndAddAndActivateServer(let customChain, let customChainId):
            return R.string.localizable.addCustomChainAddAndSwitch(customChain.chainName ?? R.string.localizable.addCustomChainUnnamed(preferredLanguages: Languages.preferred()), customChainId)
        case .promptAndActivateExistingServer(let existingServer):
            return R.string.localizable.addCustomChainEnableExisting(existingServer.displayName, existingServer.chainID)
        }
    }

    var actionButtonTitle: String {
        switch configuration {
        case .promptAndSwitchToExistingServerInBrowser:
            // Switch & Reload
            return R.string.localizable.switchChainRequestActionSwitchReload(preferredLanguages: Languages.preferred())
        case .promptAndAddAndActivateServer:
            // Add, Switch & Reload Mainnet
            return R.string.localizable.switchChainRequestActionAddSwitchReload(R.string.localizable.settingsEnabledNetworksMainnet(preferredLanguages: Languages.preferred()))
        case .promptAndActivateExistingServer:
            // Enable, Switch & Reload
            return R.string.localizable.switchChainRequestActionEnableSwitchReload(preferredLanguages: Languages.preferred())
        }
    }

    var additionalButtonTitle: String {
        R.string.localizable.switchChainRequestActionAddSwitchReload(R.string.localizable.settingsEnabledNetworksTestnet(preferredLanguages: Languages.preferred()))
    }
}
