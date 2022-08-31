//
//  ArbitrumBridge.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 04.10.2021.
//

import Foundation
import Combine

public typealias BridgeTokenURLProviderType = BuyTokenURLProviderType

public final class ArbitrumBridge: SupportedTokenActionsProvider, BridgeTokenURLProviderType {
    public var objectWillChange: AnyPublisher<Void, Never> {
        return .empty()
    }

    private static let supportedServer: RPCServer = .main

    public func isSupport(token: TokenActionsIdentifiable) -> Bool {
        switch token.type {
        case .erc1155, .erc721, .erc721ForTickets, .erc875:
            return false
        case .nativeCryptocurrency, .erc20:
            //NOTE: we are not pretty sure what tokens it supports, so let assume for all
            return token.server == ArbitrumBridge.supportedServer
        }
    }

    public func actions(token: TokenActionsIdentifiable) -> [TokenInstanceAction] {
        return [.init(type: .bridge(service: self))]
    }

    func rpcServer(forToken token: TokenActionsIdentifiable) -> RPCServer? {
        return ArbitrumBridge.supportedServer
    }

    public let action: String
    public let analyticsNavigation: Analytics.Navigation = .onArbitrumBridge
    public let analyticsName: String = "Arbitrum Bridge"

    public init(action: String) {
        self.action = action
    }
    public func url(token: TokenActionsIdentifiable, wallet: Wallet) -> URL? {
        return Constants.arbitrumBridge
    }

    public func start() {
        //no-op
    } 
}
