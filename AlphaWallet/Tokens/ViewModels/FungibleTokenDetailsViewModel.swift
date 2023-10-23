// Copyright © 2018 Stormbird PTE. LTD.

import UIKit
import Combine
import AlphaWalletCore
import AlphaWalletFoundation
import AlphaWalletLogger

struct FungibleTokenDetailsViewModelInput {
    let willAppear: AnyPublisher<Void, Never>
    let action: AnyPublisher<TokenInstanceAction, Never>
}

struct FungibleTokenDetailsViewModelOutput {
    let viewState: AnyPublisher<FungibleTokenDetailsViewModel.ViewState, Never>
    let action: AnyPublisher<FungibleTokenDetailsViewModel.FungibleTokenAction, Never>
}

final class FungibleTokenDetailsViewModel {
    private let chartHistoriesSubject: CurrentValueSubject<[ChartHistoryPeriod: ChartHistory], Never> = .init([:])
    private let coinTickersProvider: CoinTickersProvider
    private let tokensService: TokensProcessingPipeline
    private var cancelable = Set<AnyCancellable>()
    private var chartHistories: [ChartHistoryPeriod: ChartHistory] { chartHistoriesSubject.value }
    private lazy var coinTicker: AnyPublisher<CoinTicker?, Never> = {
        return tokensService.tokenViewModelPublisher(for: token)
            .map { $0?.balance.ticker }
            .eraseToAnyPublisher()
    }()
    private lazy var tokenHolder: TokenHolder = session.tokenAdaptor.getTokenHolder(token: token)
    private let session: WalletSession
    private let assetDefinitionStore: AssetDefinitionStore
    private let tokenActionsProvider: SupportedTokenActionsProvider
    private (set) var actions: [TokenInstanceAction] = []
    private let currencyService: CurrencyService
    private let tokenImageFetcher: TokenImageFetcher
    private var actionAdapter: TokenInstanceActionAdapter {
        return TokenInstanceActionAdapter(
           session: session,
           token: token,
           tokenHolder: tokenHolder,
           tokenActionsProvider: tokenActionsProvider)
    }

    let token: Token
    lazy var chartViewModel = TokenHistoryChartViewModel(
        chartHistories: chartHistoriesSubject.eraseToAnyPublisher(),
        coinTicker: coinTicker,
        currencyService: currencyService)

    lazy var headerViewModel = FungibleTokenHeaderViewModel(
        token: token,
        tokensService: tokensService,
        tokenImageFetcher: tokenImageFetcher)

    var wallet: Wallet { session.account }

    init(token: Token, coinTickersProvider: CoinTickersProvider, tokensService: TokensProcessingPipeline, session: WalletSession, assetDefinitionStore: AssetDefinitionStore, tokenActionsProvider: SupportedTokenActionsProvider, currencyService: CurrencyService, tokenImageFetcher: TokenImageFetcher) {
        self.tokenImageFetcher = tokenImageFetcher
        self.currencyService = currencyService
        self.tokenActionsProvider = tokenActionsProvider
        self.session = session
        self.assetDefinitionStore = assetDefinitionStore
        self.tokensService = tokensService
        self.coinTickersProvider = coinTickersProvider
        self.token = token
    }

    func transform(input: FungibleTokenDetailsViewModelInput) -> FungibleTokenDetailsViewModelOutput {
        input.willAppear.flatMapLatest { [coinTickersProvider, token, currencyService] _ in
            asFuture {
                await coinTickersProvider.chartHistories(for: .init(token: token), currency: currencyService.currency)
            }
        }.assign(to: \.value, on: chartHistoriesSubject)
        .store(in: &cancelable)

        let viewTypes = Publishers.CombineLatest(coinTicker, chartHistoriesSubject)
            .compactMap { [weak self] ticker, _ in self?.buildViewTypes(for: ticker) }

        let viewState = Publishers.CombineLatest(tokenActionButtonsPublisher(), viewTypes)
            .map { FungibleTokenDetailsViewModel.ViewState(actionButtons: $0, views: $1) }

        let action = input.action
            .flatMap { action in asFuture { await self.buildFungibleTokenAction(for: action) } }.compactMap { $0 }

        return .init(
            viewState: viewState.eraseToAnyPublisher(),
            action: action.eraseToAnyPublisher())
    }

