//
//  WalletBalanceFetcherType.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 28.05.2021.
//

import Foundation
import BigInt
import Combine

public protocol WalletBalanceFetcherType: AnyObject {
    var walletBalance: AnyPublisher<WalletBalance, Never> { get }

    func start()
    func refreshBalance(updatePolicy: TokenBalanceFetcher.RefreshBalancePolicy)
}

public class WalletBalanceFetcher: NSObject, WalletBalanceFetcherType {
    private static let updateBalanceInterval: TimeInterval = 60
    private var timer: Timer?
    private let wallet: Wallet
    private var cancelable = Set<AnyCancellable>()
    private let tokensPipeline: TokensProcessingPipeline
    private let tokensService: TokensService
    private lazy var walletBalanceSubject = CurrentValueSubject<WalletBalance, Never>(WalletBalance(wallet: wallet, tokens: [], currency: currencyService.currency))
    private let currencyService: CurrencyService
    public var walletBalance: AnyPublisher<WalletBalance, Never> {
        walletBalanceSubject.eraseToAnyPublisher()
    }

    public init(wallet: Wallet,
                tokensPipeline: TokensProcessingPipeline,
                currencyService: CurrencyService,
                tokensService: TokensService) {

        self.tokensService = tokensService
        self.wallet = wallet
        self.tokensPipeline = tokensPipeline
        self.currencyService = currencyService
        super.init()
    }

    public func start() {
        guard !isRunningTests() else { return }

        timer = Timer.scheduledTimer(withTimeInterval: Self.updateBalanceInterval, repeats: true) { [weak self] _ in
            self?.refreshBalance(updatePolicy: .all)
        }

        tokensPipeline.tokenViewModels
            .map { [wallet, currencyService] in WalletBalance(wallet: wallet, tokens: $0, currency: currencyService.currency) }
            .removeDuplicates()
            .assign(to: \.value, on: walletBalanceSubject)
            .store(in: &cancelable)
    }

    deinit {
        self.stop()
    }

    public func refreshBalance(updatePolicy: TokenBalanceFetcher.RefreshBalancePolicy) {
        tokensService.refreshBalance(updatePolicy: updatePolicy)
    }

    public func stop() {
        timer?.invalidate()
        timer = nil
    }
}
