//
//  BuyTokenService.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 03.03.2021.
//

import Foundation
import Combine

public protocol BuyTokenURLProviderType: TokenActionProvider {
    func url(token: TokenActionsIdentifiable, wallet: Wallet) -> URL?
}

public protocol TokenActionServiceProvidable {
    func service(ofType: SupportedTokenActionsProvider.Type) -> SupportedTokenActionsProvider?
}

public final class BuyTokenProvider: SupportedTokenActionsProvider, BuyTokenURLProviderType, TokenActionServiceProvidable {
    private let subProviders: [BuyTokenURLProviderType & SupportedTokenActionsProvider]

    public var objectWillChange: AnyPublisher<Void, Never> {
        return Just(subProviders)
            .flatMap { Publishers.MergeMany($0.map { $0.objectWillChange }) }
            .mapToVoid()
            .eraseToAnyPublisher()
    }
    public let analyticsNavigation: Analytics.Navigation = .fallback
    public let analyticsName: String = "Buy Crypto"
    public let action: String
    public var services: [BuyTokenURLProviderType & SupportedTokenActionsProvider] { return subProviders }

    public func isSupport(token: TokenActionsIdentifiable) -> Bool {
        return subProviders.contains(where: { $0.isSupport(token: token) })
    }

    public func service(ofType: SupportedTokenActionsProvider.Type) -> SupportedTokenActionsProvider? {
        return subProviders.first(where: { type(of: $0) == ofType })
    }

    public func actions(token: TokenActionsIdentifiable) -> [TokenInstanceAction] {
        return [.init(type: .buy(service: self))]
    }

    public init(subProviders: [BuyTokenURLProviderType & SupportedTokenActionsProvider], action: String) {
        self.subProviders = subProviders
        self.action = action
    }

    public func start() {
        subProviders.forEach { $0.start() }
    }

    public func url(token: TokenActionsIdentifiable, wallet: Wallet) -> URL? {
        return subProviders.compactMap { $0.url(token: token, wallet: wallet) }.first
    }
}
