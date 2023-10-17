//
//  FungibleTokenHeaderViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 20.05.2022.
//

import UIKit
import Combine
import AlphaWalletFoundation

struct FungibleTokenHeaderViewModelInput {
    let toggleValue: AnyPublisher<Void, Never>
}

struct FungibleTokenHeaderViewModelOutput {
    let viewState: AnyPublisher<FungibleTokenHeaderViewModel.ViewState, Never>
}

final class FungibleTokenHeaderViewModel {
    private let headerViewRefreshInterval: TimeInterval = 5.0
    private var headerRefreshTimer: Timer?
    private let token: Token
    private var isShowingValueSubject: CurrentValueSubject<Bool, Never> = .init(true)
    private let tokensService: TokensProcessingPipeline
    private var cancelable = Set<AnyCancellable>()
    private let tokenImageFetcher: TokenImageFetcher

    let backgroundColor: UIColor = Configuration.Color.Semantic.defaultViewBackground
    var iconImage: TokenImagePublisher {
        tokenImageFetcher.image(token: token, size: .s300)
    }

    var blockChainTagViewModel: BlockchainTagLabelViewModel {
        return .init(server: token.server)
    }

    init(token: Token,
         tokensService: TokensProcessingPipeline,
         tokenImageFetcher: TokenImageFetcher) {

        self.tokenImageFetcher = tokenImageFetcher
        self.token = token
        self.tokensService = tokensService
    }

    deinit {
        invalidateRefreshHeaderTimer()
    }

    func transform(input: FungibleTokenHeaderViewModelInput) -> FungibleTokenHeaderViewModelOutput {
        runRefreshHeaderTimer()

        input.toggleValue
            .filter { [token] _ in !token.server.isTestnet }
            .sink { [weak self] in
                self?.tiggleIsShowingValue()
                self?.invalidateRefreshHeaderTimer()
                self?.runRefreshHeaderTimer()
            }.store(in: &cancelable)

        let viewState = tokensService.tokenViewModelPublisher(for: token)
            .combineLatest(isShowingValueSubject, { tokenViewModel, _ in return tokenViewModel })
            .map { FungibleTokenHeaderViewModel.ViewState(title: self.buildTitle(for: $0), value: self.buildValue(for: $0)) }
            .removeDuplicates()
            .eraseToAnyPublisher()

        return .init(viewState: viewState)
    }

    private func runRefreshHeaderTimer() {
        let timer = Timer(timeInterval: headerViewRefreshInterval, repeats: true) { [weak self] _ in
           self?.tiggleIsShowingValue()
        }

        RunLoop.main.add(timer, forMode: .default)
        headerRefreshTimer = timer
    }

    private func invalidateRefreshHeaderTimer() {
        headerRefreshTimer?.invalidate()
        headerRefreshTimer = nil
    }

    private func tiggleIsShowingValue() {
        isShowingValueSubject.value.toggle()
    }

    private func buildValue(for tokenViewModel: TokenViewModel?) -> NSAttributedString {
        guard let tokenViewModel = tokenViewModel else { return .init(string: UiTweaks.noPriceMarker) }
        return amountAttributedString(for: tokenViewModel.balance) ?? .init(string: UiTweaks.noPriceMarker)
    }

    private func buildTitle(for tokenViewModel: TokenViewModel?) -> NSAttributedString {
        guard let tokenViewModel = tokenViewModel else { return .init(string: UiTweaks.noPriceMarker) }
        let value: String
        switch tokenViewModel.type {
        case .nativeCryptocurrency:
            value = "\(tokenViewModel.balance.amountShort) \(tokenViewModel.balance.symbol)"
        case .erc20:
            value = "\(tokenViewModel.balance.amountShort) \(tokenViewModel.tokenScriptOverrides?.symbolInPluralForm ?? tokenViewModel.balance.symbol)"
        case .erc1155, .erc721, .erc721ForTickets, .erc875:
            value = UiTweaks.noPriceMarker
        }

        return FungibleTokenHeaderViewModel.functional.asTitleAttributedString(value)
    }

