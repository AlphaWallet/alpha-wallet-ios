//
//  xDaiBridge.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 04.10.2021.
//

import Foundation

final class xDaiBridge: TokenActionsProvider, BridgeTokenURLProviderType {
    private static let supportedServer: RPCServer = .xDai

    func isSupport(token: TokenActionsServiceKey) -> Bool {
        switch token.type {
        case .erc1155, .erc20, .erc721, .erc721ForTickets, .erc875:
            return false
        case .nativeCryptocurrency:
            return token.server == xDaiBridge.supportedServer
        }
    }

    func actions(token: TokenActionsServiceKey) -> [TokenInstanceAction] {
        return [.init(type: .bridge(service: self))]
    }

    func rpcServer(forToken token: TokenActionsServiceKey) -> RPCServer? {
        return xDaiBridge.supportedServer
    }

    var action: String {
        return R.string.localizable.aWalletTokenXDaiBridgeButtonTitle()
    }

    var analyticsName: String {
        "xDai Bridge"
    }

    func url(token: TokenActionsServiceKey) -> URL? {
        return Constants.xDaiBridge
    }
}
