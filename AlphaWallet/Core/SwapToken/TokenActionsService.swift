//
//  TokenActionsService.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 26.11.2020.
//

import Foundation
import Combine

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

protocol SupportedTokenActionsProvider {
    var objectWillChange: AnyPublisher<Void, Never> { get }

    func isSupport(token: TokenActionsServiceKey) -> Bool
    func actions(token: TokenActionsServiceKey) -> [TokenInstanceAction]
    func start()
} 

protocol TokenActionProvider {
    var action: String { get }
}

class TokenActionsService: SupportedTokenActionsProvider {

    @Published private var services: [SupportedTokenActionsProvider] = []
    private var cancelable = Set<Combine.AnyCancellable>()

    private (set) lazy var objectWillChange: AnyPublisher<Void, Never> = {
        return $services
            .flatMap { Publishers.MergeMany($0.map { $0.objectWillChange }) }
            .map { _ in }
            .eraseToAnyPublisher()
    }()

    func register(service: SupportedTokenActionsProvider) {
        services.append(service)
    }

    func service(ofType: SupportedTokenActionsProvider.Type) -> SupportedTokenActionsProvider? {
        return services.first(where: { type(of: $0) == ofType })
    }

    func actions(token: TokenActionsServiceKey) -> [TokenInstanceAction] {
        services.filter { $0.isSupport(token: token) }.flatMap { $0.actions(token: token) }
    }

    func isSupport(token: TokenActionsServiceKey) -> Bool {
        services.contains { $0.isSupport(token: token) }
    }

    func start() {
        services.forEach { $0.start() }
    }
}

extension TransactionType {
    var swapServiceInputToken: TokenActionsServiceKey? {
        switch self {
        case .nativeCryptocurrency(let token, _, _):
            return TokenActionsServiceKey(tokenObject: token)
        case .erc20Token(let token, _, _):
            return TokenActionsServiceKey(tokenObject: token)
        case .erc875Token, .erc875TokenOrder, .erc721Token, .erc721ForTicketToken, .erc1155Token, .dapp, .tokenScript, .claimPaidErc875MagicLink, .prebuilt:
            return nil
        }
    }
}
