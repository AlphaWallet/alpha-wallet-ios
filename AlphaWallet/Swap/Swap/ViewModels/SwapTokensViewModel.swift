//
//  SwapTokensViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 08.03.2022.
//

import UIKit
import Combine
import BigInt
import AlphaWalletFoundation

struct SwapTokensViewModelInput {
    let cryptoValue: AnyPublisher<String, Never>
    let allFunds: AnyPublisher<Void, Never>
    let togglePair: AnyPublisher<Void, Never>
}

struct SwapTokensViewModelOutput {
    let anyErrorString: AnyPublisher<String, Never>
    let isContinueButtonEnabled: AnyPublisher<Bool, Never>
    let isConfiguratorInUpdatingState: AnyPublisher<Bool, Never>
    let convertedValue: AnyPublisher<String, Never>
    let fromTokenBalance: AnyPublisher<String, Never>
    let toTokenBalance: AnyPublisher<String?, Never>
    let tokens: AnyPublisher<(from: Token, to: Token?), Never>
    let amountValidation: AnyPublisher<AmountTextField.ErrorState, Never>
    let allFunds: AnyPublisher<(allFundsFullValue: NSDecimalNumber?, allFundsShortValue: String), Never>
}

final class SwapTokensViewModel: NSObject {
    private var cancelable = Set<AnyCancellable>()
    private let configurator: SwapOptionsConfigurator
    private let tokensService: TokenViewModelState

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

    private var allFundsFormattedValues: (allFundsFullValue: NSDecimalNumber?, allFundsShortValue: String)? {
        let token = configurator.swapPair.from
        switch token.type {
        case .nativeCryptocurrency:
            let etherToken = MultipleChainsTokensDataStore.functional.etherToken(forServer: token.server)

            guard let balance = tokensService.tokenViewModel(for: etherToken).flatMap({ $0.balance }) else { return nil }
            let fullValue = EtherNumberFormatter.plain.string(from: balance.value, units: .ether).droppedTrailingZeros
            let shortValue = EtherNumberFormatter.shortPlain.string(from: balance.value, units: .ether).droppedTrailingZeros

            return (fullValue.optionalDecimalValue, shortValue)
        case .erc20:
            guard let balance = tokensService.tokenViewModel(for: token).flatMap({ $0.balance }) else { return nil }
            let fullValue = EtherNumberFormatter.plain.string(from: balance.value, decimals: token.decimals).droppedTrailingZeros
            let shortValue = EtherNumberFormatter.shortPlain.string(from: balance.value, decimals: token.decimals).droppedTrailingZeros

            return (fullValue.optionalDecimalValue, shortValue)

        case .erc1155, .erc721, .erc875, .erc721ForTickets:
            return nil
        }
    }

    var tokens: AnyPublisher<(from: Token, to: Token?), Never> {
        return activeSession.combineLatest(swapPair)
            .map { _, swapPair -> (from: Token, to: Token?) in return (swapPair.from, swapPair.to) }
            .eraseToAnyPublisher()
    }

    var backgoundColor: UIColor = R.color.alabaster()!

    var footerBackgroundColor: UIColor = Colors.appWhite

    let fromHeaderViewModel = SendViewSectionHeaderViewModel(
        text: "From".uppercased(),
        showTopSeparatorLine: false,
        showBottomSeparatorLine: false,
        backgroundColor: Colors.appBackground)

    let toHeaderViewModel = SendViewSectionHeaderViewModel(
        text: "To".uppercased(),
        showTopSeparatorLine: false,
        showBottomSeparatorLine: false,
        backgroundColor: Colors.appBackground)

    var title: String = "Swap"

    let swapPair: CurrentValueSubject<SwapPair, Never>

    lazy var quoteDetailsViewModel: SwapQuoteDetailsViewModel = .init(configurator: configurator)

