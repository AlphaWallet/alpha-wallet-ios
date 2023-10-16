//
//  File.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 26.04.2023.
//

import UIKit
import AlphaWalletFoundation

extension TokenActionsService {
    static func instance(networkService: NetworkService, tokenSwapper: TokenSwapper) -> TokenActionsService {
        let service = TokenActionsService()
        let traitCollection = UINavigationController().traitCollection
        if Features.current.isAvailable(.buyCryptoEnabled) {
            service.register(service: BuyTokenProvider(subProviders: [
                Coinbase(action: R.string.localizable.aWalletTokenBuyOnCoinbaseTitle()),
                Ramp(action: R.string.localizable.aWalletTokenBuyOnRampTitle(), networking: BaseRampNetworking(networkService: networkService))
            ], action: R.string.localizable.aWalletTokenBuyTitle()))
        }

        let honeySwapService = HoneySwap(action: R.string.localizable.aWalletTokenErc20ExchangeHoneyswapButtonTitle())
        honeySwapService.theme = traitCollection.honeyswapTheme

        let quickSwap = QuickSwap(action: R.string.localizable.aWalletTokenErc20ExchangeOnQuickSwapButtonTitle())
        quickSwap.theme = traitCollection.uniswapTheme
        var availableSwapProviders: [SupportedTokenActionsProvider & TokenActionProvider] = [
            honeySwapService,
            quickSwap,
            Oneinch(action: R.string.localizable.aWalletTokenErc20ExchangeOn1inchButtonTitle(), networking: BaseOneinchNetworking(networkService: networkService)),
            //uniswap
        ]
        availableSwapProviders += Features.current.isAvailable(.isSwapEnabled) ? [SwapTokenNativeProvider(tokenSwapper: tokenSwapper)] : []

        if Features.current.isAvailable(.isSwapEnabled) {
            service.register(service: SwapTokenProvider(subProviders: availableSwapProviders, action: R.string.localizable.aWalletTokenSwapButtonTitle()))
            service.register(service: ArbitrumBridge(action: R.string.localizable.aWalletTokenArbitrumBridgeButtonTitle()))
            service.register(service: xDaiBridge(action: R.string.localizable.aWalletTokenXDaiBridgeButtonTitle()))
        }

        return service
    }
}
