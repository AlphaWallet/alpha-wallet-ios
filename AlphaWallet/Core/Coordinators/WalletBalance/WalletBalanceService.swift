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
}

protocol TokenBalanceProvider: AnyObject {
    func tokenBalance(_ key: AddressAndRPCServer, wallet: Wallet) -> BalanceBaseViewModel
    func tokenBalancePublisher(_ addressAndRPCServer: AddressAndRPCServer, wallet: Wallet) -> AnyPublisher<BalanceBaseViewModel, Never>
    func refreshBalance(for wallet: Wallet) -> Promise<Void>
    func refreshEthBalance(for wallet: Wallet) -> Promise<Void>
    func refreshBalance(updatePolicy: PrivateBalanceFetcher.RefreshBalancePolicy, force: Bool) -> Promise<Void>
}

protocol WalletBalanceService: TokenBalanceProvider, CoinTickerProvider {
    var walletsSummary: AnyPublisher<WalletSummary, Never> { get }

    func walletBalance(wallet: Wallet) -> AnyPublisher<WalletBalance, Never>
    func tokenBalancePublisher(_ addressAndRPCServer: AddressAndRPCServer, wallet: Wallet) -> AnyPublisher<BalanceBaseViewModel, Never>
    func start()
    func refreshBalance(for wallet: Wallet) -> Promise<Void>
    func refreshEthBalance(for wallet: Wallet) -> Promise<Void>
    func refreshBalance(updatePolicy: PrivateBalanceFetcher.RefreshBalancePolicy, force: Bool) -> Promise<Void>
}

class MultiWalletBalanceService: NSObject, WalletBalanceService {
    private let keystore: Keystore
    private let config: Config
    private let assetDefinitionStore: AssetDefinitionStore
    private var coinTickersFetcher: CoinTickersFetcherType
    private var balanceFetchers: [Wallet: WalletBalanceFetcherType] = [:]
    private lazy var walletsSummarySubject: CurrentValueSubject<WalletSummary, Never> = {
        let balances = balanceFetchers.map { $0.value.balance }
        let summary = WalletSummary(balances: balances)
        return .init(summary)
    }()
    private let queue: DispatchQueue = DispatchQueue(label: "com.MultiWalletBalanceService.updateQueue")
    private let walletAddressesStore: WalletAddressesStore
    private var cancelable = Set<AnyCancellable>()
    private let nftProvider: NFTProvider = OpenSea()
    
    var walletsSummary: AnyPublisher<WalletSummary, Never> {
        return walletsSummarySubject
            .eraseToAnyPublisher()
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
    }

    func tokenBalance(_ key: AddressAndRPCServer, wallet: Wallet) -> BalanceBaseViewModel {
        return getOrCreateBalanceFetcher(for: wallet)
            .tokenBalance(key)
    }

    func tokenBalancePublisher(_ addressAndRPCServer: AddressAndRPCServer, wallet: Wallet) -> AnyPublisher<BalanceBaseViewModel, Never> {
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

    func refreshBalance(for wallet: Wallet) -> Promise<Void> {
        return getOrCreateBalanceFetcher(for: wallet)
            .refreshBalance()
    }

    func refreshEthBalance(for wallet: Wallet) -> Promise<Void> {
        return getOrCreateBalanceFetcher(for: wallet)
            .refreshEthBalance()
    }

    ///Refreshes available wallets balances
    func refreshBalance(updatePolicy: PrivateBalanceFetcher.RefreshBalancePolicy, force: Bool) -> Promise<Void> {
        let promises = keystore.wallets.map { wallet in
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

    private func createWalletBalanceFetcher(wallet: Wallet) -> WalletBalanceFetcherType {
        let fetcher = WalletBalanceFetcher(wallet: wallet, nftProvider: nftProvider, config: config, assetDefinitionStore: assetDefinitionStore, queue: queue, coinTickersFetcher: coinTickersFetcher)
        fetcher.delegate = self

        return fetcher
    }

    func walletBalance(wallet: Wallet) -> AnyPublisher<WalletBalance, Never> {
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
