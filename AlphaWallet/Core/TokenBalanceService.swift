// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import Combine

protocol TokenBalanceService {
    var etherToken: TokenObject { get }
    var ethBalanceViewModel: BalanceBaseViewModel { get }
    var etherBalance: AnyPublisher<BalanceBaseViewModel, Never> { get }
    var etherToFiatRatePublisher: AnyPublisher<Double?, Never> { get }
    var etherToFiatRate: Double? { get }

    func refresh()
    func refreshEthBalance()
    func coinTicker(_ addressAndRPCServer: AddressAndRPCServer) -> CoinTicker?
    func tokenBalancePublisher(_ addressAndRPCServer: AddressAndRPCServer) -> AnyPublisher<BalanceBaseViewModel, Never>
}

class SingleChainTokenBalanceService: NSObject, TokenBalanceService {
    private let wallet: Wallet
    private let server: RPCServer
    private var emptyEtherBalance: BalanceBaseViewModel {
        return balanceProvider.tokenBalance(etherToken.addressAndRPCServer, wallet: wallet)
    }
    private let balanceProvider: TokenBalanceProvider & CoinTickerProvider
    private var cancelable = Set<AnyCancellable>()
    private lazy var etherBalanceSubject: CurrentValueSubject<BalanceBaseViewModel, Never> = .init(emptyEtherBalance)

    private (set) lazy var etherToken: TokenObject = {
        return MultipleChainsTokensDataStore.functional.etherToken(forServer: server)
    }()

    private (set) lazy var etherToFiatRatePublisher: AnyPublisher<Double?, Never> = {
        return etherBalance
            .map { $0.ticker?.price_usd }
            .eraseToAnyPublisher()
    }()

    private (set) lazy var etherBalance: AnyPublisher<BalanceBaseViewModel, Never> = {
        return etherBalanceSubject
            .eraseToAnyPublisher()
    }()

    var etherToFiatRate: Double? {
        coinTicker(etherToken.addressAndRPCServer)
            .flatMap { $0.price_usd }
    }

    var ethBalanceViewModel: BalanceBaseViewModel {
        return etherBalanceSubject.value
    }

    init(wallet: Wallet, server: RPCServer, tokenBalanceProvider: TokenBalanceProvider & CoinTickerProvider) {
        self.wallet = wallet
        self.server = server
        self.balanceProvider = tokenBalanceProvider
        super.init()

        tokenBalancePublisher(etherToken.addressAndRPCServer)
            .assign(to: \.value, on: etherBalanceSubject)
            .store(in: &cancelable)
    }

    func coinTicker(_ addressAndRPCServer: AddressAndRPCServer) -> CoinTicker? {
        balanceProvider.coinTicker(addressAndRPCServer)
    } 

    func tokenBalancePublisher(_ addressAndRPCServer: AddressAndRPCServer) -> AnyPublisher<BalanceBaseViewModel, Never> {
        balanceProvider.tokenBalancePublisher(addressAndRPCServer, wallet: wallet)
    }

    func refresh() {
        balanceProvider.refreshBalance(for: wallet).done { _ in
            //no-op
        }.cauterize()
    }

    func refreshEthBalance() {
        balanceProvider.refreshEthBalance(for: wallet).done { _ in
            //no-op
        }.cauterize()
    }
}