    private func buildFungibleTokenAction(for action: TokenInstanceAction) async -> FungibleTokenAction? {
        switch action.type {
        case .swap: return .swap(swapTokenFlow: .swapToken(token: token))
        case .erc20Send: return .erc20Transfer(token: token)
        case .erc20Receive: return .erc20Receive(token: token)
        case .nftRedeem, .nftSell, .nonFungibleTransfer: return nil
        case .tokenScript:
            let fungibleBalance = await tokensService.tokenViewModel(for: token)?.balance.value
            if let message = actionAdapter.tokenScriptWarningMessage(for: action, fungibleBalance: fungibleBalance) {
                guard case .warning(let string) = message else { return nil }
                return .display(warning: string)
            } else {
                return .tokenScript(action: action, token: token)
            }
        case .bridge(let service): return .bridge(token: token, service: service)
        case .buy(let service): return .buy(token: token, service: service)
        }
    }

    private func tokenActionButtonsPublisher() -> AnyPublisher<[ActionButton], Never> {
        let whenTokenHolderHasChanged = tokenHolder.objectWillChange
            .flatMap { [tokensService, token] _ in asFuture { await tokensService.tokenViewModel(for: token) } }
            .receive(on: RunLoop.main)
            .eraseToAnyPublisher()

        let whenTokenActionsHasChanged = tokenActionsProvider.objectWillChange
            .flatMap { [tokensService, token] _ in asFuture { await tokensService.tokenViewModel(for: token) } }
            .receive(on: RunLoop.main)
            .eraseToAnyPublisher()

        let tokenViewModel = tokensService.tokenViewModelPublisher(for: token)

        return Publishers.MergeMany(tokenViewModel, whenTokenHolderHasChanged, whenTokenActionsHasChanged)
            .compactMap { _ in self.actionAdapter.availableActions() }
            .flatMap { [tokensService, token] actions in
                asFuture {
                    let fungibleBalance = await tokensService.tokenViewModel(for: token)?.balance.value
                    return actions.map {
                        ActionButton(actionType: $0, name: $0.name, state: self.actionAdapter.state(for: $0, fungibleBalance: fungibleBalance))
                    }
                }
            }.eraseToAnyPublisher()
    }

    private func buildViewTypes(for ticker: CoinTicker?) -> [FungibleTokenDetailsViewModel.ViewType] {
        var views: [FungibleTokenDetailsViewModel.ViewType] = []

        if token.server.isTestnet {
            views = [
                .testnet
            ]
        } else {
            views = [
                .charts,
                .header(viewModel: .init(title: R.string.localizable.tokenInfoHeaderPerformance())),
                .field(viewModel: dayViewModel),
                .field(viewModel: weekViewModel),
                .field(viewModel: monthViewModel),
                .field(viewModel: yearViewModel),

                .header(viewModel: .init(title: R.string.localizable.tokenInfoHeaderStats())),
                .field(viewModel: markerCapViewModel(for: ticker)),
                .field(viewModel: yearLowViewModel),
                .field(viewModel: yearHighViewModel)
            ]
        }

        return views
    }

    private func markerCapViewModel(for ticker: CoinTicker?) -> TokenAttributeViewModel {
        let value: String = ticker?.market_cap.flatMap { StringFormatter().largeNumberFormatter(for: $0, currency: "USD") } ?? "-"
        let attributedValue = TokenAttributeViewModel.defaultValueAttributedString(value)
        return .init(title: R.string.localizable.tokenInfoFieldStatsMarket_cap(), attributedValue: attributedValue)
    }

    private func totalSupplyViewModel(for ticker: CoinTicker?) -> TokenAttributeViewModel {
        let value: String = ticker?.total_supply.flatMap { String($0) } ?? "-"
        let attributedValue = TokenAttributeViewModel.defaultValueAttributedString(value)
        return .init(title: R.string.localizable.tokenInfoFieldStatsTotal_supply(), attributedValue: attributedValue)
    }

    private func maxSupplyViewModel(for ticker: CoinTicker?) -> TokenAttributeViewModel {
        let value: String = {
            guard let ticker = ticker else { return "-" }
            if let maxSupply = ticker.max_supply {
                return NumberFormatter.fiat(currency: ticker.currency).string(double: maxSupply) ?? "-"
            } else {
                return "-"
            }
        }()
        let attributedValue = TokenAttributeViewModel.defaultValueAttributedString(value)
        return .init(title: R.string.localizable.tokenInfoFieldStatsMax_supply(), attributedValue: attributedValue)
    }

