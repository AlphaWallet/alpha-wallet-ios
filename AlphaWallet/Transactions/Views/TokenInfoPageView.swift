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

class TokenInfoPageView: UIView, PageViewType {
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

    private var stackView: UIStackView {
        return containerView.stackView
    }

    private lazy var containerView: ScrollableStackView = {
        let view = ScrollableStackView()
        return view
    }()
    private let config: Config
    lazy var viewModel = TokenInfoPageViewModel(server: server, token: token, transactionType: transactionType)
    weak var delegate: TokenInfoPageViewDelegate?
    private var headerRefreshTimer: Timer?

    private let server: RPCServer
    private let token: TokenObject
    private let transactionType: TransactionType
    var rightBarButtonItem: UIBarButtonItem?

    init(server: RPCServer, token: TokenObject, config: Config, transactionType: TransactionType) {
        self.server = server
        self.token = token
        self.config = config
        self.transactionType = transactionType
        super.init(frame: .zero)

        translatesAutoresizingMaskIntoConstraints = false

        addSubview(containerView)

        NSLayoutConstraint.activate([containerView.anchorsConstraint(to: self)])

        generateSubviews(viewModel: viewModel)

        let timer = Timer(timeInterval: headerViewRefreshInterval, repeats: true) { [weak self] _ in
            self?.refreshHeaderView()
        }

        RunLoop.main.add(timer, forMode: .default)
        headerRefreshTimer = timer

        headerView.delegate = self
    }

    deinit {
        headerRefreshTimer?.invalidate()
        headerRefreshTimer = nil
    }

    private func generateSubviews(viewModel: TokenInfoPageViewModel) {
        stackView.removeAllArrangedSubviews()

        stackView.addArrangedSubview(headerView)

        for each in viewModel.configurations {
            switch each {
            case .testnet:
                stackView.addArrangedSubview(UIView.spacer(height: 40))
                stackView.addArrangedSubview(UIView.separator())

                let view = TestnetTokenInfoView()
                view.configure(viewModel: .init())

                stackView.addArrangedSubview(view)
            case .charts:
                stackView.addArrangedSubview(chartView)

                stackView.addArrangedSubview(UIView.spacer(height: 10))
                stackView.addArrangedSubview(UIView.separator())
                stackView.addArrangedSubview(UIView.spacer(height: 10))
            case .field(let viewModel):
                let view = TickerFieldValueView()
                view.configure(viewModel: viewModel)

                stackView.addArrangedSubview(view)
            case .header(let viewModel):
                let perfomanceHeader = TokenInfoHeaderView()
                perfomanceHeader.configure(viewModel: viewModel)

                stackView.addArrangedSubview(perfomanceHeader)
            }
        }
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
