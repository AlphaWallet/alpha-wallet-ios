//
//  Carthage.swift
//  AlphaWalletFoundation
//
//  Created by Jeffrey Sun on 9/3/22.
//

import Foundation
import Combine

public class Carthage: SupportedTokenActionsProvider, SwapTokenViaUrlProvider {
    public var objectWillChange: AnyPublisher<Void, Never> {
        .empty()
    }

    public let action: String
    private var supportedServers: [RPCServer] {
        return [.candle]
    }

    public func rpcServer(forToken token: TokenActionsIdentifiable) -> RPCServer? {
        if supportedServers.contains(where: { $0 == token.server }) {
            return token.server
        } else {
            return .main
        }
    }
    public let analyticsNavigation: Analytics.Navigation = .onCarthage
    public let analyticsName: String = "Carthage"

    public func url(token: TokenActionsIdentifiable) -> URL? {
        return URL(string: "https://app.carthagedex.com/#/swap?chain=candle")
    }

    public func actions(token: TokenActionsIdentifiable) -> [TokenInstanceAction] {
        return [
            .init(type: .swap(service: self))
        ]
    }

    public func isSupport(token: TokenActionsIdentifiable) -> Bool {
        switch token.server.serverWithEnhancedSupport {
        case .candle:
            return true
        case .main, .xDai, .polygon, .binance_smart_chain, .heco, .arbitrum, .klaytnCypress, .klaytnBaobabTestnet, .rinkeby, nil:
            return false
        }
    }

    public init(action: String) {
        self.action = action
    }

    public func start() {
    }
}
