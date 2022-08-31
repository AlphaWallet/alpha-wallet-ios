//
//  TokenHistoryChartView.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 12.05.2021.
//

import UIKit
import Charts
import Combine
import AlphaWalletFoundation

class TokenHistoryChartView: UIView {

    private class YMinMaxOnlyAxisValueFormatter: IAxisValueFormatter {
        //NOTE: helper index for determining right label position
        private var index: Int = 0
        private let formatter = Formatter.fiat

        func stringForValue(_ value: Double, axis: AxisBase?) -> String {
            guard let axis = axis else { return "" }
            func formattedString(for value: Double) -> String {
                return formatter.string(from: value) ?? ""
            }

            let validEntryIndex = index % axis.entries.count
            if validEntryIndex == 0 {
                index += 1

                return formattedString(for: axis.axisMinimum)
            } else if validEntryIndex == axis.entries.count - 1 {
                index = 0
                return formattedString(for: axis.axisMaximum)
            } else {
                index += 1
                return ""
            }
        }
    }

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
        chartView.rightAxis.enabled = true

        chartView.rightAxis.drawGridLinesEnabled = true
        chartView.rightAxis.gridColor = .init(red: 220, green: 220, blue: 220)
        chartView.rightAxis.drawLabelsEnabled = true

        chartView.rightAxis.axisLineColor = .clear
        chartView.rightAxis.labelAlignment = .center
        chartView.rightAxis.labelPosition = .insideChart

        chartView.rightAxis.setLabelCount(5, force: true)
        chartView.rightAxis.valueFormatter = YMinMaxOnlyAxisValueFormatter()

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

    private let viewModel: TokenHistoryChartViewModel
    private var cancelable = Set<AnyCancellable>()

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

        bind(viewModel: viewModel)
        periodSelectorView.set(selectedIndex: viewModel.selectedHistoryIndex)
    } 

    required init?(coder: NSCoder) {
        return nil
    } 

    private func bind(viewModel: TokenHistoryChartViewModel) {
        viewModel.lineChartDataSet
            .receive(on: RunLoop.main)
            .sink { [weak chartView] dataSet in
                guard let set = dataSet else { chartView?.data = nil; return; }

                set.fillFormatter = DefaultFillFormatter { _, _  -> CGFloat in
                    guard let chartView = chartView else { return 0.0 }
                    return CGFloat(chartView.leftAxis.axisMinimum)
                }

                let data: LineChartData = LineChartData(dataSets: [set])
                data.setDrawValues(false)

                chartView?.data = data
            }.store(in: &cancelable)
    }
}

extension TokenHistoryChartView: TokenHistoryPeriodSelectorViewDelegate {
    func view(_ view: TokenHistoryPeriodSelectorView, didChangeSelection selection: ControlSelection) {
        switch selection {
        case .selected(let index):
            viewModel.set(selectedHistoryIndex: Int(index))
        case .unselected:
            break
        }
    }
}