    init(configurator: SwapOptionsConfigurator, tokensService: TokenViewModelState) {
        self.configurator = configurator
        self.tokensService = tokensService
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
        bigIntValue(cryptoValue: input.cryptoValue)
            .sink { [configurator] in configurator.set(fromAmount: $0) }
            .store(in: &cancelable)

        input.togglePair
            .sink { [configurator] _ in configurator.togglePair() }
            .store(in: &cancelable)

        let isContinueButtonEnabled = isContinueButtonEnabled(cryptoValue: input.cryptoValue)
        let amountValidation = amountValidation(cryptoValue: input.cryptoValue)

        let convertedValue = configurator.tokensWithTheirSwapQuote
            .map { data -> String in
                guard let data = data else { return "" }
                return EtherNumberFormatter.shortPlain.string(from: data.swapQuote.estimate.toAmount, decimals: data.tokens.to.decimals)
            }.eraseToAnyPublisher()

        let anyErrorString = configurator.error
            .compactMap { $0?.description }
            .eraseToAnyPublisher()

        let allFunds = input.allFunds
            .compactMap { _ in self.allFundsFormattedValues }
            .eraseToAnyPublisher()

        return .init(anyErrorString: anyErrorString, isContinueButtonEnabled: isContinueButtonEnabled, isConfiguratorInUpdatingState: isConfiguratorInUpdatingState, convertedValue: convertedValue, fromTokenBalance: fromTokenBalance, toTokenBalance: toTokenBalance, tokens: tokens, amountValidation: amountValidation, allFunds: allFunds)
    }

    private func isContinueButtonEnabled(cryptoValue: AnyPublisher<String, Never>) -> AnyPublisher<Bool, Never> {
        let hasValidEnteredAmount = amountValidation(cryptoValue: cryptoValue)
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

    private func bigIntValue(cryptoValue: AnyPublisher<String, Never>) -> AnyPublisher<BigInt?, Never> {
        return Publishers.CombineLatest(cryptoValue, activeSession.combineLatest(swapPair))
            .map { cryptoValue, sessionAndSwapPair -> BigInt? in
                return self.parseEnteredAmount(cryptoValue, token: sessionAndSwapPair.1.from)
            }.eraseToAnyPublisher()
    }

    private func amountValidation(cryptoValue: AnyPublisher<String, Never>, useGreaterThanZeroValidation: Bool = true) -> AnyPublisher<AmountTextField.ErrorState, Never> {
        return Publishers.CombineLatest(cryptoValue, activeSession.combineLatest(swapPair))
            .map { cryptoValue, sessionAndSwapPair -> AmountTextField.ErrorState in
                let token = sessionAndSwapPair.1.from
                guard let balance: BalanceViewModel = self.balance(for: token, session: sessionAndSwapPair.0) else {
                    return .error
                }
                let parsedValue: BigInt? = self.parseEnteredAmount(cryptoValue, token: token)

                let greaterThanZero = useGreaterThanZeroValidation ? self.checkIfGreaterThanZero(for: token) : false
                guard let value = parsedValue, greaterThanZero ? value > 0 : true else {
                    return .error
                }

                return balance.value >= value ? .none : .error
            }.eraseToAnyPublisher()
    }

    private func balancePublisher(for token: Token, session: WalletSession) -> AnyPublisher<BalanceViewModel?, Never> {
        return Just(token)
            .flatMap { [tokensService] in tokensService.tokenViewModelPublisher(for: $0) }
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

    private func parseEnteredAmount(_ amountString: String, token: Token) -> BigInt? {
        switch token.type {
        case .nativeCryptocurrency:
            return EtherNumberFormatter.full.number(from: amountString, units: .ether)
        case .erc20:
            return EtherNumberFormatter.full.number(from: amountString, decimals: token.decimals)
        case .erc721, .erc1155, .erc721ForTickets, .erc875:
            return nil
        }
    }

    private func balance(for token: Token, session: WalletSession) -> BalanceViewModel? {
        return tokensService.tokenViewModel(for: token)
            .flatMap { $0.balance }
    }
}
