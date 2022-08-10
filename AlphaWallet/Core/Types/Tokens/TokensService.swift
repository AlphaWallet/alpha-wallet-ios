//
//  TokensService.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 08.07.2022.
//

import Foundation
import Combine

protocol TokenProvidable {
    func token(for contract: AlphaWallet.Address) -> Token?
    func token(for contract: AlphaWallet.Address, server: RPCServer) -> Token?
    func tokens(for servers: [RPCServer]) -> [Token]
    func tokenPublisher(for contract: AlphaWallet.Address, server: RPCServer) -> AnyPublisher<Token?, Never>
}

protocol TokenAddable {
    @discardableResult func addCustom(tokens: [ERCToken], shouldUpdateBalance: Bool) -> [Token]
}

protocol TokenDetectable {
    var newTokens: AnyPublisher<[Token], Never> { get }
}

protocol TokensState {
    var tokens: [Token] { get }
    //NOTE: as protocol can't be marked as ObservableObject
    var objectWillChange: AnyPublisher<Void, Never> { get }
}

extension TokensState {
    var tokensPublisher: AnyPublisher<[Token], Never> {
        let tokensWhenChanged = objectWillChange.map { _ in tokens }
        return Just(tokens)
            .merge(with: tokensWhenChanged)
            .eraseToAnyPublisher()
    }
}

protocol TokenHidable {
    func mark(token: TokenIdentifiable, isHidden: Bool)
}

protocol TokensServiceTests {
    func setBalanceTestsOnly(balance: Balance, for token: Token)
    func setNftBalanceTestsOnly(_ value: NonFungibleBalance, for token: Token)
    func addOrUpdateTokenTestsOnly(token: Token)
    func deleteTokenTestsOnly(token: Token)
}

protocol PipelineTests: CoinTickersFetcherTests { }

protocol TokenUpdatable {
    func update(token: TokenIdentifiable, value: TokenUpdateAction)
}

protocol TokensService: TokensState, TokenProvidable, TokenAddable, TokenHidable, TokenDetectable, TokenBalanceRefreshable, TokensServiceTests, TokenUpdatable {
    func refresh()
    func start()
}
