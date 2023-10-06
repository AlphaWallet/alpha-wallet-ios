//
//  TokensService.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 08.07.2022.
//

import Foundation
import Combine
import AlphaWalletWeb3

public protocol TokensService {
    var tokens: [Token] { get async }
    var tokensPublisher: AnyPublisher<[Token], Never> { get }
    var addedTokensPublisher: AnyPublisher<[Token], Never> { get }
    var providersHasChanged: AnyPublisher<Void, Never> { get }

    func token(for contract: AlphaWallet.Address) async -> Token?
    func token(for contract: AlphaWallet.Address, server: RPCServer) async -> Token?
    func tokens(for servers: [RPCServer]) async -> [Token]
    func tokenPublisher(for contract: AlphaWallet.Address, server: RPCServer) -> AnyPublisher<Token?, Never>
    func tokensChangesetPublisher(servers: [RPCServer]) -> AnyPublisher<ChangeSet<[Token]>, Never>

    func refresh()
    func start()
    func stop()
    func mark(token: TokenIdentifiable, isHidden: Bool)
    @discardableResult func setBalanceTestsOnly(balance: Balance, for token: Token) -> Task<Bool?, Never>
    @discardableResult func setNftBalanceTestsOnly(_ value: NonFungibleBalance, for token: Token) -> Task<Bool?, Never>
    @discardableResult func addOrUpdateTokenTestsOnly(token: Token) -> Task<[Token], Never>
    func deleteTokenTestsOnly(token: Token)
    func refreshBalance(updatePolicy: TokenBalanceFetcher.RefreshBalancePolicy)
    @discardableResult func addOrUpdate(with actions: [AddOrUpdateTokenAction]) async -> [Token]
    func update(token: TokenIdentifiable, value: TokenFieldUpdate)
    @discardableResult func updateToken(primaryKey: String, action: TokenFieldUpdate) async -> Bool?

    func alreadyAddedContracts(for server: RPCServer) async -> [AlphaWallet.Address]
    func deletedContracts(for server: RPCServer) async -> [AlphaWallet.Address]
    func hiddenContracts(for server: RPCServer) async -> [AlphaWallet.Address]
    func delegateContracts(for server: RPCServer) async -> [AlphaWallet.Address]
}
