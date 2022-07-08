//
//  FakeSingleChainTokenBalanceService.swift
//  AlphaWalletTests
//
//  Created by Vladyslav Shepitko on 11.05.2022.
//

@testable import AlphaWallet

class FakeSingleChainTokenBalanceService: SingleChainTokenBalanceService {
    private let balanceService: FakeMultiWalletBalanceService
    private let wallet: Wallet

    var tokensDataStore: TokensDataStore {
        balanceService.tokensDataStore
    }

    init(wallet: Wallet, server: RPCServer, etherToken: Token) {
        self.wallet = wallet
        balanceService = FakeMultiWalletBalanceService(wallet: wallet, servers: [server])
        super.init(wallet: wallet, server: server, etherToken: etherToken, tokenBalanceProvider: balanceService)
    }

    func triggerUpdateBalanceSubjectTestsOnly(wallet: Wallet) {
        balanceService.triggerUpdateBalanceSubjectTestsOnly(wallet: wallet)
    }

    func setBalanceTestsOnly(balance: Balance, forToken token: Token) {
        balanceService.setBalanceTestsOnly(balance.value, forToken: token, wallet: wallet)
    }

    func setNftBalanceTestsOnly(_ value: NonFungibleBalance, forToken token: Token) {
        balanceService.setNftBalanceTestsOnly(value, forToken: token, wallet: wallet)
    }

    func addOrUpdateTokenTestsOnly(token: Token) {
        balanceService.addOrUpdateTokenTestsOnly(token: token, wallet: wallet)
    }

    func deleteTokenTestsOnly(token: Token) {
        balanceService.deleteTokenTestsOnly(token: token, wallet: wallet)
    }

    override func refresh(refreshBalancePolicy: PrivateBalanceFetcher.RefreshBalancePolicy) {
        //no-op
    }
}

extension FakeSingleChainTokenBalanceService: TokenProvidable, TokenAddable {
    func token(for contract: AlphaWallet.Address) -> Token? {
        tokensDataStore.token(forContract: contract)
    }

    func token(for contract: AlphaWallet.Address, server: RPCServer) -> Token? {
        tokensDataStore.token(forContract: contract, server: server)
    }

    func addCustom(tokens: [ERCToken], shouldUpdateBalance: Bool) -> [Token] {
        tokensDataStore.addCustom(tokens: tokens, shouldUpdateBalance: shouldUpdateBalance)
    }
}
