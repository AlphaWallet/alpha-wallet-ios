//
//  InfoPageView.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 12.05.2021.
//

import UIKit

protocol TokenInfoPageViewDelegate: class {
    func didPressViewContractWebPage(forContract contract: AlphaWallet.Address, in tokenInfoPageView: TokenInfoPageView)
}

class TokenInfoPageView: UIView, TokenPageViewType {
    private let headerViewRefreshInterval: TimeInterval = 5.0

    var title: String {
        return viewModel.tabTitle
    }

    private let headerView = SendHeaderView()
    private lazy var chartView: TokenHistoryChartView = {
        let viewModel = TokenHistoryChartViewModel(values: [], ticker: nil)
        let chartView = TokenHistoryChartView(viewModel: viewModel)

        return chartView
    }()

    private let stackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 0
        stackView.translatesAutoresizingMaskIntoConstraints = false

        return stackView
    }()

    private lazy var scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stackView)
        return scrollView
    }()

    lazy var viewModel = TokenInfoPageViewModel(server: server, token: token, transactionType: transactionType)
    weak var delegate: TokenInfoPageViewDelegate?
    private var headerRefreshTimer: Timer!

    private let server: RPCServer
    private let token: TokenObject
    private let transactionType: TransactionType

    init(server: RPCServer, token: TokenObject, transactionType: TransactionType) {
        self.server = server
        self.token = token
        self.transactionType = transactionType
        super.init(frame: .zero)

        translatesAutoresizingMaskIntoConstraints = false 

        addSubview(scrollView)

        NSLayoutConstraint.activate([
            scrollView.centerYAnchor.constraint(equalTo: centerYAnchor),
            scrollView.centerXAnchor.constraint(equalTo: centerXAnchor),
            scrollView.widthAnchor.constraint(equalTo: widthAnchor),
            scrollView.heightAnchor.constraint(equalTo: heightAnchor),
            
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor),
            stackView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            stackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
        ])

        generateSubviews(viewModel: viewModel)

        headerRefreshTimer = Timer(timeInterval: headerViewRefreshInterval, repeats: true) { [weak self] _ in
            self?.refreshHeaderView()
        }

        RunLoop.main.add(headerRefreshTimer, forMode: .default)
        headerView.delegate = self
    }

    private func generateSubviews(viewModel: TokenInfoPageViewModel) {
        stackView.removeAllArrangedSubviews()

        stackView.addArrangedSubview(headerView)
        stackView.addArrangedSubview(chartView)

        stackView.addArrangedSubview(UIView.spacer(height: 10))
        stackView.addArrangedSubview(UIView.separator())
        stackView.addArrangedSubview(UIView.spacer(height: 10))

        let perfomanceHeader = TokenInfoHeaderView()
        perfomanceHeader.configure(viewModel: .init(title: R.string.localizable.tokenInfoHeaderPerfomance()))

        stackView.addArrangedSubview(perfomanceHeader)

        let view7 = TickerFieldValueView()

        view7.configure(viewModel: viewModel.dayViewModel)
        stackView.addArrangedSubview(view7)

        let view9 = TickerFieldValueView()

        view9.configure(viewModel: viewModel.weekViewModel)
        stackView.addArrangedSubview(view9)

        let view10 = TickerFieldValueView()

        view10.configure(viewModel: viewModel.monthViewModel)
        stackView.addArrangedSubview(view10)

        let view6 = TickerFieldValueView()

        view6.configure(viewModel: viewModel.yearViewModel)
        stackView.addArrangedSubview(view6)

        let statsHeader = TokenInfoHeaderView()
        statsHeader.configure(viewModel: .init(title: R.string.localizable.tokenInfoHeaderStats()))

        stackView.addArrangedSubview(statsHeader)

        let view5 = TickerFieldValueView()

        view5.configure(viewModel: viewModel.markerCapViewModel)
        stackView.addArrangedSubview(view5)

        let view1 = TickerFieldValueView()

        view1.configure(viewModel: viewModel.totalVolumeViewModel)
        stackView.addArrangedSubview(view1)

        let view13 = TickerFieldValueView()

        view13.configure(viewModel: viewModel.maxSupplyViewModel)
        stackView.addArrangedSubview(view13)

        let view14 = TickerFieldValueView()

        view14.configure(viewModel: viewModel.yearLowViewModel)
        stackView.addArrangedSubview(view14)

        let view15 = TickerFieldValueView()

        view15.configure(viewModel: viewModel.yearHightViewModel)
        stackView.addArrangedSubview(view15)
    }

    func configure(viewModel: TokenInfoPageViewModel) {
        self.viewModel = viewModel
        
        generateSubviews(viewModel: viewModel)

        var chartViewModel = chartView.viewModel
        chartViewModel.ticker = viewModel.ticker
        chartViewModel.values = viewModel.values

        chartView.configure(viewModel: chartViewModel)
        headerView.configure(viewModel: viewModel)
    }

    required init?(coder: NSCoder) {
        return nil
    }

    @objc private func refreshHeaderView() {
        viewModel.isShowingValue.toggle()
        headerView.configure(viewModel: viewModel)
    }
}

extension TokenInfoPageView: SendHeaderViewDelegate {

    func didPressViewContractWebPage(inHeaderView: SendHeaderView) {
        delegate?.didPressViewContractWebPage(forContract: transactionType.contract, in: self)
    }

    func showHideMarketPriceSelected(inHeaderView: SendHeaderView) {
        refreshHeaderView()
    }
}

extension UIView {
    static func separator(backgroundColor: UIColor = R.color.mike()!) -> UIView {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = backgroundColor

        NSLayoutConstraint.activate([
            view.heightAnchor.constraint(equalToConstant: 1)
        ])

        return view
    }
}
