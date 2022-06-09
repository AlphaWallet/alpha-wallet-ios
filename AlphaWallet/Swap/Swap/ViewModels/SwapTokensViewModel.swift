//
//  SwapTokensViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 08.03.2022.
//

import UIKit
import Combine
import BigInt

class SwapTokensViewModel: NSObject {
    private var cancelable = Set<AnyCancellable>()
    private let configurator: SwapOptionsConfigurator

    var backgoundColor: UIColor = R.color.alabaster()!

    var footerBackgroundColor: UIColor = Colors.appWhite
    
    let fromHeaderViewModel = SendViewSectionHeaderViewModel(
        text: "From".uppercased(),
        showTopSeparatorLine: false,
        showBottomSeparatorLine: false,
        backgroundColor: Colors.appBackground
    )

    let toHeaderViewModel = SendViewSectionHeaderViewModel(
        text: "To".uppercased(),
        showTopSeparatorLine: false,
        showBottomSeparatorLine: false,
        backgroundColor: Colors.appBackground
    )

    var navigationTitle: String = "Swap"

    let swapPair: CurrentValueSubject<SwapPair, Never>

    lazy var swapDetailsViewModel: SwapDetailsViewModel = .init(configurator: configurator)

    var convertedValue: AnyPublisher<String, Never> {
        return configurator.swapQuote.map { swapQuote -> String in
            return swapQuote.flatMap { EtherNumberFormatter.full.string(from: BigInt($0.estimate.toAmount)) } ?? ""
        }.eraseToAnyPublisher()
    }

    var anyErrorString: AnyPublisher<String, Never> {
        configurator.error
            .compactMap { $0?.description }
            .eraseToAnyPublisher()
    }

    lazy private (set) var activeSession: AnyPublisher<WalletSession, Never> = {
        return configurator.$server.combineLatest(configurator.$sessions) { server, sessions -> WalletSession? in
            return sessions.first(where: { $0.server == server })
        }.compactMap { $0 }
        .removeDuplicates()
        .share()
        .prepend(Just(configurator.session).compactMap { $0 })
        .eraseToAnyPublisher()
    }()

    func isContinueButtonEnabled(cryptoValue: AnyPublisher<String, Never>) -> AnyPublisher<Bool, Never> {
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

    var isConfiguratorInUpdatingState: AnyPublisher<Bool, Never> {
        let isFetchingSwapQuote = configurator.swapQuoteState
            .map { state -> Bool in state == .fetching }

        let isLoadingSwapOptions = configurator.tokenSwapper.loadingStatePublisher
            .map { state -> Bool in state == .updating }

        return Publishers.Merge(isFetchingSwapQuote, isLoadingSwapOptions)
            .removeDuplicates()
            .eraseToAnyPublisher()
    }

    var allFundsFormattedValues: (allFundsFullValue: NSDecimalNumber?, allFundsShortValue: String)? {
        let token = configurator.swapPair.from
        switch token.type {
        case .nativeCryptocurrency:
            let etherToken = MultipleChainsTokensDataStore.functional.etherToken(forServer: token.server).addressAndRPCServer
            guard let balance = configurator.session.tokenBalanceService.tokenBalance(etherToken) else { return nil }
            let fullValue = EtherNumberFormatter.plain.string(from: balance.value, units: .ether).droppedTrailingZeros
            let shortValue = EtherNumberFormatter.shortPlain.string(from: balance.value, units: .ether).droppedTrailingZeros

            return (fullValue.optionalDecimalValue, shortValue)
        case .erc20:
            guard let balance = configurator.session.tokenBalanceService.tokenBalance(token.addressAndRPCServer) else { return nil }
            let fullValue = EtherNumberFormatter.plain.string(from: balance.value, decimals: token.decimals).droppedTrailingZeros
            let shortValue = EtherNumberFormatter.shortPlain.string(from: balance.value, decimals: token.decimals).droppedTrailingZeros

            return (fullValue.optionalDecimalValue, shortValue)

        case .erc1155, .erc721, .erc875, .erc721ForTickets:
            return nil
        }
    }

    var fromTokenBalance: AnyPublisher<String, Never> {
        return activeSession.combineLatest(swapPair)
            .map { self.balancePublisher(for: $0.1.from, session: $0.0) }
            .switchToLatest()
            .map { R.string.localizable.sendAvailable($0.flatMap { $0.amountShort } ?? "-") }
            .eraseToAnyPublisher()
    }

    var toTokenBalance: AnyPublisher<String?, Never> {
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
            .map { _, swapPair -> (from: Token, to: Token?) in
                return (swapPair.from, swapPair.to)
            }.eraseToAnyPublisher()
    }

    init(configurator: SwapOptionsConfigurator) {
        self.configurator = configurator
        let value = configurator.swapPair
        self.swapPair = .init(value)

        super.init()

        configurator.$swapPair.share()
            .prepend(configurator.swapPair)
            .multicast(subject: swapPair)
            .connect()
            .store(in: &cancelable)
    } 

    func set(fromAmount amount: BigInt?) {
        configurator.set(fromAmount: amount)
    }

    func togglePair() {
        configurator.togglePair()
    }

    func bigIntValue(cryptoValue: AnyPublisher<String, Never>) -> AnyPublisher<BigInt?, Never> {
        return Publishers.CombineLatest(cryptoValue, activeSession.combineLatest(swapPair))
            .map { cryptoValue, sessionAndSwapPair -> BigInt? in
                return self.parseEnteredAmount(cryptoValue, token: sessionAndSwapPair.1.from)
            }.eraseToAnyPublisher()
    }

    func amountValidation(cryptoValue: AnyPublisher<String, Never>, useGreaterThanZeroValidation: Bool = true) -> AnyPublisher<AmountTextField_v2.ErrorState, Never> {
        return Publishers.CombineLatest(cryptoValue, activeSession.combineLatest(swapPair))
            .map { cryptoValue, sessionAndSwapPair -> AmountTextField_v2.ErrorState in
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
        switch token.type {
        case .nativeCryptocurrency:
            let etherToken = MultipleChainsTokensDataStore.functional.etherToken(forServer: token.server).addressAndRPCServer
            return session.tokenBalanceService.tokenBalancePublisher(etherToken)
        case .erc20:
            return session.tokenBalanceService.tokenBalancePublisher(token.addressAndRPCServer)
        case .erc1155, .erc721, .erc875, .erc721ForTickets:
            return session.tokenBalanceService.tokenBalancePublisher(token.addressAndRPCServer)
        }
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
        switch token.type {
        case .nativeCryptocurrency:
            let etherToken = MultipleChainsTokensDataStore.functional.etherToken(forServer: token.server).addressAndRPCServer
            return session.tokenBalanceService.tokenBalance(etherToken)
        case .erc20:
            return session.tokenBalanceService.tokenBalance(token.addressAndRPCServer)
        case .erc1155, .erc721, .erc875, .erc721ForTickets:
            return session.tokenBalanceService.tokenBalance(token.addressAndRPCServer)
        }
    }
}
