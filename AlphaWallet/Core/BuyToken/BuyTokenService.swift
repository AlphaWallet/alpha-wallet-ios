//
//  BuyTokenService.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 03.03.2021.
//

import Foundation
import Combine

protocol BuyTokenURLProviderType: TokenActionProvider {
    func url(token: TokenActionsIdentifiable, wallet: Wallet) -> URL?
}

protocol TokenActionServiceProvidable {
    func service(ofType: SupportedTokenActionsProvider.Type) -> SupportedTokenActionsProvider?
}

final class BuyTokenProvider: SupportedTokenActionsProvider, BuyTokenURLProviderType, TokenActionServiceProvidable {
    private let subProviders: [BuyTokenURLProviderType & SupportedTokenActionsProvider]

    var objectWillChange: AnyPublisher<Void, Never> {
        return Just(subProviders)
            .flatMap { Publishers.MergeMany($0.map { $0.objectWillChange }) }
            .mapToVoid()
            .eraseToAnyPublisher()
    }
    let analyticsNavigation: Analytics.Navigation = .fallback
    let analyticsName: String = "Buy Crypto"
    let action: String
    var services: [BuyTokenURLProviderType & SupportedTokenActionsProvider] { return subProviders }

    func isSupport(token: TokenActionsIdentifiable) -> Bool {
        return subProviders.contains(where: { $0.isSupport(token: token) })
    }

    func service(ofType: SupportedTokenActionsProvider.Type) -> SupportedTokenActionsProvider? {
        return subProviders.first(where: { type(of: $0) == ofType })
    }

    func actions(token: TokenActionsIdentifiable) -> [TokenInstanceAction] {
        return [.init(type: .buy(service: self))]
    }

    init(subProviders: [BuyTokenURLProviderType & SupportedTokenActionsProvider], action: String) {
        self.subProviders = subProviders
        self.action = action
    }

    func start() {
        subProviders.forEach { $0.start() }
    }

    func url(token: TokenActionsIdentifiable, wallet: Wallet) -> URL? {
        return subProviders.compactMap { $0.url(token: token, wallet: wallet) }.first
    }
}
