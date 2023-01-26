//
//  TokenHistoryChartViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 20.05.2022.
//

import UIKit
import Combine
import Charts
import AlphaWalletFoundation

struct TokenHistoryChartViewModelInput {
    let selection: AnyPublisher<Int, Never>
}

struct TokenHistoryChartViewModelOutput {
    let viewState: AnyPublisher<TokenHistoryChartViewModel.ViewState, Never>
}

class TokenHistoryChartViewModel {
    private let chartHistories: AnyPublisher<[ChartHistoryPeriod: ChartHistory], Never>
    private let coinTicker: AnyPublisher<CoinTicker?, Never>
    private let currencyService: CurrencyService

    var periodTitles: [String] = ChartHistoryPeriod.allCases.map { $0.title }
    var initialSelectionIndex: Int { return 0 }
    var setGradientFill: Fill? {
        return ColorFill(color: Configuration.Color.Semantic.backgroundClear)
    }

    init(chartHistories: AnyPublisher<[ChartHistoryPeriod: ChartHistory], Never>, coinTicker: AnyPublisher<CoinTicker?, Never>, currencyService: CurrencyService) {
        self.chartHistories = chartHistories
        self.coinTicker = coinTicker
        self.currencyService = currencyService
    }

    func transform(input: TokenHistoryChartViewModelInput) -> TokenHistoryChartViewModelOutput {
        let selection = input.selection
            .merge(with: Just(initialSelectionIndex))
            .compactMap { ChartHistoryPeriod(index: $0) }

        let lineDataSets = Publishers.CombineLatest(chartHistories, coinTicker)
            .map { chartHistories, ticker -> [ChartHistoryPeriod: LineChartDataSet] in
                return chartHistories.compactMapValues { history in
                    if !history.prices.isEmpty {
                        let chartEntries = history.prices.map { ChartDataEntry(x: $0.timestamp, y: $0.value) }
                        return self.buildLineChartDataSet(for: chartEntries, ticker: ticker)
                    } else {
                        return nil
                    }
                }
            }.receive(on: RunLoop.main)

        let currency = coinTicker
            .compactMap { [currencyService] in $0?.currency ?? currencyService.currency }

        let viewState = Publishers.CombineLatest3(selection, lineDataSets, currency)
            .map { ViewState(currency: $2, lineChartDataSet: $1[$0]) }
            .eraseToAnyPublisher()

        return .init(viewState: viewState)
    }

    private func buildLineChartDataSet(for entries: [ChartDataEntry], ticker: CoinTicker?) -> LineChartDataSet {
        let set = LineChartDataSet(entries: entries, label: "")
        set.axisDependency = .left
        set.setColor(chartSetColorForTicker(ticker: ticker))
        set.drawCirclesEnabled = false
        set.lineWidth = 2
        set.fillAlpha = 1
        set.drawFilledEnabled = true
        set.fill = setGradientFill
        set.highlightColor = chartSelectionColorForTicker(ticker: ticker)
        set.drawCircleHoleEnabled = false

        return set
    }

    private func chartSetColorForTicker(ticker: CoinTicker?) -> UIColor {
        gradientColorForTicker(ticker: ticker)
    }

    private func chartSelectionColorForTicker(ticker: CoinTicker?) -> UIColor {
        gradientColorForTicker(ticker: ticker)
    }

    private func gradientColorForTicker(ticker: CoinTicker?) -> UIColor {
        switch TickerHelper(ticker: ticker).change24h {
        case .appreciate, .none:
            return Configuration.Color.Semantic.appreciation
        case .depreciate:
            return  Configuration.Color.Semantic.depreciation
        }
    }
}

extension TokenHistoryChartViewModel {
    struct ViewState {
        let currency: Currency
        let lineChartDataSet: LineChartDataSet?
    }
}
