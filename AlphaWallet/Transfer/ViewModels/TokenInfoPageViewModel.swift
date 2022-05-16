// Copyright © 2018 Stormbird PTE. LTD.

import UIKit
import Combine

enum TokenInfoPageViewModelConfiguration {
    case charts
    case testnet
    case header(viewModel: TokenInfoHeaderViewModel)
    case field(viewModel: TickerFieldValueViewModel)
}

class TokenInfoPageViewModel: NSObject {
    private var chartHistoriesSubject: CurrentValueSubject<[ChartHistory], Never> = .init([])
    private let session: WalletSession
    private let assetDefinitionStore: AssetDefinitionStore
    private let coinTickersFetcher: CoinTickersFetcherType
    private var ticker: CoinTicker?

    var tabTitle: String {
        return R.string.localizable.tokenTabInfo()
    }

    let transactionType: TransactionType

    var chartHistories: [ChartHistory] {
        chartHistoriesSubject.value
    }

    lazy var fieldsViewModelConfigurations: AnyPublisher<[TokenInfoPageViewModelConfiguration], Never> = {
        let coinTicker = coinTicker.handleEvents(receiveOutput: { [weak self] ticker in
                self?.ticker = ticker
            }).map { _ in }
            .eraseToAnyPublisher()

        let chartHistories = chartHistoriesSubject
            .map { _ in }
            .eraseToAnyPublisher()

        return Publishers.Merge(coinTicker, chartHistories)
            .compactMap { [weak self] _ in self?.generateConfigurations() }
            .eraseToAnyPublisher()
    }()
    
    lazy var chartViewModel: TokenHistoryChartViewModel = .init(chartHistories: chartHistoriesSubject.eraseToAnyPublisher(), coinTicker: coinTicker)
    lazy var headerViewModel: NonFungibleTokenHeaderViewModel = .init(session: session, transactionType: transactionType, assetDefinitionStore: assetDefinitionStore)

    init(session: WalletSession, transactionType: TransactionType, assetDefinitionStore: AssetDefinitionStore, coinTickersFetcher: CoinTickersFetcherType) {
        self.session = session
        self.coinTickersFetcher = coinTickersFetcher
        self.transactionType = transactionType
        self.assetDefinitionStore = assetDefinitionStore
        super.init()
    }

    func fetchChartHistory() {
        coinTickersFetcher.fetchChartHistories(addressToRPCServerKey: transactionType.tokenObject.addressAndRPCServer, force: false, periods: ChartHistoryPeriod.allCases)
            .done { chartHistories in
                self.chartHistoriesSubject.send(chartHistories)
            }.cauterize()
    }

    private lazy var coinTicker: AnyPublisher<CoinTicker?, Never> = {
        switch transactionType {
        case .nativeCryptocurrency:
            return session.tokenBalanceService
                .etherBalance
                .map { $0?.ticker }
                .receive(on: RunLoop.main)
                .prepend(session.tokenBalanceService.ethBalanceViewModel?.ticker)
                .eraseToAnyPublisher()
        case .erc20Token(let token, _, _):
            return session.tokenBalanceService
                .tokenBalancePublisher(token.addressAndRPCServer)
                .receive(on: RunLoop.main)
                .map { $0?.ticker }
                .prepend(session.tokenBalanceService.coinTicker(token.addressAndRPCServer))
                .eraseToAnyPublisher()
        case .erc875Token, .erc875TokenOrder, .erc721Token, .erc721ForTicketToken, .erc1155Token, .dapp, .tokenScript, .claimPaidErc875MagicLink, .prebuilt:
            return Just<CoinTicker?>(nil)
                .eraseToAnyPublisher()
        }
    }()

    private func generateConfigurations() -> [TokenInfoPageViewModelConfiguration] {
        var configurations: [TokenInfoPageViewModelConfiguration] = []

        if session.server.isTestnet {
            configurations = [
                .testnet
            ]
        } else {
            configurations = [
                .charts,
                .header(viewModel: .init(title: R.string.localizable.tokenInfoHeaderPerformance())),
                .field(viewModel: dayViewModel),
                .field(viewModel: weekViewModel),
                .field(viewModel: monthViewModel),
                .field(viewModel: yearViewModel),

                .header(viewModel: .init(title: R.string.localizable.tokenInfoHeaderStats())),
                .field(viewModel: markerCapViewModel),
                //.field(viewModel: viewModel.totalSupplyViewModel),
                //.field(viewModel: viewModel.maxSupplyViewModel),
                .field(viewModel: yearLowViewModel),
                .field(viewModel: yearHighViewModel)
            ]
        }

        return configurations
    }

    private var valuePercentageChangeValue: String? {
        switch EthCurrencyHelper(ticker: ticker).change24h {
        case .appreciate(let percentageChange24h):
            return "(\(percentageChange24h)%)"
        case .depreciate(let percentageChange24h):
            return "(\(percentageChange24h)%)"
        case .none:
            return nil
        }
    }

