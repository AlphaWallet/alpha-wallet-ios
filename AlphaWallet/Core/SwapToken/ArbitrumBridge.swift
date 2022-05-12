//
//  ArbitrumBridge.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 04.10.2021.
//

import Foundation
import Combine

typealias BridgeTokenURLProviderType = BuyTokenURLProviderType

final class ArbitrumBridge: SupportedTokenActionsProvider, BridgeTokenURLProviderType {
    var objectWillChange: AnyPublisher<Void, Never> {
        return Empty<Void, Never>(completeImmediately: true).eraseToAnyPublisher()
    }

    private static let supportedServer: RPCServer = .main

    func isSupport(token: TokenActionsServiceKey) -> Bool {
        switch token.type {
        case .erc1155, .erc721, .erc721ForTickets, .erc875:
            return false
        case .nativeCryptocurrency, .erc20:
            //NOTE: we are not pretty sure what tokens it supports, so let assume for all
            return token.server == ArbitrumBridge.supportedServer
        }
    }

    func actions(token: TokenActionsServiceKey) -> [TokenInstanceAction] {
        return [.init(type: .bridge(service: self))]
    }

    func rpcServer(forToken token: TokenActionsServiceKey) -> RPCServer? {
        return ArbitrumBridge.supportedServer
    }

    var action: String {
        return R.string.localizable.aWalletTokenArbitrumBridgeButtonTitle()
    }

    var analyticsName: String {
        "Arbitrum Bridge"
    }

    func url(token: TokenActionsServiceKey) -> URL? {
        return Constants.arbitrumBridge
    }

    func start() {
        //no-op
    }
}
