//
//  SwapTokensViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 08.03.2022.
//

import UIKit
import Combine
import AlphaWalletCore
import AlphaWalletFoundation
import BigInt

struct SwapTokensViewModelInput {
    let cryptoValue: AnyPublisher<AmountTextFieldViewModel.FungibleAmount, Never>
    let allFunds: AnyPublisher<Void, Never>
    let togglePair: AnyPublisher<Void, Never>
}

struct SwapTokensViewModelOutput {
    let anyErrorString: AnyPublisher<String, Never>
    let isContinueButtonEnabled: AnyPublisher<Bool, Never>
    let isConfiguratorInUpdatingState: AnyPublisher<Bool, Never>
    let convertedValue: AnyPublisher<AmountTextFieldViewModel.FungibleAmount, Never>
    let fromTokenBalance: AnyPublisher<String, Never>
    let toTokenBalance: AnyPublisher<String?, Never>
    let tokens: AnyPublisher<(from: Token, to: Token?), Never>
    let amountValidation: AnyPublisher<AmountTextField.ErrorState, Never>
    let allFunds: AnyPublisher<AmountTextFieldViewModel.FungibleAmount, Never>
}

final class SwapTokensViewModel: NSObject {
    private var cancelable = Set<AnyCancellable>()
    private let configurator: SwapOptionsConfigurator
    private let tokensPipeline: TokensProcessingPipeline

    lazy private (set) var activeSession: AnyPublisher<WalletSession, Never> = {
        return configurator.$server.combineLatest(configurator.$sessions) { server, sessions -> WalletSession? in
            return sessions.first(where: { $0.server == server })
        }.compactMap { $0 }
        .removeDuplicates()
        .share()
        .prepend(Just(configurator.session).compactMap { $0 })
        .eraseToAnyPublisher()
    }()

    private var isConfiguratorInUpdatingState: AnyPublisher<Bool, Never> {
        let isFetchingSwapQuote = configurator.fetchSwapQuoteState
            .map { state -> Bool in state == .fetching }

        let isLoadingSwapOptions = configurator.tokenSwapper.loadingStatePublisher
            .map { state -> Bool in state == .updating }

        return Publishers.Merge(isFetchingSwapQuote, isLoadingSwapOptions)
            .removeDuplicates()
            .eraseToAnyPublisher()
    }

    private var fromTokenBalance: AnyPublisher<String, Never> {
        return activeSession.combineLatest(swapPair)
            .flatMapLatest { self.balancePublisher(for: $0.1.from, session: $0.0) }
            .map { R.string.localizable.sendAvailable($0.flatMap { $0.amountShort } ?? "-") }
            .eraseToAnyPublisher()
    }

    private var toTokenBalance: AnyPublisher<String?, Never> {
        return activeSession.combineLatest(swapPair)
            .flatMap { value -> AnyPublisher<BalanceViewModel?, Never> in
                if let publisher = value.1.to.flatMap({ self.balancePublisher(for: $0, session: value.0) }) {
                    return publisher
                } else {
                    return Just(nil).eraseToAnyPublisher()
                }
            }.map { $0.flatMap { R.string.localizable.sendAvailable($0.amountShort) } }
            .eraseToAnyPublisher()
    }

    var tokens: AnyPublisher<(from: Token, to: Token?), Never> {
        return activeSession.combineLatest(swapPair)
            .map { _, swapPair -> (from: Token, to: Token?) in return (swapPair.from, swapPair.to) }
            .eraseToAnyPublisher()
    }

    let fromHeaderViewModel = SendViewSectionHeaderViewModel(
        text: "From".uppercased(),
        showTopSeparatorLine: false,
        showBottomSeparatorLine: false,
        backgroundColor: Configuration.Color.Semantic.defaultViewBackground)

    let toHeaderViewModel = SendViewSectionHeaderViewModel(
        text: "To".uppercased(),
        showTopSeparatorLine: false,
        showBottomSeparatorLine: false,
        backgroundColor: Configuration.Color.Semantic.defaultViewBackground)

    var title: String = "Swap"

    let swapPair: CurrentValueSubject<SwapPair, Never>

    lazy var quoteDetailsViewModel: SwapQuoteDetailsViewModel = .init(configurator: configurator)

    init(configurator: SwapOptionsConfigurator, tokensPipeline: TokensProcessingPipeline) {
        self.configurator = configurator
        self.tokensPipeline = tokensPipeline
        let value = configurator.swapPair
        self.swapPair = .init(value)

        super.init()

        configurator.$swapPair.share()
            .prepend(configurator.swapPair)
            .multicast(subject: swapPair)
            .connect()
            .store(in: &cancelable)
    }

