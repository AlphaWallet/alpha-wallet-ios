//
//  WalletBalanceFetcherType.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 28.05.2021.
//

import Foundation
import BigInt
import Combine
import AlphaWalletCore

public protocol WalletBalanceFetcherType: AnyObject {
    var walletBalance: AnyPublisher<WalletBalance, Never> { get }

    func start()
    func refreshBalance(updatePolicy: TokenBalanceFetcher.RefreshBalancePolicy)
}

public class WalletBalanceFetcher: NSObject, WalletBalanceFetcherType {
    private static let updateBalanceInterval: TimeInterval = 60
    private let scheduler: Scheduler
    private let wallet: Wallet
    private var cancelable = Set<AnyCancellable>()
    private let tokensPipeline: TokensProcessingPipeline
    private let tokensService: TokensService
    private lazy var subject = CurrentValueSubject<WalletBalance, Never>(WalletBalance(wallet: wallet, tokens: [], currency: currencyService.currency))
    private let currencyService: CurrencyService
    public var walletBalance: AnyPublisher<WalletBalance, Never> {
        subject.eraseToAnyPublisher()
    }

    public init(wallet: Wallet,
                tokensPipeline: TokensProcessingPipeline,
                currencyService: CurrencyService,
                tokensService: TokensService) {

        self.tokensService = tokensService
        self.wallet = wallet
        self.tokensPipeline = tokensPipeline
        self.currencyService = currencyService
        let provider = ReloadTokensSchedulerProvider(tokensService: tokensService)
        self.scheduler = Scheduler(provider: provider)
        super.init()
    }

    public func start() {
        guard !isRunningTests() else { return }

        scheduler.start()

        tokensPipeline.tokenViewModels
            .map { [wallet, currencyService] in WalletBalance(wallet: wallet, tokens: $0, currency: currencyService.currency) }
            .removeDuplicates()
            .assign(to: \.value, on: subject)
            .store(in: &cancelable)

        NotificationCenter.default.applicationState
            .receive(on: RunLoop.main)
            .sink { [weak scheduler] state in
                switch state {
                case .didEnterBackground:
                    scheduler?.cancel()
                case .willEnterForeground:
                    scheduler?.restart()
                }
            }.store(in: &cancelable)

        tokensService.providersHasChanged
            .sink { [weak scheduler] _ in scheduler?.restart(force: true) }
            .store(in: &cancelable)
    }

    deinit {
        self.stop()
    }

    public func refreshBalance(updatePolicy: TokenBalanceFetcher.RefreshBalancePolicy) {
        tokensService.refreshBalance(updatePolicy: updatePolicy)
    }

    public func stop() {
        scheduler.cancel()
    }

    private class ReloadTokensSchedulerProvider: SchedulerProvider {
        private let tokensService: TokensService

        let name: String = ""
        let interval: TimeInterval = 60

        var operation: AnyPublisher<Void, PromiseError> {
            AnyPublisher.create { [tokensService] seal in
                seal.send(completion: .finished)
                tokensService.refreshBalance(updatePolicy: .all)

                return AnyCancellable { }
            }
        }

        init(tokensService: TokensService) {
            self.tokensService = tokensService
        }
    }
}
