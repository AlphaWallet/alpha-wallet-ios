//
//  TokenActionsService.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 26.11.2020.
//

import UIKit

protocol TokenActionsProvider {
    func isSupport(token: TokenObject) -> Bool
    func actions(token: TokenObject) -> [TokenInstanceAction]
}

protocol SwapTokenURLProviderType {
    var action: String { get }
    var rpcServer: RPCServer? { get }
    var analyticsName: String { get }
    func url(token: TokenObject) -> URL?
}

protocol TokenActionsServiceType: TokenActionsProvider {
    func register(service: TokenActionsProvider)
}

class TokenActionsService: TokenActionsServiceType {

    private var services: [TokenActionsProvider] = []

    func register(service: TokenActionsProvider) {
        services.append(service)
    }

    func actions(token: TokenObject) -> [TokenInstanceAction] {
        services.filter {
            $0.isSupport(token: token)
        }.flatMap {
            $0.actions(token: token)
        }
    }

    func isSupport(token: TokenObject) -> Bool {
        services.contains { $0.isSupport(token: token) }
    }
}

extension TransactionType {
    var swapServiceInputToken: TokenObject? {
        switch self {
        case .nativeCryptocurrency(let token, _, _):
            return token
        case .ERC20Token(let token, _, _):
            return token
        case .ERC875Token, .ERC875TokenOrder, .ERC721Token, .ERC721ForTicketToken, .dapp, .tokenScript, .claimPaidErc875MagicLink:
            return nil
        }
    }
}
