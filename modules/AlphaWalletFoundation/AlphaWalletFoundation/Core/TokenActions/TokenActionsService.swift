//
//  TokenActionsService.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 26.11.2020.
//

import Foundation
import Combine

public protocol TokenActionsIdentifiable {
    var contractAddress: AlphaWallet.Address { get }
    var server: RPCServer { get }
    var symbol: String { get }
    var decimals: Int { get }
    var type: TokenType { get }
}

public protocol SupportedTokenActionsProvider {
    var analyticsNavigation: Analytics.Navigation { get }
    var analyticsName: String { get }
    var objectWillChange: AnyPublisher<Void, Never> { get }

    func isSupport(token: TokenActionsIdentifiable) -> Bool
    func actions(token: TokenActionsIdentifiable) -> [TokenInstanceAction]
    func start()
} 

public protocol TokenActionProvider {
    var action: String { get }
}

open class TokenActionsService: SupportedTokenActionsProvider, TokenActionServiceProvidable {
    @Published private var services: [SupportedTokenActionsProvider] = []
    private var cancelable = Set<Combine.AnyCancellable>()

    private (set) lazy public var objectWillChange: AnyPublisher<Void, Never> = {
        return $services
            .flatMap { Publishers.MergeMany($0.map { $0.objectWillChange }) }
            .mapToVoid()
            .eraseToAnyPublisher()
    }()

    public let analyticsName: String = "Token Actions"
    public let analyticsNavigation: Analytics.Navigation = .fallback

    public init() {}

    public func register(service: SupportedTokenActionsProvider) {
        services.append(service)
    }

    public func service(ofType: SupportedTokenActionsProvider.Type) -> SupportedTokenActionsProvider? {
        return services.first(where: { type(of: $0) == ofType })
    }

    public func actions(token: TokenActionsIdentifiable) -> [TokenInstanceAction] {
        services.filter { $0.isSupport(token: token) }.flatMap { $0.actions(token: token) }
    }

    public func isSupport(token: TokenActionsIdentifiable) -> Bool {
        services.contains { $0.isSupport(token: token) }
    }

    public func start() {
        services.forEach { $0.start() }
    }
}

extension TransactionType {
    public var swapServiceInputToken: TokenActionsIdentifiable? {
        switch self {
        case .nativeCryptocurrency(let token, _, _):
            return token
        case .erc20Token(let token, _, _):
            return token
        case .erc875Token, .erc875TokenOrder, .erc721Token, .erc721ForTicketToken, .erc1155Token, .dapp, .tokenScript, .claimPaidErc875MagicLink, .prebuilt:
            return nil
        }
    }
}
