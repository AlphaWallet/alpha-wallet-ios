//
//  CoinBase.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 23.08.2022.
//

import Foundation
import Combine

public final class CoinBase: SupportedTokenActionsProvider, BuyTokenURLProviderType {
    public var objectWillChange: AnyPublisher<Void, Never> {
        return .empty()
    }

    public var analyticsName: String { "CoinBase" }
    public let analyticsNavigation: Analytics.Navigation = .onCoinBase
    public let action: String

    public init(action: String) {
        self.action = action
    }

    public func url(token: TokenActionsIdentifiable, wallet: Wallet) -> URL? {
        guard let platform = token.server.coinBasePlatform else { return nil }
        return Constants.buyWithCoinBaseUrl(blockchain: platform, wallet: wallet).flatMap { URL(string: $0) }
    }

    public func actions(token: TokenActionsIdentifiable) -> [TokenInstanceAction] {
        return [.init(type: .buy(service: self))]
    }

    public func isSupport(token: TokenActionsIdentifiable) -> Bool {
        return token.server.coinBasePlatform != nil
    }

    public func start() {
        //no-op
    } 
}