    func transform(input: SwapTokensViewModelInput) -> SwapTokensViewModelOutput {
        let amountToSwap = input.cryptoValue
            .map { $0.asAmount }
            .eraseToAnyPublisher()

        self.buildBigUIntValue(amount: amountToSwap)
            .sink { [configurator] in configurator.set(fromAmount: $0) }
            .store(in: &cancelable)

        input.togglePair
            .sink { [configurator] _ in configurator.togglePair() }
            .store(in: &cancelable)

        let isContinueButtonEnabled = isContinueButtonEnabled(amountToSwap: amountToSwap)
        let amountValidation = amountValidation(amountToSwap: amountToSwap)

        let convertedValue = configurator.tokensWithTheirSwapQuote
            .map { data -> AmountTextFieldViewModel.FungibleAmount in
                guard let data = data else { return .notSet }

                guard let amount = Decimal(bigUInt: data.swapQuote.estimate.toAmount, decimals: data.tokens.to.decimals) else { return .notSet }
                return .amount(amount.doubleValue)
            }.eraseToAnyPublisher()

        let anyErrorString = configurator.error
            .compactMap { $0?.description }
            .eraseToAnyPublisher()

        let allFunds = buildMaxFungibleAmount(for: input.allFunds)

        return .init(anyErrorString: anyErrorString, isContinueButtonEnabled: isContinueButtonEnabled, isConfiguratorInUpdatingState: isConfiguratorInUpdatingState, convertedValue: convertedValue, fromTokenBalance: fromTokenBalance, toTokenBalance: toTokenBalance, tokens: tokens, amountValidation: amountValidation, allFunds: allFunds)
    }

    private func isContinueButtonEnabled(amountToSwap: AnyPublisher<FungibleAmount, Never>) -> AnyPublisher<Bool, Never> {
        let hasValidEnteredAmount = amountValidation(amountToSwap: amountToSwap)
            .map { $0 == .none }
            .removeDuplicates()

        let hasValidSwapQuote = configurator.swapQuote
            .map { $0 != nil }

        let isInLoadingState = isConfiguratorInUpdatingState

        return Publishers.CombineLatest3(hasValidSwapQuote, hasValidEnteredAmount, isInLoadingState)
            .map { $0.0 && $0.1 && !$0.2 }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }

    private func buildMaxFungibleAmount(for trigger: AnyPublisher<Void, Never>) -> AnyPublisher<AmountTextFieldViewModel.FungibleAmount, Never> {
        trigger.flatMap { [tokensPipeline, configurator] _ in
            asFuture {
                let token = configurator.swapPair.from
                switch token.type {
                case .nativeCryptocurrency:
                    guard let balance = await tokensPipeline.tokenViewModel(for: token)?.balance else { return nil }

                    return Decimal(bigUInt: BigUInt(balance.value), decimals: token.decimals).flatMap { AmountTextFieldViewModel.FungibleAmount.allFunds($0.doubleValue) }
                case .erc20:
                    guard let balance = await tokensPipeline.tokenViewModel(for: token)?.balance else { return nil }

                    return Decimal(bigUInt: BigUInt(balance.value), decimals: token.decimals).flatMap { AmountTextFieldViewModel.FungibleAmount.allFunds($0.doubleValue) }
                case .erc1155, .erc721, .erc875, .erc721ForTickets:
                    return nil
                }
            }
        }.compactMap { $0 }.eraseToAnyPublisher()
    }

    private func buildBigUIntValue(amount: AnyPublisher<FungibleAmount, Never>) -> AnyPublisher<BigUInt?, Never> {
        return Publishers.CombineLatest(amount, activeSession.combineLatest(swapPair))
            .flatMap { amount, sessionAndSwapPair in
                asFuture {
                    switch amount {
                    case .amount(let amount):
                        return Decimal(amount).toBigUInt(decimals: sessionAndSwapPair.1.from.decimals)
                    case .allFunds:
                        guard let balance: BalanceViewModel = await self.balance(for: sessionAndSwapPair.1.from, session: sessionAndSwapPair.0) else {
                            return nil
                        }
                        return balance.value
                    case .notSet:
                        return nil
                    }
                }
            }.eraseToAnyPublisher()
    }

    private func amountValidation(amountToSwap: AnyPublisher<FungibleAmount, Never>, useGreaterThanZeroValidation: Bool = true) -> AnyPublisher<AmountTextField.ErrorState, Never> {
        return Publishers.CombineLatest(amountToSwap, activeSession.combineLatest(swapPair))
            .flatMap { amountToSwap, sessionAndSwapPair in
                asFuture {
                    let token = sessionAndSwapPair.1.from
                    guard let balance: BalanceViewModel = await self.balance(for: token, session: sessionAndSwapPair.0) else {
                        return .error
                    }

                    switch amountToSwap {
                    case .notSet:
                        return .error
                    case .allFunds:
                        return .none
                    case .amount(let amount):
                        let greaterThanZero = useGreaterThanZeroValidation ? self.checkIfGreaterThanZero(for: token) : false
                        guard greaterThanZero ? amount > 0 : true else {
                            return .error
                        }
                        return balance.valueDecimal.doubleValue >= amount ? .none : .error
                    }
                }
            }.eraseToAnyPublisher()
    }

    private func balancePublisher(for token: Token, session: WalletSession) -> AnyPublisher<BalanceViewModel?, Never> {
        return Just(token)
            .flatMap { [tokensPipeline] in tokensPipeline.tokenViewModelPublisher(for: $0) }
            .map { $0?.balance }
            .eraseToAnyPublisher()
    }

    private func checkIfGreaterThanZero(for token: Token) -> Bool {
        switch token.type {
        case .nativeCryptocurrency:
            return false
        case .erc20, .erc1155, .erc721, .erc875, .erc721ForTickets:
            return true
        }
    }

    private func balance(for token: Token, session: WalletSession) async -> BalanceViewModel? {
        return await tokensPipeline.tokenViewModel(for: token)
            .flatMap { $0.balance }
    }
}
