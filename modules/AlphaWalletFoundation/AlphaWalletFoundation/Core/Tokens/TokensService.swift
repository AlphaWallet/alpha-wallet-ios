//
//  TokensService.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 08.07.2022.
//

import Foundation
import Combine

public protocol TokenProvidable {
    func token(for contract: AlphaWallet.Address) -> Token?
    func token(for contract: AlphaWallet.Address, server: RPCServer) -> Token?
    func tokens(for servers: [RPCServer]) -> [Token]

    func tokenPublisher(for contract: AlphaWallet.Address, server: RPCServer) -> AnyPublisher<Token?, Never>
    func tokensPublisher(servers: [RPCServer]) -> AnyPublisher<[Token], Never>
}

public protocol TokenAddable {
    func add(tokenUpdates updates: [TokenUpdate])
    @discardableResult func addCustom(tokens: [ERCToken], shouldUpdateBalance: Bool) -> [Token]
    @discardableResult func addOrUpdate(tokensOrContracts: [TokenOrContract]) -> [Token]
    @discardableResult func addOrUpdate(_ actions: [AddOrUpdateTokenAction]) -> Bool?
}

public protocol TokenAutoDetectable {
    var newTokens: AnyPublisher<[Token], Never> { get }
}

public protocol TokensState {
    var tokens: [Token] { get }
    var tokensPublisher: AnyPublisher<[Token], Never> { get }
}

public protocol TokenHidable {
    func mark(token: TokenIdentifiable, isHidden: Bool)
}

public protocol TokensServiceTests {
    func setBalanceTestsOnly(balance: Balance, for token: Token)
    func setNftBalanceTestsOnly(_ value: NonFungibleBalance, for token: Token)
    func addOrUpdateTokenTestsOnly(token: Token)
    func deleteTokenTestsOnly(token: Token)
}

public protocol PipelineTests: CoinTickersFetcherTests { }

public protocol TokenUpdatable {
    func update(token: TokenIdentifiable, value: TokenUpdateAction)
    @discardableResult func updateToken(primaryKey: String, action: TokenUpdateAction) -> Bool?
}

public protocol TokensService: TokensState, TokenProvidable, TokenAddable, TokenHidable, TokenAutoDetectable, TokenBalanceRefreshable, TokensServiceTests, TokenUpdatable, DetectedContractsProvideble {
    func refresh()
    func start()
    func stop()
}