    private var markerCapViewModel: TickerFieldValueViewModel {
        let value: String = {
            if let market_cap = ticker?.market_cap {
                return StringFormatter().largeNumberFormatter(for: market_cap, currency: "USD")
            } else {
                return "-"
            }
        }()

        let attributedValue: NSAttributedString = .init(string: value, attributes: [
            .font: Screen.TokenCard.Font.valueChangeValue,
            .foregroundColor: Colors.black
        ])

        return .init(title: R.string.localizable.tokenInfoFieldStatsMarket_cap(), attributedValue: attributedValue)
    }

    private var totalSupplyViewModel: TickerFieldValueViewModel {
        let value: String = {
            if let total_volume = ticker?.total_supply {
                return String(total_volume)
            } else {
                return "-"
            }
        }()

        let attributedValue: NSAttributedString = .init(string: value, attributes: [
            .font: Screen.TokenCard.Font.valueChangeValue,
            .foregroundColor: Colors.black
        ])
        return .init(title: R.string.localizable.tokenInfoFieldStatsTotal_supply(), attributedValue: attributedValue)
    }

    private var maxSupplyViewModel: TickerFieldValueViewModel {
        let value: String = {
            if let max_supply = ticker?.max_supply, let value = Formatter.usd.string(from: max_supply) {
                return String(value)
            } else {
                return "-"
            }
        }()

        let attributedValue: NSAttributedString = .init(string: value, attributes: [
            .font: Screen.TokenCard.Font.valueChangeValue,
            .foregroundColor: Colors.black
        ])
        return .init(title: R.string.localizable.tokenInfoFieldStatsMax_supply(), attributedValue: attributedValue)
    }

    private var yearLowViewModel: TickerFieldValueViewModel {
        let value: String = {
            let history = chartHistories[safe: ChartHistoryPeriod.year.index]
            if let min = HistoryHelper(history: history).minMax?.min, let value = Formatter.usd.string(from: min) {
                return value
            } else {
                return "-"
            }
        }()

        let attributedValue: NSAttributedString = .init(string: value, attributes: [
            .font: Screen.TokenCard.Font.valueChangeValue,
            .foregroundColor: Colors.black
        ])
        return .init(title: R.string.localizable.tokenInfoFieldPerformanceYearLow(), attributedValue: attributedValue)
    }

    private var yearHighViewModel: TickerFieldValueViewModel {
        let value: String = {
            let history = chartHistories[safe: ChartHistoryPeriod.year.index]
            if let max = HistoryHelper(history: history).minMax?.max, let value = Formatter.usd.string(from: max) {
                return value
            } else {
                return "-"
            }
        }()

        let attributedValue: NSAttributedString = .init(string: value, attributes: [
            .font: Screen.TokenCard.Font.valueChangeValue,
            .foregroundColor: Colors.black
        ])
        return .init(title: R.string.localizable.tokenInfoFieldPerformanceYearHigh(), attributedValue: attributedValue)
    }

    private var yearViewModel: TickerFieldValueViewModel {
        let attributedValue: NSAttributedString = attributedHistoryValue(period: ChartHistoryPeriod.year)
        return .init(title: R.string.localizable.tokenInfoFieldStatsYear(), attributedValue: attributedValue)
    }

    private var monthViewModel: TickerFieldValueViewModel {
        let attributedValue: NSAttributedString = attributedHistoryValue(period: ChartHistoryPeriod.month)
        return .init(title: R.string.localizable.tokenInfoFieldStatsMonth(), attributedValue: attributedValue)
    }

    private var weekViewModel: TickerFieldValueViewModel {
        let attributedValue: NSAttributedString = attributedHistoryValue(period: ChartHistoryPeriod.week)
        return .init(title: R.string.localizable.tokenInfoFieldStatsWeek(), attributedValue: attributedValue)
    }

    private var dayViewModel: TickerFieldValueViewModel {
        let attributedValue: NSAttributedString = attributedHistoryValue(period: ChartHistoryPeriod.day)
        return .init(title: R.string.localizable.tokenInfoFieldStatsDay(), attributedValue: attributedValue)
    }

    private func attributedHistoryValue(period: ChartHistoryPeriod) -> NSAttributedString {
        let result: (String, UIColor) = {
            let result = HistoryHelper(history: chartHistories[safe: period.index])

            switch result.change {
            case .appreciate(let percentage, let value):
                let p = Formatter.percent.string(from: percentage) ?? "-"
                let v = Formatter.usd.string(from: value) ?? "-"

                return ("\(v) (\(p)%)", Style.value.appreciated)
            case .depreciate(let percentage, let value):
                let p = Formatter.percent.string(from: percentage) ?? "-"
                let v = Formatter.usd.string(from: value) ?? "-"

                return ("\(v) (\(p)%)", Style.value.depreciated)
            case .none:
                return ("-", Colors.black)
            }
        }()

        return .init(string: result.0, attributes: [
            .font: Screen.TokenCard.Font.valueChangeValue,
            .foregroundColor: result.1
        ])
    }

    var backgroundColor: UIColor {
        return Screen.TokenCard.Color.background
    }
}
