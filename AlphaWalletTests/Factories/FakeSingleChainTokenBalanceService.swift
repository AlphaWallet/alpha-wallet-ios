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

    init(wallet: Wallet, server: RPCServer, etherToken: TokenObject) {
        self.wallet = wallet
        balanceService = FakeMultiWalletBalanceService(wallet: wallet, servers: [server])
        super.init(wallet: wallet, server: server, etherToken: etherToken, tokenBalanceProvider: balanceService)
    }

    func triggerUpdateBalanceSubjectTestsOnly(wallet: Wallet) {
        balanceService.triggerUpdateBalanceSubjectTestsOnly(wallet: wallet)
    }

    func setBalanceTestsOnly(balance: Balance, forToken token: TokenObject) {
        balanceService.setBalanceTestsOnly(balance.value, forToken: token, wallet: wallet)
    }

    func addOrUpdateTokenTestsOnly(token: TokenObject) {
        balanceService.addOrUpdateTokenTestsOnly(token: token, wallet: wallet)
    }

    func deleteTokenTestsOnly(token: TokenObject) {
        balanceService.deleteTokenTestsOnly(token: token, wallet: wallet)
    }

    override func refresh(refreshBalancePolicy: PrivateBalanceFetcher.RefreshBalancePolicy) {
        //no-op
    }
}
