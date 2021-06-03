//
//  TokenActionsService.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 26.11.2020.
//

import UIKit

struct TokenActionsServiceKey {
    let contractAddress: AlphaWallet.Address
    let server: RPCServer
    var symbol: String
    var decimals: Int

    init(tokenObject: TokenObject) {
        self.contractAddress = tokenObject.contractAddress
        self.server = tokenObject.server
        self.symbol = tokenObject.symbol
        self.decimals = tokenObject.decimals
    }
}

protocol TokenActionsProvider {
    func isSupport(token: TokenActionsServiceKey) -> Bool
    func actions(token: TokenActionsServiceKey) -> [TokenInstanceAction]
}

protocol SwapTokenURLProviderType {
    var action: String { get }
    var rpcServer: RPCServer? { get }
    var analyticsName: String { get }
    func url(token: TokenActionsServiceKey) -> URL?
}

protocol TokenActionsServiceType: TokenActionsProvider {
    func register(service: TokenActionsProvider)
}

class TokenActionsService: TokenActionsServiceType {

    private var services: [TokenActionsProvider] = []

    func register(service: TokenActionsProvider) {
        services.append(service)
    }

    func actions(token: TokenActionsServiceKey) -> [TokenInstanceAction] {
        services.filter {
            $0.isSupport(token: token)
        }.flatMap {
            $0.actions(token: token)
        }
    }

    func isSupport(token: TokenActionsServiceKey) -> Bool {
        services.contains { $0.isSupport(token: token) }
    }
}

extension TransactionType {
    var swapServiceInputToken: TokenActionsServiceKey? {
        switch self {
        case .nativeCryptocurrency(let token, _, _):
            return TokenActionsServiceKey(tokenObject: token)
        case .ERC20Token(let token, _, _):
            return TokenActionsServiceKey(tokenObject: token)
        case .ERC875Token, .ERC875TokenOrder, .ERC721Token, .ERC721ForTicketToken, .dapp, .tokenScript, .claimPaidErc875MagicLink:
            return nil
        }
    }
}
