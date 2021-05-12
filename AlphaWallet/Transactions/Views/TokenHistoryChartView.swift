//
//  TokenHistoryChartView.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 12.05.2021.
//

import UIKit
import Charts

struct TokenHistoryChartViewModel {
    var values: [ChartHistory]
    var ticker: CoinTicker?

    var selectedHistoryIndex: Int = 0
    var periodTitles: [String] = ChartHistoryPeriod.allCases.map { $0.title }
    var separatorBackgroundColor: UIColor = Colors.darkGray.withAlphaComponent(0.5)
    var chartSetColor: UIColor { gradientColor }
    var chartSelectionColor: UIColor { gradientColor }
    
    private var gradientColor: UIColor {
        switch EthCurrencyHelper(ticker: ticker).change24h {
        case .appreciate, .none:
            return Colors.appActionButtonGreen
        case .depreciate:
            return Colors.appRed
        }
    }

    var setGradientFill: Fill? {
        let gradientColors = [gradientColor.withAlphaComponent(0.1).cgColor, Colors.appWhite.cgColor] as CFArray
        if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: gradientColors, locations: [1.0, 0.0]) {
            return Fill.fillWithLinearGradient(gradient, angle: 90.0)
        } else {
            return nil
        }
    }
}

class TokenHistoryChartView: UIView {

    private lazy var chartView: LineChartView = {
        let chartView = LineChartView()

        chartView.translatesAutoresizingMaskIntoConstraints = false
        chartView.backgroundColor = .white
        chartView.drawGridBackgroundEnabled = false
        chartView.drawBordersEnabled = false

        chartView.chartDescription?.enabled = false

        chartView.pinchZoomEnabled = false
        chartView.dragEnabled = true
        chartView.setScaleEnabled(false)
        chartView.legend.enabled = false

        chartView.xAxis.enabled = false

        chartView.leftAxis.enabled = false
        chartView.rightAxis.enabled = false

        let marker = XYMarkerView(color: Colors.darkGray,
                                  font: Fonts.regular(size: 12),
                                  textColor: Colors.appWhite,
                                  insets: UIEdgeInsets(top: 8, left: 8, bottom: 20, right: 8))
        marker.chartView = chartView
        marker.minimumSize = CGSize(width: 80, height: 40)
        chartView.marker = marker

        return chartView
    }()

    private lazy var periodSelectorView: TokenHistoryPeriodSelectorView = {
        let view = TokenHistoryPeriodSelectorView(viewModel: .init(titles: viewModel.periodTitles))
        view.delegate = self

        return view
    }()

    private (set) var viewModel: TokenHistoryChartViewModel

    init(viewModel: TokenHistoryChartViewModel) {
        self.viewModel = viewModel
        super.init(frame: .zero)

        addSubview(chartView)
        addSubview(periodSelectorView)

        NSLayoutConstraint.activate([
            chartView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: -10),
            chartView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: 10),
            chartView.topAnchor.constraint(equalTo: topAnchor),
            chartView.bottomAnchor.constraint(equalTo: periodSelectorView.topAnchor),

            chartView.heightAnchor.constraint(equalToConstant: 250),

            periodSelectorView.leadingAnchor.constraint(equalTo: leadingAnchor),
            periodSelectorView.trailingAnchor.constraint(equalTo: trailingAnchor),
            periodSelectorView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        configure(viewModel: viewModel)
        periodSelectorView.set(selectedIndex: viewModel.selectedHistoryIndex)
    } 

    required init?(coder: NSCoder) {
        return nil
    }

    func configure(viewModel: TokenHistoryChartViewModel) {
        self.viewModel = viewModel
        
        fillChartView(viewModel: viewModel)
    }

    private func fillChartView(viewModel: TokenHistoryChartViewModel) {
        if let history = viewModel.values[safe: viewModel.selectedHistoryIndex], !history.prices.isEmpty {
            let entries = history.prices.map { value -> ChartDataEntry in
                return ChartDataEntry(x: value.timestamp, y: value.value)
            }

            let set = LineChartDataSet(entries: entries, label: "")
            set.axisDependency = .left
            set.setColor(viewModel.chartSetColor)
            set.drawCirclesEnabled = false
            set.lineWidth = 2
            set.fillAlpha = 1
            set.drawFilledEnabled = true
            set.fill = viewModel.setGradientFill
            set.highlightColor = viewModel.chartSelectionColor
            set.drawCircleHoleEnabled = false
            set.fillFormatter = DefaultFillFormatter { _, _  -> CGFloat in
                return CGFloat(self.chartView.leftAxis.axisMinimum)
            }

            let data: LineChartData = LineChartData(dataSets: [set])
            data.setDrawValues(false)

            chartView.data = data
        } else {
            chartView.data = nil
        }
    }
}

extension TokenHistoryChartView: TokenHistoryPeriodSelectorViewDelegate {
    func view(_ view: TokenHistoryPeriodSelectorView, didChangeSelection selection: SegmentedControl.Selection) {
        switch selection {
        case .selected(let index):
            viewModel.selectedHistoryIndex = Int(index)
        case .unselected:
            break
        }
        configure(viewModel: viewModel)
    }
}

extension Collection where Indices.Iterator.Element == Index {

    /// Returns the element at the specified index if it is within bounds, otherwise nil.
    subscript (safe index: Index) -> Iterator.Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