    private var yearLowViewModel: TokenAttributeViewModel {
        let value: String = {
            guard let history = chartHistories[ChartHistoryPeriod.year] else { return "-" }
            let helper = HistoryHelper(history: history)
            if let min = helper.minMax?.min, let value = NumberFormatter.fiat(currency: history.currency).string(double: min) {
                return value
            } else {
                return "-"
            }
        }()

        let attributedValue = TokenAttributeViewModel.defaultValueAttributedString(value)
        return .init(title: R.string.localizable.tokenInfoFieldPerformanceYearLow(), attributedValue: attributedValue)
    }

    private var yearHighViewModel: TokenAttributeViewModel {
        let value: String = {
            guard let history = chartHistories[ChartHistoryPeriod.year] else { return "-" }
            let helper = HistoryHelper(history: history)
            if let max = helper.minMax?.max, let value = NumberFormatter.fiat(currency: history.currency).string(double: max) {
                return value
            } else {
                return "-"
            }
        }()

        let attributedValue = TokenAttributeViewModel.defaultValueAttributedString(value)
        return .init(title: R.string.localizable.tokenInfoFieldPerformanceYearHigh(), attributedValue: attributedValue)
    }

    private var yearViewModel: TokenAttributeViewModel {
        let attributedValue: NSAttributedString = attributedHistoryValue(period: ChartHistoryPeriod.year)
        return .init(title: R.string.localizable.tokenInfoFieldStatsYear(), attributedValue: attributedValue)
    }

    private var monthViewModel: TokenAttributeViewModel {
        let attributedValue: NSAttributedString = attributedHistoryValue(period: ChartHistoryPeriod.month)
        return .init(title: R.string.localizable.tokenInfoFieldStatsMonth(), attributedValue: attributedValue)
    }

    private var weekViewModel: TokenAttributeViewModel {
        let attributedValue: NSAttributedString = attributedHistoryValue(period: ChartHistoryPeriod.week)
        return .init(title: R.string.localizable.tokenInfoFieldStatsWeek(), attributedValue: attributedValue)
    }

    private var dayViewModel: TokenAttributeViewModel {
        let attributedValue: NSAttributedString = attributedHistoryValue(period: ChartHistoryPeriod.day)
        return .init(title: R.string.localizable.tokenInfoFieldStatsDay(), attributedValue: attributedValue)
    }

    private func attributedHistoryValue(period: ChartHistoryPeriod) -> NSAttributedString {
        let result: (string: String, foregroundColor: UIColor) = {
            guard let history = chartHistories[period] else { return ("-", Configuration.Color.Semantic.defaultForegroundText) }

            let result = HistoryHelper(history: history)

            switch result.change {
            case .appreciate(let percentage, let value):
                let p = NumberFormatter.percent.string(double: percentage) ?? "-"
                let v = NumberFormatter.fiat(currency: history.currency).string(double: value) ?? "-"

                return ("\(v) (\(p)%)", Configuration.Color.Semantic.appreciation)
            case .depreciate(let percentage, let value):
                let p = NumberFormatter.percent.string(double: percentage) ?? "-"
                let v = NumberFormatter.fiat(currency: history.currency).string(double: value) ?? "-"

                return ("\(v) (\(p)%)", Configuration.Color.Semantic.depreciation)
            case .none:
                return ("-", Configuration.Color.Semantic.defaultForegroundText)
            }
        }()

        return TokenAttributeViewModel.attributedString(result.string, alignment: .right, font: Fonts.regular(size: 17), foregroundColor: result.foregroundColor, lineBreakMode: .byTruncatingTail)
    }
}

extension FungibleTokenDetailsViewModel {

    enum ViewType {
        case charts
        case testnet
        case header(viewModel: TokenInfoHeaderViewModel)
        case field(viewModel: TokenAttributeViewModel)
    }

    struct ViewState {
        let actionButtons: [ActionButton]
        let views: [FungibleTokenDetailsViewModel.ViewType]
    }

    struct ActionButton {
        let actionType: TokenInstanceAction
        let name: String
        let state: TokenInstanceActionAdapter.ActionState
    }

    enum FungibleTokenAction {
        case swap(swapTokenFlow: SwapTokenFlow)
        case erc20Transfer(token: Token)
        case erc20Receive(token: Token)
        case tokenScript(action: TokenInstanceAction, token: Token)
        case bridge(token: Token, service: TokenActionProvider)
        case buy(token: Token, service: TokenActionProvider)
        case display(warning: String)
    }
}
