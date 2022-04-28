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
import RealmSwift

protocol CoinTickerProvider: AnyObject {
    func coinTicker(_ addressAndRPCServer: AddressAndRPCServer) -> CoinTicker?
}

protocol TokenBalanceProviderTests {
    func setBalanceTestsOnly(_ value: BigInt, forToken token: TokenObject, wallet: Wallet)
    func deleteTokenTestsOnly(token: TokenObject, wallet: Wallet)
    func addOrUpdateTokenTestsOnly(token: TokenObject, wallet: Wallet)
}

protocol TokenBalanceProvider: AnyObject, TokenBalanceProviderTests {
    func tokenBalance(_ key: AddressAndRPCServer, wallet: Wallet) -> BalanceBaseViewModel?
    func tokenBalancePublisher(_ addressAndRPCServer: AddressAndRPCServer, wallet: Wallet) -> AnyPublisher<BalanceBaseViewModel?, Never>
    func refreshBalance(updatePolicy: PrivateBalanceFetcher.RefreshBalancePolicy, wallets: [Wallet], force: Bool) -> Promise<Void>
}

protocol WalletBalanceService: TokenBalanceProvider, CoinTickerProvider {
    var walletsSummaryPublisher: AnyPublisher<WalletSummary, Never> { get }
    var walletsSummary: WalletSummary { get }

    func walletBalancePublisher(wallet: Wallet) -> AnyPublisher<WalletBalance, Never>
    func walletBalance(wallet: Wallet) -> WalletBalance
    func start()
}

class MultiWalletBalanceService: NSObject, WalletBalanceService {
    private let keystore: Keystore
    private let config: Config
    let assetDefinitionStore: AssetDefinitionStore
    var coinTickersFetcher: CoinTickersFetcherType
    private var balanceFetchers: [Wallet: WalletBalanceFetcherType] = [:]
    private lazy var walletsSummarySubject: CurrentValueSubject<WalletSummary, Never> = {
        let balances = balanceFetchers.map { $0.value.balance }
        let summary = WalletSummary(balances: balances)
        return .init(summary)
    }()
    private let queue: DispatchQueue = DispatchQueue(label: "com.MultiWalletBalanceService.updateQueue")
    private let walletAddressesStore: WalletAddressesStore
    private var cancelable = Set<AnyCancellable>()
    private let nftProvider: NFTProvider = AlphaWalletNFTProvider()
    
    var walletsSummaryPublisher: AnyPublisher<WalletSummary, Never> {
        return walletsSummarySubject
            .eraseToAnyPublisher()
    }

    var walletsSummary: WalletSummary {
        return walletsSummarySubject.value
    }

    init(keystore: Keystore, config: Config, assetDefinitionStore: AssetDefinitionStore, coinTickersFetcher: CoinTickersFetcherType, walletAddressesStore: WalletAddressesStore) {
        self.keystore = keystore
        self.config = config
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

                //NOTE: we need to remove all balance fetcher for deleted wallets
                let handlertToDelete = strongSelf.balanceFetchers.filter { !wallets.contains($0.key) }
                for value in handlertToDelete {
                    strongSelf.balanceFetchers.removeValue(forKey: value.key)
                }

                strongSelf.notifyWalletsSummary()
            }.store(in: &cancelable)

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

    func tokenBalance(_ key: AddressAndRPCServer, wallet: Wallet) -> BalanceBaseViewModel? {
        return getOrCreateBalanceFetcher(for: wallet)
            .tokenBalance(key)
    }

    func tokenBalancePublisher(_ addressAndRPCServer: AddressAndRPCServer, wallet: Wallet) -> AnyPublisher<BalanceBaseViewModel?, Never> {
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
    func refreshBalance(updatePolicy: PrivateBalanceFetcher.RefreshBalancePolicy, wallets: [Wallet], force: Bool) -> Promise<Void> {
        let promises = wallets.map { wallet in
            return getOrCreateBalanceFetcher(for: wallet)
                .refreshBalance(updatePolicy: updatePolicy, force: force)
        }
        return when(resolved: promises).asVoid()
    }

    func start() {
        fetchTokenPrices()
    }

    //NOTE: for case if we disable rpc server, we don't fetch ticker for its native crypto
    private static var nativeCryptoForAllChains: [Activity.AssignedToken] {
        return RPCServer.allCases.map { server in
            Activity.AssignedToken.init(tokenObject: MultipleChainsTokensDataStore.functional.etherToken(forServer: server))
        }
    }

    private var availableTokenObjects: Promise<ServerDictionary<[TokenMappedToTicker]>> {
        Promise<[Activity.AssignedToken]> { seal in
            DispatchQueue.main.async { [weak self] in
                guard let strongSelf = self else { return seal.reject(PMKError.cancelled) }
                let tokenObjects = strongSelf.balanceFetchers.map { $0.value.tokenObjects }.flatMap { $0 }

                seal.fulfill(tokenObjects + Self.nativeCryptoForAllChains)
            }
        }.map(on: queue, { objects -> ServerDictionary<[TokenMappedToTicker]> in
            let tokenObjects = objects.filter { !$0.server.isTestnet }
            let uniqueTokenObjectsOfAllWallets = Set(tokenObjects)

            var tokens = ServerDictionary<[TokenMappedToTicker]>()

            for each in uniqueTokenObjectsOfAllWallets {
                var array: [TokenMappedToTicker]
                if let value = tokens[safe: each.server] {
                    array = value
                } else {
                    array = .init()
                }

                array.append(TokenMappedToTicker(token: each))

                tokens[each.server] = array
            }
            return tokens
        })
    }

    /// NOTE: internal for test ourposes
    func createWalletBalanceFetcher(wallet: Wallet) -> WalletBalanceFetcherType {
        let realm: Realm = Wallet.functional.realm(forAccount: wallet)
        let tokensDataStore = MultipleChainsTokensDataStore(realm: realm, servers: config.enabledServers)
        let transactionsStorage = TransactionDataStore(realm: realm)
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

    private func fetchTokenPrices() {
        firstly {
            availableTokenObjects
        }.then(on: queue, { values -> Promise<Void> in
            self.coinTickersFetcher.fetchPrices(forTokens: values.values.flatMap({ $0 }))
        }).done(on: queue, { _ in
            //no-op
        }).catch({ e in
            error(value: e)
        })
    }

    private func notifyWalletsSummary() {
        let balances = balanceFetchers.map { $0.value.balance }
        walletsSummarySubject.value = WalletSummary(balances: balances)
    }
}

extension MultiWalletBalanceService {
    func setBalanceTestsOnly(_ value: BigInt, forToken token: TokenObject, wallet: Wallet) {
        getOrCreateBalanceFetcher(for: wallet)
            .setBalanceTestsOnly(value, forToken: token)
    }

    func deleteTokenTestsOnly(token: TokenObject, wallet: Wallet) {
        getOrCreateBalanceFetcher(for: wallet)
            .deleteTokenTestsOnly(token: token)
    }

    func addOrUpdateTokenTestsOnly(token: TokenObject, wallet: Wallet) {
        getOrCreateBalanceFetcher(for: wallet)
            .addOrUpdateTokenTestsOnly(token: token)
    }
}

extension MultiWalletBalanceService: WalletBalanceFetcherDelegate {

    func didAddToken(in fetcher: WalletBalanceFetcherType) {
        fetchTokenPrices()
    }

    func didUpdate(in fetcher: WalletBalanceFetcherType) {
        notifyWalletsSummary()
    }
}

extension Wallet: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(address.eip55String)
    }
}
