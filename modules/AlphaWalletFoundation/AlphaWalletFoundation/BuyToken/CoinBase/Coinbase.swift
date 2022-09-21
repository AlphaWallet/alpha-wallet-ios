//
//  Coinbase.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 23.08.2022.
//

import Foundation
import Combine

public final class Coinbase: SupportedTokenActionsProvider, BuyTokenURLProviderType {
    public var objectWillChange: AnyPublisher<Void, Never> {
        return .empty()
    }

    public var analyticsName: String { "Coinbase" }
    public let analyticsNavigation: Analytics.Navigation = .onRamp
    public let action: String

    public init(action: String) {
        self.action = action
    }

    public func url(token: TokenActionsIdentifiable, wallet: Wallet) -> URL? {
        guard let platform = token.server.coinbasePlatform else { return nil }
        return Constants.buyWithCoinbaseUrl(blockchain: platform, wallet: wallet).flatMap { URL(string: $0) }
    }

    public func actions(token: TokenActionsIdentifiable) -> [TokenInstanceAction] {
        return [.init(type: .buy(service: self))]
    }

    public func isSupport(token: TokenActionsIdentifiable) -> Bool {
        return token.server.coinbasePlatform != nil
    }

    public func start() {
        //no-op
    }
}
