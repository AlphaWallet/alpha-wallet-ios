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
    func start(fetchers: [Wallet: WalletBalanceFetcherType])
}

open class MultiWalletBalanceService: WalletBalanceService {
    private let fetchers = CurrentValueSubject<[Wallet: WalletBalanceFetcherType], Never>([:])

    public var walletsSummary: AnyPublisher<WalletSummary, Never> {
        fetchers.map { $0.values }
            .flatMapLatest { $0.map { $0.walletBalance }.combineLatest() }
            .map { WalletSummary(balances: $0) }
            .removeDuplicates()
            .prepend(WalletSummary(balances: []))
            .eraseToAnyPublisher()
    }

    public init() { }

    public func start(fetchers: [Wallet: WalletBalanceFetcherType]) {
        self.fetchers.send(fetchers)
    }

    ///Refreshes available wallets balances
    public func refreshBalance(updatePolicy: TokenBalanceFetcher.RefreshBalancePolicy, wallets: [Wallet]) {
        for wallet in wallets {
            guard let fetcher = fetchers.value[wallet] else { continue }
            fetcher.refreshBalance(updatePolicy: updatePolicy)
        }
    }

    public func walletBalance(for wallet: Wallet) -> AnyPublisher<WalletBalance, Never> {
        let walletBalance = fetchers
            .compactMap { fetchers in fetchers[wallet] }
            .flatMapLatest { $0.walletBalance }

        let initial = Just(WalletBalance(wallet: wallet))

        return Publishers.Merge(initial, walletBalance).eraseToAnyPublisher()
    }
}
