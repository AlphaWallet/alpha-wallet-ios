// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import Combine

protocol TokenBalanceService {
    var etherToken: TokenObject { get }
    var ethBalanceViewModel: BalanceBaseViewModel? { get }
    var etherBalance: AnyPublisher<BalanceBaseViewModel?, Never> { get }
    var etherToFiatRatePublisher: AnyPublisher<Double?, Never> { get }
    var etherToFiatRate: Double? { get }

    func start()
    func refresh(refreshBalancePolicy: PrivateBalanceFetcher.RefreshBalancePolicy)
    func coinTicker(_ addressAndRPCServer: AddressAndRPCServer) -> CoinTicker?
    func tokenBalance(_ addressAndRPCServer: AddressAndRPCServer) -> BalanceBaseViewModel?
    func tokenBalancePublisher(_ addressAndRPCServer: AddressAndRPCServer) -> AnyPublisher<BalanceBaseViewModel?, Never>
}

class SingleChainTokenBalanceService: NSObject, TokenBalanceService {
    private let wallet: Wallet
    private let server: RPCServer
    private let balanceProvider: TokenBalanceProvider & CoinTickerProvider

    let etherToken: TokenObject

    private (set) lazy var etherToFiatRatePublisher: AnyPublisher<Double?, Never> = {
        return etherBalance
            .map { $0?.ticker?.price_usd }
            .eraseToAnyPublisher()
    }()

    private (set) lazy var etherBalance: AnyPublisher<BalanceBaseViewModel?, Never> = {
        return tokenBalancePublisher(etherToken.addressAndRPCServer)
            .eraseToAnyPublisher()
    }()

    var etherToFiatRate: Double? {
        coinTicker(etherToken.addressAndRPCServer)
            .flatMap { $0.price_usd }
    }

    var ethBalanceViewModel: BalanceBaseViewModel? {
        return tokenBalance(etherToken.addressAndRPCServer)
    }

    init(wallet: Wallet, server: RPCServer, etherToken: TokenObject, tokenBalanceProvider: TokenBalanceProvider & CoinTickerProvider) {
        self.wallet = wallet
        self.etherToken = etherToken
        self.server = server
        self.balanceProvider = tokenBalanceProvider
        super.init()
    }

    func start() {
        //no-op
    }

    func coinTicker(_ addressAndRPCServer: AddressAndRPCServer) -> CoinTicker? {
        balanceProvider.coinTicker(addressAndRPCServer)
    }

    func tokenBalance(_ addressAndRPCServer: AddressAndRPCServer) -> BalanceBaseViewModel? {
        balanceProvider.tokenBalance(addressAndRPCServer, wallet: wallet)
    }

    func tokenBalancePublisher(_ addressAndRPCServer: AddressAndRPCServer) -> AnyPublisher<BalanceBaseViewModel?, Never> {
        balanceProvider.tokenBalancePublisher(addressAndRPCServer, wallet: wallet)
    }

    func refresh(refreshBalancePolicy: PrivateBalanceFetcher.RefreshBalancePolicy) {
        balanceProvider.refreshBalance(updatePolicy: refreshBalancePolicy, wallets: [wallet])
    }
}
