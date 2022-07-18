// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import PromiseKit
import Combine

protocol TokenBalanceService {
    var etherToken: Token { get }
    var ethBalanceViewModel: BalanceViewModel? { get }
    var etherBalance: AnyPublisher<BalanceViewModel?, Never> { get }
    var etherToFiatRatePublisher: AnyPublisher<Double?, Never> { get }
    var etherToFiatRate: Double? { get }

    func start()
    func refresh(refreshBalancePolicy: PrivateBalanceFetcher.RefreshBalancePolicy)
    func coinTicker(_ addressAndRPCServer: AddressAndRPCServer) -> CoinTicker?
    func tokenBalance(_ addressAndRPCServer: AddressAndRPCServer) -> BalanceViewModel?
    func tokenBalancePublisher(_ addressAndRPCServer: AddressAndRPCServer) -> AnyPublisher<BalanceViewModel?, Never>
    func fetchChartHistories(for token: Token, force: Bool, periods: [ChartHistoryPeriod]) -> AnyPublisher<[ChartHistory], Never>
}

class SingleChainTokenBalanceService: NSObject, TokenBalanceService {

    private let wallet: Wallet
    private let server: RPCServer
    private let balanceProvider: TokenBalanceProvider & CoinTickerProvider

    let etherToken: Token

    private (set) lazy var etherToFiatRatePublisher: AnyPublisher<Double?, Never> = {
        return etherBalance
            .map { $0?.ticker?.price_usd }
            .eraseToAnyPublisher()
    }()

    private (set) lazy var etherBalance: AnyPublisher<BalanceViewModel?, Never> = {
        return tokenBalancePublisher(etherToken.addressAndRPCServer)
            .eraseToAnyPublisher()
    }()

    var etherToFiatRate: Double? {
        coinTicker(etherToken.addressAndRPCServer)
            .flatMap { $0.price_usd }
    }

    var ethBalanceViewModel: BalanceViewModel? {
        return tokenBalance(etherToken.addressAndRPCServer)
    }

    init(wallet: Wallet, server: RPCServer, etherToken: Token, tokenBalanceProvider: TokenBalanceProvider & CoinTickerProvider) {
        self.wallet = wallet
        self.etherToken = etherToken
        self.server = server
        self.balanceProvider = tokenBalanceProvider
        super.init()
    }

    func start() {
        //no-op
    }

    func fetchChartHistories(for token: Token, force: Bool, periods: [ChartHistoryPeriod]) -> AnyPublisher<[ChartHistory], Never> {
        return balanceProvider.fetchChartHistories(for: token, force: force, periods: periods)
    }

    func coinTicker(_ addressAndRPCServer: AddressAndRPCServer) -> CoinTicker? {
        balanceProvider.coinTicker(addressAndRPCServer)
    }

    func tokenBalance(_ addressAndRPCServer: AddressAndRPCServer) -> BalanceViewModel? {
        balanceProvider.tokenBalance(addressAndRPCServer, wallet: wallet)
    }

    func tokenBalancePublisher(_ addressAndRPCServer: AddressAndRPCServer) -> AnyPublisher<BalanceViewModel?, Never> {
        balanceProvider.tokenBalancePublisher(addressAndRPCServer, wallet: wallet)
    }

    func refresh(refreshBalancePolicy: PrivateBalanceFetcher.RefreshBalancePolicy) {
        balanceProvider.refreshBalance(updatePolicy: refreshBalancePolicy, wallets: [wallet])
    }
}
