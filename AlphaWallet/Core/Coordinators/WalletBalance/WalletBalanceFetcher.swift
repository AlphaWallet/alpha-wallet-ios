//
//  WalletBalanceFetcherType.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 28.05.2021.
//

import UIKit 
import BigInt
import Combine

protocol WalletBalanceFetcherTypeTests {
    func setNftBalanceTestsOnly(_ value: NonFungibleBalance, forToken token: Token)
    func setBalanceTestsOnly(_ value: BigInt, forToken token: Token)
    func deleteTokenTestsOnly(token: Token)
    func addOrUpdateTokenTestsOnly(token: Token)
}

protocol WalletBalanceFetcherType: AnyObject {
    var walletBalance: AnyPublisher<WalletBalance, Never> { get }

    func start()
    func refreshBalance(updatePolicy: TokenBalanceFetcher.RefreshBalancePolicy)
}

class WalletBalanceFetcher: NSObject, WalletBalanceFetcherType {
    private static let updateBalanceInterval: TimeInterval = 60
    private var timer: Timer?
    private let wallet: Wallet
    private var cancelable = Set<AnyCancellable>()
    private lazy var walletBalanceSubject: CurrentValueSubject<WalletBalance, Never> = .init(.init(wallet: wallet, tokens: []))
    private let tokensService: TokenViewModelState & TokenBalanceRefreshable

    var walletBalance: AnyPublisher<WalletBalance, Never> {
        return walletBalanceSubject
            .eraseToAnyPublisher()
    }

    init(wallet: Wallet, tokensService: TokenViewModelState & TokenBalanceRefreshable) {
        self.wallet = wallet
        self.tokensService = tokensService
        super.init()
    }

    func start() {
        cancelable.cancellAll()

        tokensService.tokenViewModels
            .map { [wallet] in WalletBalance(wallet: wallet, tokens: $0) }
            .removeDuplicates()
            .assign(to: \.value, on: walletBalanceSubject)
            .store(in: &cancelable)

        guard !isRunningTests() else { return }

        timer = Timer.scheduledTimer(withTimeInterval: Self.updateBalanceInterval, repeats: true) { [weak self] _ in
            self?.refreshBalance(updatePolicy: .all)
        }
    }

    deinit {
        self.stop()
    }

    func refreshBalance(updatePolicy: TokenBalanceFetcher.RefreshBalancePolicy) {
        tokensService.refreshBalance(updatePolicy: updatePolicy)
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }
}
