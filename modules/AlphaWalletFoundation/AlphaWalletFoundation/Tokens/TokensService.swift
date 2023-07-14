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
    var tokens: [Token] { get }
    var tokensPublisher: AnyPublisher<[Token], Never> { get }
    var addedTokensPublisher: AnyPublisher<[Token], Never> { get }
    var providersHasChanged: AnyPublisher<Void, Never> { get }

    func token(for contract: AlphaWallet.Address) -> Token?
    func token(for contract: AlphaWallet.Address, server: RPCServer) -> Token?
    func tokens(for servers: [RPCServer]) -> [Token]
    func tokenPublisher(for contract: AlphaWallet.Address, server: RPCServer) -> AnyPublisher<Token?, Never>
    func tokensChangesetPublisher(servers: [RPCServer]) -> AnyPublisher<ChangeSet<[Token]>, Never>

    func refresh()
    func start()
    func stop()
    func mark(token: TokenIdentifiable, isHidden: Bool)
    func setBalanceTestsOnly(balance: Balance, for token: Token)
    func setNftBalanceTestsOnly(_ value: NonFungibleBalance, for token: Token)
    func addOrUpdateTokenTestsOnly(token: Token)
    func deleteTokenTestsOnly(token: Token)
    func refreshBalance(updatePolicy: TokenBalanceFetcher.RefreshBalancePolicy)
    @discardableResult func addOrUpdate(with actions: [AddOrUpdateTokenAction]) -> [Token]
    func update(token: TokenIdentifiable, value: TokenFieldUpdate)
    @discardableResult func updateToken(primaryKey: String, action: TokenFieldUpdate) -> Bool?

    func alreadyAddedContracts(for server: RPCServer) -> [AlphaWallet.Address]
    func deletedContracts(for server: RPCServer) -> [AlphaWallet.Address]
    func hiddenContracts(for server: RPCServer) -> [AlphaWallet.Address]
    func delegateContracts(for server: RPCServer) -> [AlphaWallet.Address]
}
