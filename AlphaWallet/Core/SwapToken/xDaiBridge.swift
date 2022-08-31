//
//  xDaiBridge.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 04.10.2021.
//

import Foundation
import Combine

final class xDaiBridge: SupportedTokenActionsProvider, BridgeTokenURLProviderType {
    var objectWillChange: AnyPublisher<Void, Never> {
        return .empty()
    }

    private static let supportedServer: RPCServer = .xDai

    func isSupport(token: TokenActionsIdentifiable) -> Bool {
        switch token.type {
        case .erc1155, .erc20, .erc721, .erc721ForTickets, .erc875:
            return false
        case .nativeCryptocurrency:
            return token.server == xDaiBridge.supportedServer
        }
    }

    func actions(token: TokenActionsIdentifiable) -> [TokenInstanceAction] {
        return [.init(type: .bridge(service: self))]
    }

    func rpcServer(forToken token: TokenActionsIdentifiable) -> RPCServer? {
        return xDaiBridge.supportedServer
    }

    let action: String
    let analyticsNavigation: Analytics.Navigation = .onxDaiBridge
    let analyticsName: String = "xDai Bridge"

    func url(token: TokenActionsIdentifiable, wallet: Wallet) -> URL? {
        return Constants.xDaiBridge
    }

    init(action: String) {
        self.action = action
    }

    func start() {
        //no-op
    } 
}
