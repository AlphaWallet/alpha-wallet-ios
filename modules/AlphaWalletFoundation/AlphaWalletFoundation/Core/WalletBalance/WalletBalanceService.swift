//
//  MultiWalletBalanceService.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 25.05.2021.
//

import Foundation
import BigInt
import Combine
import CombineExt

public protocol TokenBalanceProviderTests {
    func setNftBalanceTestsOnly(_ value: NonFungibleBalance, forToken token: Token, wallet: Wallet)
    func setBalanceTestsOnly(_ value: BigInt, forToken token: Token, wallet: Wallet)
    func deleteTokenTestsOnly(token: Token, wallet: Wallet)
    func addOrUpdateTokenTestsOnly(token: Token, wallet: Wallet)
}

public protocol WalletBalanceService {
    var walletsSummary: AnyPublisher<WalletSummary, Never> { get }

    func walletBalance(for wallet: Wallet) -> AnyPublisher<WalletBalance, Never>
    func refreshBalance(updatePolicy: TokenBalanceFetcher.RefreshBalancePolicy, wallets: [Wallet])
}

open class MultiWalletBalanceService: WalletBalanceService {
    private let walletAddressesStore: WalletAddressesStore
    private var cancelable = Set<AnyCancellable>()
    private let fetchers = CurrentValueSubject<[Wallet: WalletBalanceFetcherType], Never>([:])
    private let dependencyContainer: WalletDependencyContainer
    private let walletsSummarySubject = CurrentValueSubject<WalletSummary, Never>(WalletSummary(balances: []))

    public var walletsSummary: AnyPublisher<WalletSummary, Never> {
        return walletsSummarySubject
            .removeDuplicates()
            .eraseToAnyPublisher()
    }

    public init(walletAddressesStore: WalletAddressesStore, dependencyContainer: WalletDependencyContainer) {
        self.walletAddressesStore = walletAddressesStore
        self.dependencyContainer = dependencyContainer
    }

    public func start() {
        walletAddressesStore
            .walletsPublisher
            .receive(on: RunLoop.main) //NOTE: async to avoid `swift_beginAccess` crash
            .map { [dependencyContainer, weak self] wallets -> [Wallet: WalletBalanceFetcherType] in
                guard let strongSelf = self else { return [:] }
                var fetchers: [Wallet: WalletBalanceFetcherType] = [:]

                for wallet in wallets {
                    if let fetcher = strongSelf.fetchers.value[wallet] {
                        fetchers[wallet] = fetcher
                    } else {
                        let dep = dependencyContainer.makeDependencies(for: wallet)
                        dep.sessionsProvider.start(wallet: wallet)
                        dep.fetcher.start()
                        dep.pipeline.start()

                        fetchers[wallet] = dep.fetcher
                    }
                }

                return fetchers
            }.sink { [weak self, dependencyContainer] newFetchers in
                guard let strongSelf = self else { return }

                let fetchersToDelete = strongSelf.fetchers.value.keys.filter({ !newFetchers.keys.contains($0) })
                for wallet in fetchersToDelete {
                    dependencyContainer.destroy(for: wallet)
                }

                strongSelf.fetchers.send(newFetchers)
            }.store(in: &cancelable)

        fetchers.map { $0.values }
            .flatMapLatest { $0.map { $0.walletBalance }.combineLatest() }
            .map { WalletSummary(balances: $0) }
            .assign(to: \.value, on: walletsSummarySubject, ownership: .weak)
            .store(in: &cancelable)
    }

    ///Refreshes available wallets balances
    public func refreshBalance(updatePolicy: TokenBalanceFetcher.RefreshBalancePolicy, wallets: [Wallet]) {
        for wallet in wallets {
            guard let fetcher = fetchers.value[wallet] else { continue }
            fetcher.refreshBalance(updatePolicy: updatePolicy)
        }
    }

    public func walletBalance(for wallet: Wallet) -> AnyPublisher<WalletBalance, Never> {
        return Just(wallet).combineLatest(fetchers)
            .compactMap { wallet, fetchers in fetchers[wallet] }
            .flatMapLatest { $0.walletBalance }
            .eraseToAnyPublisher()
    }
}
