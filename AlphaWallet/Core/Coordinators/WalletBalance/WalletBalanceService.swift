//
//  MultiWalletBalanceService.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 25.05.2021.
//

import UIKit
import BigInt
import PromiseKit
import Combine

protocol CoinTickerProvider: AnyObject {
    func coinTicker(_ addressAndRPCServer: AddressAndRPCServer) -> CoinTicker?
    func fetchChartHistories(_ addressToRPCServerKey: AddressAndRPCServer, force: Bool, periods: [ChartHistoryPeriod]) -> Promise<[ChartHistory]>
}

protocol TokenBalanceProviderTests {
    func setNftBalanceTestsOnly(_ value: [String], forToken token: Token, wallet: Wallet)
    func setBalanceTestsOnly(_ value: BigInt, forToken token: Token, wallet: Wallet)
    func deleteTokenTestsOnly(token: Token, wallet: Wallet)
    func addOrUpdateTokenTestsOnly(token: Token, wallet: Wallet)
}

protocol TokenBalanceProvider: AnyObject, TokenBalanceProviderTests {
    func tokenBalance(_ key: AddressAndRPCServer, wallet: Wallet) -> BalanceViewModel?
    func tokenBalancePublisher(_ addressAndRPCServer: AddressAndRPCServer, wallet: Wallet) -> AnyPublisher<BalanceViewModel?, Never>
    func refreshBalance(updatePolicy: PrivateBalanceFetcher.RefreshBalancePolicy, wallets: [Wallet])
}

protocol WalletBalanceService: TokenBalanceProvider, CoinTickerProvider {
    var walletsSummaryPublisher: AnyPublisher<WalletSummary, Never> { get }

    func walletBalancePublisher(wallet: Wallet) -> AnyPublisher<WalletBalance, Never>
    func walletBalance(wallet: Wallet) -> WalletBalance
}

class MultiWalletBalanceService: NSObject, WalletBalanceService {
    private let keystore: Keystore
    private let config: Config
    private let analyticsCoordinator: AnalyticsCoordinator
    let assetDefinitionStore: AssetDefinitionStore
    var coinTickersFetcher: CoinTickersFetcherType
    private var balanceFetchers: AtomicDictionary<Wallet, WalletBalanceFetcherType> = .init()
    private lazy var walletsSummarySubject: CurrentValueSubject<WalletSummary, Never> = {
        let balances = balanceFetchers.values.map { $0.value.balance }
        let summary = WalletSummary(balances: balances)
        return .init(summary)
    }()
    private let queue: DispatchQueue = DispatchQueue(label: "org.alphawallet.swift.walletBalance")
    private let walletAddressesStore: WalletAddressesStore
    private var cancelable = Set<AnyCancellable>()
    private lazy var nftProvider: NFTProvider = AlphaWalletNFTProvider(analyticsCoordinator: analyticsCoordinator, queue: queue)

    var walletsSummaryPublisher: AnyPublisher<WalletSummary, Never> {
        return walletsSummarySubject
            .receive(on: RunLoop.main)
            .prepend(walletsSummary)
            .removeDuplicates()
            .eraseToAnyPublisher()
    }

    private var walletsSummary: WalletSummary {
        let balances = balanceFetchers.values.map { $0.value.balance }
        return WalletSummary(balances: balances)
    }
    private let store: LocalStore

    init(store: LocalStore, keystore: Keystore, config: Config, assetDefinitionStore: AssetDefinitionStore, analyticsCoordinator: AnalyticsCoordinator, coinTickersFetcher: CoinTickersFetcherType, walletAddressesStore: WalletAddressesStore) {
        self.store = store
        self.keystore = keystore
        self.config = config
        self.analyticsCoordinator = analyticsCoordinator
        self.assetDefinitionStore = assetDefinitionStore
        self.coinTickersFetcher = coinTickersFetcher
        self.walletAddressesStore = walletAddressesStore
        super.init()

        walletAddressesStore
            .walletsPublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] wallets in
                guard let strongSelf = self else { return }

                for wallet in wallets {
                    strongSelf.getOrCreateBalanceFetcher(for: wallet)
                }
                strongSelf.removeBalanceFetcher(wallets: wallets)

