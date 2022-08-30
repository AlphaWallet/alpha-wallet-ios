//
//  CoinBase.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 23.08.2022.
//

import Foundation
import Combine

final class CoinBase: SupportedTokenActionsProvider, BuyTokenURLProviderType {
    var objectWillChange: AnyPublisher<Void, Never> {
        return .empty()
    }

    var analyticsName: String { "CoinBase" }
    let analyticsNavigation: Analytics.Navigation = .onCoinBase
    let action: String

    init(action: String) {
        self.action = action
    }

    func url(token: TokenActionsIdentifiable, wallet: Wallet) -> URL? {
        guard let platform = token.server.coinBasePlatform else { return nil }
        return Constants.buyWithCoinBaseUrl(blockchain: platform, wallet: wallet).flatMap { URL(string: $0) }
    }

    func actions(token: TokenActionsIdentifiable) -> [TokenInstanceAction] {
        return [.init(type: .buy(service: self))]
    }

    func isSupport(token: TokenActionsIdentifiable) -> Bool {
        return token.server.coinBasePlatform != nil
    }

    func start() {
        //no-op
    } 
}
