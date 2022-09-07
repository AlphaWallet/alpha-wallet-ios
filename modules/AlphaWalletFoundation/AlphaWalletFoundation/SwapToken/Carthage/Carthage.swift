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
        objectWillChangeSubject.eraseToAnyPublisher()
    }
    private var objectWillChangeSubject = PassthroughSubject<Void, Never>()

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
        switch token.server {
        case .candle:
            return true
        case .main, .kovan, .ropsten, .rinkeby, .sokol, .goerli, .artis_sigma1, .artis_tau1, .custom, .poa, .callisto, .xDai, .classic, .arbitrum, .binance_smart_chain, .binance_smart_chain_testnet, .heco, .heco_testnet, .fantom, .fantom_testnet, .avalanche, .avalanche_testnet, .polygon, .mumbai_testnet, .optimistic, .optimisticKovan, .cronosTestnet, .palm, .palmTestnet, .arbitrumRinkeby, .klaytnCypress, .klaytnBaobabTestnet, .phi, .ioTeX, .ioTeXTestnet:
            return false
        }
    }

    public init(action: String) {
        self.action = action
    }

    public func start() {
    }
}
