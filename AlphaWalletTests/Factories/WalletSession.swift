// Copyright SIX DAY LLC. All rights reserved.

import Foundation
@testable import AlphaWallet

extension WalletSession {
    static func make(
        account: Wallet = .make(),
        server: RPCServer = .main,
        config: Config = .make(),
        tokenBalanceService: TokenBalanceService
    ) -> WalletSession {
        return WalletSession(
            account: account,
            server: server,
            config: config,
            tokenBalanceService: tokenBalanceService
        )
    }

    static func make(
        account: Wallet = .make(),
        server: RPCServer = .main,
        config: Config = .make()
    ) -> WalletSession {
        return WalletSession(
            account: account,
            server: server,
            config: config,
            tokenBalanceService: FakeSingleChainTokenBalanceService(wallet: account, server: server)
        )
    }

    static func makeStormBirdSession(
        account: Wallet = .makeStormBird(),
        server: RPCServer,
        config: Config = .make(),
        tokenBalanceService: TokenBalanceService
    ) -> WalletSession {
        return WalletSession(
            account: account,
            server: server,
            config: config,
            tokenBalanceService: FakeSingleChainTokenBalanceService(wallet: account, server: server)
        )
    }
}

import PromiseKit
import Combine

private final class FakeTokenBalanceProvider: TokenBalanceProvider, CoinTickerProvider {
    private var balanceSubject = CurrentValueSubject<Balance?, Never>(nil)

    var balance: Balance? {
        didSet { balanceSubject.value = balance }
    }

    func tokenBalance(_ key: AddressAndRPCServer, wallet: Wallet) -> BalanceBaseViewModel {
        let b: Balance = balance ?? .init(value: .zero)
        return NativecryptoBalanceViewModel(server: key.server, balance: b, ticker: nil)
    }

    func coinTicker(_ addressAndRPCServer: AddressAndRPCServer) -> CoinTicker? {
        return nil
    }

    func tokenBalancePublisher(_ addressAndRPCServer: AddressAndRPCServer, wallet: Wallet) -> AnyPublisher<BalanceBaseViewModel, Never> {
        return balanceSubject
            .map { $0 ?? Balance(value: .zero) }
            .map { NativecryptoBalanceViewModel(server: addressAndRPCServer.server, balance: $0, ticker: nil) }
            .eraseToAnyPublisher()
    }

    func refreshBalance(for wallet: Wallet) -> Promise<Void> {
        return .init()
    }

    func refreshEthBalance(for wallet: Wallet) -> Promise<Void> {
        return .init()
    }

    func refreshBalance(updatePolicy: PrivateBalanceFetcher.RefreshBalancePolicy, force: Bool) -> Promise<Void> {
        return .init()
    }
}

class FakeSingleChainTokenBalanceService: SingleChainTokenBalanceService {
    private let balanceProvider = FakeTokenBalanceProvider()

    var balance: Balance? {
        didSet { balanceProvider.balance = balance }
    }

    init(wallet: Wallet, server: RPCServer) {
        let coinTickersFetcher = FakeCoinTickersFetcher()

        super.init(wallet: wallet, server: server, tokenBalanceProvider: balanceProvider)
    }
}
