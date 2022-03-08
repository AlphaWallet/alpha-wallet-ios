//
//  TokenActionsService.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 26.11.2020.
//

import Foundation

struct TokenActionsServiceKey {
    let contractAddress: AlphaWallet.Address
    let server: RPCServer
    var symbol: String
    var decimals: Int
    let type: TokenType

    init(tokenObject: TokenObject) {
        self.contractAddress = tokenObject.contractAddress
        self.server = tokenObject.server
        self.symbol = tokenObject.symbol
        self.decimals = tokenObject.decimals
        self.type = tokenObject.type
    }
}

protocol TokenActionsProvider {
    func isSupport(token: TokenActionsServiceKey) -> Bool
    func actions(token: TokenActionsServiceKey) -> [TokenInstanceAction]
} 

protocol SwapTokenURLProviderType {
    var action: String { get }
    var analyticsName: String { get }

    func rpcServer(forToken token: TokenActionsServiceKey) -> RPCServer?
    func url(token: TokenActionsServiceKey) -> URL?
}

protocol TokenActionsServiceType: TokenActionsProvider {
    func register(service: TokenActionsProvider)
    func service(ofType: TokenActionsProvider.Type) -> TokenActionsProvider?
}

class TokenActionsService: TokenActionsServiceType {
    
    private var services: [TokenActionsProvider] = []

    func register(service: TokenActionsProvider) {
        services.append(service)
    }

    func service(ofType: TokenActionsProvider.Type) -> TokenActionsProvider? {
        return services.first(where: { type(of: $0) == ofType })
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
        case .erc20Token(let token, _, _):
            return TokenActionsServiceKey(tokenObject: token)
        case .erc875Token, .erc875TokenOrder, .erc721Token, .erc721ForTicketToken, .erc1155Token, .dapp, .tokenScript, .claimPaidErc875MagicLink:
            return nil
        }
    }
}
