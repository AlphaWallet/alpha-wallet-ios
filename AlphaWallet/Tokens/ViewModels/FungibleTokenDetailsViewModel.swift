// Copyright © 2018 Stormbird PTE. LTD.

import UIKit
import Combine
import AlphaWalletFoundation

struct FungibleTokenDetailsViewModelInput {
    let willAppear: AnyPublisher<Void, Never>
}

struct FungibleTokenDetailsViewModelOutput {
    let viewState: AnyPublisher<FungibleTokenDetailsViewModel.ViewState, Never>
}

final class FungibleTokenDetailsViewModel {
    private var chartHistoriesSubject: CurrentValueSubject<[ChartHistoryPeriod: ChartHistory], Never> = .init([:])
    private let coinTickersFetcher: CoinTickersFetcher
    private let tokensService: TokenViewModelState
    private var cancelable = Set<AnyCancellable>()
    private var chartHistories: [ChartHistoryPeriod: ChartHistory] { chartHistoriesSubject.value }
    private lazy var coinTicker: AnyPublisher<CoinTicker?, Never> = {
        return tokensService.tokenViewModelPublisher(for: token)
            .map { $0?.balance.ticker }
            .eraseToAnyPublisher()
    }()
    private lazy var tokenHolder: TokenHolder = token.getTokenHolder(assetDefinitionStore: assetDefinitionStore, forWallet: session.account)
    private let session: WalletSession
    private let assetDefinitionStore: AssetDefinitionStore
    private let tokenActionsProvider: SupportedTokenActionsProvider
    private (set) var actions: [TokenInstanceAction] = []
    private let currencyService: CurrencyService
    let token: Token
    lazy var chartViewModel = TokenHistoryChartViewModel(chartHistories: chartHistoriesSubject.eraseToAnyPublisher(), coinTicker: coinTicker, currencyService: currencyService)
    lazy var headerViewModel = FungibleTokenHeaderViewModel(token: token, tokensService: tokensService)
    var wallet: Wallet { session.account }

    init(token: Token, coinTickersFetcher: CoinTickersFetcher, tokensService: TokenViewModelState, session: WalletSession, assetDefinitionStore: AssetDefinitionStore, tokenActionsProvider: SupportedTokenActionsProvider, currencyService: CurrencyService) {
        self.currencyService = currencyService
        self.tokenActionsProvider = tokenActionsProvider
        self.session = session
        self.assetDefinitionStore = assetDefinitionStore
        self.tokensService = tokensService
        self.coinTickersFetcher = coinTickersFetcher
        self.token = token
    }

    func transform(input: FungibleTokenDetailsViewModelInput) -> FungibleTokenDetailsViewModelOutput {
        input.willAppear.flatMapLatest { [coinTickersFetcher, token, currencyService] _ in
            coinTickersFetcher.fetchChartHistories(for: .init(token: token), force: false, periods: ChartHistoryPeriod.allCases, currency: currencyService.currency)
        }.assign(to: \.value, on: chartHistoriesSubject)
        .store(in: &cancelable)

        let viewTypes = Publishers.CombineLatest(coinTicker, chartHistoriesSubject)
            .compactMap { [weak self] ticker, _ in self?.buildViewTypes(for: ticker) }

        let viewState = Publishers.CombineLatest(tokenActionsPublisher(), viewTypes)
            .map { FungibleTokenDetailsViewModel.ViewState(actions: $0, views: $1) }
            .eraseToAnyPublisher()

        return .init(viewState: viewState)
    }

    private func tokenActionsPublisher() -> AnyPublisher<[TokenInstanceAction], Never> {
        let whenTokenHolderHasChanged = tokenHolder.objectWillChange
            .map { [tokensService, token] _ in tokensService.tokenViewModel(for: token) }
            .receive(on: RunLoop.main)
            .eraseToAnyPublisher()

        let whenTokenActionsHasChanged = tokenActionsProvider.objectWillChange
            .map { [tokensService, token] _ in tokensService.tokenViewModel(for: token) }
            .receive(on: RunLoop.main)
            .eraseToAnyPublisher()

        let tokenViewModel = tokensService.tokenViewModelPublisher(for: token)

        return Publishers.MergeMany(tokenViewModel, whenTokenHolderHasChanged, whenTokenActionsHasChanged)
            .compactMap { _ in self.buildTokenActions() }
            .handleEvents(receiveOutput: { self.actions = $0 })
            .eraseToAnyPublisher()
    }