    private func amountAttributedString(for balance: BalanceViewModel) -> NSAttributedString? {
        if token.server.isTestnet {
            return FungibleTokenHeaderViewModel.functional.testnetValueHintLabelAttributedString
        } else {
            switch token.type {
            case .nativeCryptocurrency, .erc20:
                if isShowingValueSubject.value {
                    return FungibleTokenHeaderViewModel.functional.amountInFiatAttributedString(for: balance)
                } else {
                    return FungibleTokenHeaderViewModel.functional.marketPriceAttributedString(for: balance)
                }
            case .erc1155, .erc721, .erc721ForTickets, .erc875:
                return nil
            }
        }
    }
}

extension FungibleTokenHeaderViewModel {
    enum functional {}
    struct ViewState {
        let title: NSAttributedString
        let value: NSAttributedString
    }
}

fileprivate extension FungibleTokenHeaderViewModel.functional {
    static func amountInFiatAttributedString(for balance: BalanceViewModel) -> NSAttributedString {
        let string: String = {
            guard let ticker = balance.ticker, let amount = balance.amountInFiat else { return UiTweaks.noPriceMarker }
            let formatter = NumberFormatter.fiat(currency: ticker.currency)

            return formatter.string(double: amount) ?? UiTweaks.noPriceMarker
        }()

        return NSAttributedString(string: R.string.localizable.aWalletTokenValue(string), attributes: [
            .font: Screen.TokenCard.Font.placeholderLabel,
            .foregroundColor: Configuration.Color.Semantic.defaultSubtitleText
        ])
    }

    static var testnetValueHintLabelAttributedString: NSAttributedString {
        return NSAttributedString(string: R.string.localizable.tokenValueTestnetWarning(), attributes: [
            .font: Screen.TokenCard.Font.placeholderLabel,
            .foregroundColor: Configuration.Color.Semantic.defaultSubtitleText
        ])
    }

    static func asTitleAttributedString(_ title: String) -> NSAttributedString {
        return NSAttributedString(string: title, attributes: [
            .font: Fonts.regular(size: ScreenChecker().isNarrowScreen ? 26 : 36),
            .foregroundColor: Configuration.Color.Semantic.defaultForegroundText
        ])
    }

    static func marketPriceAttributedString(for balance: BalanceViewModel) -> NSAttributedString? {
        guard let marketPrice = marketPrice(for: balance), let valuePercentageChange = priceChange(for: balance) else {
            return nil
        }

        let string = R.string.localizable.aWalletTokenMarketPrice(marketPrice, valuePercentageChange)

        guard let valuePercentageChangeRange = string.range(of: valuePercentageChange) else { return nil }

        let mutableAttributedString = NSMutableAttributedString(string: string, attributes: [
            .font: Screen.TokenCard.Font.placeholderLabel,
            .foregroundColor: Configuration.Color.Semantic.defaultSubtitleText
        ])

        let range = NSRange(valuePercentageChangeRange, in: string)
        mutableAttributedString.setAttributes([
            .font: Fonts.semibold(size: ScreenChecker().isNarrowScreen ? 14 : 17),
            .foregroundColor: Screen.TokenCard.Color.valueChangeValue(ticker: balance.ticker)
        ], range: range)

        return mutableAttributedString
    }

    static func priceChange(for balance: BalanceViewModel) -> String? {
        guard let ticker = balance.ticker else { return nil }

        let formatter = NumberFormatter.percent
        switch TickerHelper(ticker: ticker).change24h {
        case .appreciate(let percentageChange24h):
            return "(\(formatter.string(double: percentageChange24h) ?? "")%)"
        case .depreciate(let percentageChange24h):
            return "(\(formatter.string(double: percentageChange24h) ?? "")%)"
        case .none:
            return nil
        }
    }

    static func marketPrice(for balance: BalanceViewModel) -> String? {
        guard let ticker = balance.ticker else { return nil }

        return NumberFormatter.fiat(currency: ticker.currency).string(double: ticker.price_usd)
    }
}

extension FungibleTokenHeaderViewModel.ViewState: Equatable { }
