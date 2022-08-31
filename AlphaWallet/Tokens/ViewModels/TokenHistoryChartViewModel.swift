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

class TokenHistoryChartViewModel {
    private var selectedHistoryIndexSubject: CurrentValueSubject<Int, Never> = .init(0)
    private let chartHistories: AnyPublisher<[ChartHistory], Never>
    private let coinTicker: AnyPublisher<CoinTicker?, Never>
    private var chartDataForSelectedIndex: AnyPublisher<[ChartDataEntry]?, Never> {
        chartHistories.combineLatest(selectedHistoryIndexSubject)
            .map { chartHistories, index in
                if let history = chartHistories[safe: index], !history.prices.isEmpty {
                    return history.prices.map { ChartDataEntry(x: $0.timestamp, y: $0.value) }
                } else {
                    return nil
                }
            }.eraseToAnyPublisher()
    }

    var lineChartDataSet: AnyPublisher<LineChartDataSet?, Never> {
        chartDataForSelectedIndex.combineLatest(coinTicker).map { [weak self] entries, ticker -> LineChartDataSet? in
            guard let strongSelf = self else { return nil }

            return entries.flatMap { entries in
                let set = LineChartDataSet(entries: entries, label: "")
                set.axisDependency = .left
                set.setColor(strongSelf.chartSetColorForTicker(ticker: ticker))
                set.drawCirclesEnabled = false
                set.lineWidth = 2
                set.fillAlpha = 1
                set.drawFilledEnabled = true
                set.fill = strongSelf.setGradientFill
                set.highlightColor = strongSelf.chartSelectionColorForTicker(ticker: ticker)
                set.drawCircleHoleEnabled = false

                return set
            }
        }.eraseToAnyPublisher()
    }
    var periodTitles: [String] = ChartHistoryPeriod.allCases.map { $0.title }
    var separatorBackgroundColor: UIColor = Colors.darkGray.withAlphaComponent(0.5)
    var selectedHistoryIndex: Int {
        selectedHistoryIndexSubject.value
    }

    init(chartHistories: AnyPublisher<[ChartHistory], Never>, coinTicker: AnyPublisher<CoinTicker?, Never>) {
        self.chartHistories = chartHistories
        self.coinTicker = coinTicker
    } 

    func set(selectedHistoryIndex: Int) {
        self.selectedHistoryIndexSubject.send(selectedHistoryIndex)
    }

    var setGradientFill: Fill? {
        return Fill.fillWithCGColor(UIColor.clear.cgColor)
    }

    private func chartSetColorForTicker(ticker: CoinTicker?) -> UIColor {
        gradientColorForTicker(ticker: ticker)
    }
    private func chartSelectionColorForTicker(ticker: CoinTicker?) -> UIColor {
        gradientColorForTicker(ticker: ticker)
    }
    private func gradientColorForTicker(ticker: CoinTicker?) -> UIColor {
        switch EthCurrencyHelper(ticker: ticker).change24h {
        case .appreciate, .none:
            return Colors.appActionButtonGreen
        case .depreciate:
            return Colors.appRed
        }
    }
}