    private func buildTokenActions() -> [TokenInstanceAction] {
        let xmlHandler = XMLHandler(token: token, assetDefinitionStore: assetDefinitionStore)
        let actionsFromTokenScript = xmlHandler.actions
        infoLog("[TokenScript] actions names: \(actionsFromTokenScript.map(\.name))")
        if actionsFromTokenScript.isEmpty {
            switch token.type {
            case .erc875, .erc721, .erc721ForTickets, .erc1155:
                return []
            case .erc20, .nativeCryptocurrency:
                let actions: [TokenInstanceAction] = [
                    .init(type: .erc20Send),
                    .init(type: .erc20Receive)
                ]

                return actions + tokenActionsProvider.actions(token: token)
            }
        } else {
            switch token.type {
            case .erc875, .erc721, .erc721ForTickets, .erc1155:
                return []
            case .erc20:
                return actionsFromTokenScript + tokenActionsProvider.actions(token: token)
            case .nativeCryptocurrency:
                //TODO we should support retrieval of XML (and XMLHandler) based on address + server. For now, this is only important for native cryptocurrency. So might be ok to check like this for now
                if let server = xmlHandler.server, server.matches(server: token.server) {
                    return actionsFromTokenScript + tokenActionsProvider.actions(token: token)
                } else {
                    //TODO .erc20Send and .erc20Receive names aren't appropriate
                    let actions: [TokenInstanceAction] = [
                        .init(type: .erc20Send),
                        .init(type: .erc20Receive)
                    ]

                    return actions + tokenActionsProvider.actions(token: token)
                }
            }
        }
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

    func tokenScriptWarningMessage(for action: TokenInstanceAction) -> TokenScriptWarningMessage? {
        let fungibleBalance = tokensService.tokenViewModel(for: token)?.balance.value
        if let selection = action.activeExcludingSelection(selectedTokenHolders: [tokenHolder], forWalletAddress: wallet.address, fungibleBalance: fungibleBalance) {
            if let denialMessage = selection.denial {
                return .warning(string: denialMessage)
            } else {
                //no-op shouldn't have reached here since the button should be disabled. So just do nothing to be safe
                return .undefined
            }
        } else {
            return nil
        }
    }

    func buttonState(for action: TokenInstanceAction) -> ActionButtonState {
        func _configButton(action: TokenInstanceAction) -> ActionButtonState {
            let fungibleBalance = tokensService.tokenViewModel(for: token)?.balance.value
            if let selection = action.activeExcludingSelection(selectedTokenHolders: [tokenHolder], forWalletAddress: wallet.address, fungibleBalance: fungibleBalance) {
                if selection.denial == nil {
                    return .isDisplayed(false)
                }
            }
            return .noOption
        }

        switch wallet.type {
        case .real:
            return _configButton(action: action)
        case .watch:
            if session.config.development.shouldPretendIsRealWallet {
                return _configButton(action: action)
            } else {
                return .isEnabled(false)
            }
        }
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
            guard let history = chartHistories[period] else { return ("-", Colors.black) }

            let result = HistoryHelper(history: history)

            switch result.change {
            case .appreciate(let percentage, let value):
                let p = NumberFormatter.percent.string(double: percentage) ?? "-"
                let v = NumberFormatter.fiat(currency: history.currency).string(double: value) ?? "-"

                return ("\(v) (\(p)%)", Colors.green)
            case .depreciate(let percentage, let value):
                let p = NumberFormatter.percent.string(double: percentage) ?? "-"
                let v = NumberFormatter.fiat(currency: history.currency).string(double: value) ?? "-"

                return ("\(v) (\(p)%)", Colors.appRed)
            case .none:
                return ("-", Colors.black)
            }
        }()

        return TokenAttributeViewModel.attributedString(result.string, alignment: .right, font: Fonts.regular(size: 17), foregroundColor: result.foregroundColor, lineBreakMode: .byTruncatingTail)
    }
}

extension FungibleTokenDetailsViewModel {
    enum TokenScriptWarningMessage {
        case warning(string: String)
        case undefined
    }

    enum ActionButtonState {
        case isDisplayed(Bool)
        case isEnabled(Bool)
        case noOption
    }

    enum ViewType {
        case charts
        case testnet
        case header(viewModel: TokenInfoHeaderViewModel)
        case field(viewModel: TokenAttributeViewModel)
    }

    struct ViewState {
        let actions: [TokenInstanceAction]
        let views: [FungibleTokenDetailsViewModel.ViewType]
    }
}