                strongSelf.notifyWalletsSummary()
            }.store(in: &cancelable)

        subscribeForServerUpdates()
    }

    private func subscribeForServerUpdates() {
        config.enabledServersPublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] servers in
                guard let strongSelf = self else { return }

                for wallet in strongSelf.walletAddressesStore.wallets {
                    let fetcher = strongSelf.getOrCreateBalanceFetcher(for: wallet)
                    fetcher.update(servers: servers)
                }
            }.store(in: &cancelable)
    }

    private func removeBalanceFetcher(wallets: Set<Wallet>) {
        //NOTE: we need to remove all balance fetcher for deleted wallets
        let fetchersToDelete = balanceFetchers.values.filter { !wallets.contains($0.key) }
        for value in fetchersToDelete {
            balanceFetchers.removeValue(forKey: value.key)
        }
    }

    func tokenBalance(_ key: AddressAndRPCServer, wallet: Wallet) -> BalanceViewModel? {
        return getOrCreateBalanceFetcher(for: wallet)
            .tokenBalance(key)
    }

    func tokenBalancePublisher(_ addressAndRPCServer: AddressAndRPCServer, wallet: Wallet) -> AnyPublisher<BalanceViewModel?, Never> {
        return getOrCreateBalanceFetcher(for: wallet)
            .tokenBalancePublisher(addressAndRPCServer)
    }

    @discardableResult private func getOrCreateBalanceFetcher(for wallet: Wallet) -> WalletBalanceFetcherType {
        if let fether = balanceFetchers[wallet] {
            return fether
        } else {
            let fether = createWalletBalanceFetcher(wallet: wallet)
            fether.start()

            balanceFetchers[wallet] = fether

            return fether
        }
    }

    func coinTicker(_ addressAndRPCServer: AddressAndRPCServer) -> CoinTicker? {
        return coinTickersFetcher.ticker(for: addressAndRPCServer)
    }

    ///Refreshes available wallets balances
    func refreshBalance(updatePolicy: PrivateBalanceFetcher.RefreshBalancePolicy, wallets: [Wallet]) {
        for wallet in wallets {
            getOrCreateBalanceFetcher(for: wallet)
                .refreshBalance(updatePolicy: updatePolicy)
        }
    }

    func fetchChartHistories(_ addressToRPCServerKey: AddressAndRPCServer, force: Bool, periods: [ChartHistoryPeriod]) -> Promise<[ChartHistory]> {
        return coinTickersFetcher
            .fetchChartHistories(addressToRPCServerKey: addressToRPCServerKey, force: force, periods: periods)
    }

    /// NOTE: internal for test ourposes
    func createWalletBalanceFetcher(wallet: Wallet) -> WalletBalanceFetcherType {
        let tokensDataStore: TokensDataStore = MultipleChainsTokensDataStore(store: store.getOrCreateStore(forWallet: wallet), servers: config.enabledServers)
        let transactionsStorage = TransactionDataStore(store: store.getOrCreateStore(forWallet: wallet))
        let fetcher = WalletBalanceFetcher(wallet: wallet, servers: config.enabledServers, tokensDataStore: tokensDataStore, transactionsStorage: transactionsStorage, nftProvider: nftProvider, config: config, assetDefinitionStore: assetDefinitionStore, queue: queue, coinTickersFetcher: coinTickersFetcher)
        fetcher.delegate = self

        return fetcher
    }

    func walletBalancePublisher(wallet: Wallet) -> AnyPublisher<WalletBalance, Never> {
        return getOrCreateBalanceFetcher(for: wallet)
            .walletBalancePublisher
    }

    func walletBalance(wallet: Wallet) -> WalletBalance {
        return getOrCreateBalanceFetcher(for: wallet)
            .walletBalance
    }

    private func notifyWalletsSummary() {
        queue.async {
            let balances = self.balanceFetchers.values.map { $0.value.balance }
            self.walletsSummarySubject.value = WalletSummary(balances: balances)
        }
    }
}

extension MultiWalletBalanceService {
    func triggerUpdateBalanceSubjectTestsOnly(wallet: Wallet) {
        getOrCreateBalanceFetcher(for: wallet)
            .triggerUpdateBalanceSubjectTestsOnly()
    }

    func setBalanceTestsOnly(_ value: BigInt, forToken token: Token, wallet: Wallet) {
        getOrCreateBalanceFetcher(for: wallet)
            .setBalanceTestsOnly(value, forToken: token)
    }

    func setNftBalanceTestsOnly(_ value: [String], forToken token: Token, wallet: Wallet) {
        getOrCreateBalanceFetcher(for: wallet)
            .setNftBalanceTestsOnly(value, forToken: token)
    }

    func deleteTokenTestsOnly(token: Token, wallet: Wallet) {
        getOrCreateBalanceFetcher(for: wallet)
            .deleteTokenTestsOnly(token: token)
    }

    func addOrUpdateTokenTestsOnly(token: Token, wallet: Wallet) {
        getOrCreateBalanceFetcher(for: wallet)
            .addOrUpdateTokenTestsOnly(token: token)
    }
}

extension MultiWalletBalanceService: WalletBalanceFetcherDelegate {

    func didUpdate(in fetcher: WalletBalanceFetcherType) {
        notifyWalletsSummary()
    }
}

extension Wallet: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(address.eip55String)
    }
}
