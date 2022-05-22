//
//  InfoPageView.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 12.05.2021.
//

import UIKit
import Combine

protocol TokenInfoPageViewDelegate: class {
    func didPressViewContractWebPage(forContract contract: AlphaWallet.Address, in tokenInfoPageView: TokenInfoPageView)
}

class TokenInfoPageView: UIView, PageViewType {
    private lazy var headerView = NonFungibleTokenHeaderView(viewModel: viewModel.headerViewModel)
    private lazy var chartView: TokenHistoryChartView = {
        let chartView = TokenHistoryChartView(viewModel: viewModel.chartViewModel)
        return chartView
    }()

    private var stackView: UIStackView {
        return containerView.stackView
    }

    private lazy var containerView: ScrollableStackView = {
        let view = ScrollableStackView()
        return view
    }()

    private let viewModel: TokenInfoPageViewModel
    private var cancelable = Set<AnyCancellable>()

    weak var delegate: TokenInfoPageViewDelegate?
    var rightBarButtonItem: UIBarButtonItem?
    var title: String { return viewModel.tabTitle }

    init(viewModel: TokenInfoPageViewModel) {
        self.viewModel = viewModel
        super.init(frame: .zero)

        translatesAutoresizingMaskIntoConstraints = false

        addSubview(containerView)

        NSLayoutConstraint.activate([containerView.anchorsConstraint(to: self)])

        headerView.delegate = self

        bind(viewModel: viewModel)
    }

    private func generateSubviews(configurations: [TokenInfoPageViewModelConfiguration]) {
        stackView.removeAllArrangedSubviews()

        stackView.addArrangedSubview(headerView)

        for each in configurations {
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

    private func bind(viewModel: TokenInfoPageViewModel) {
        viewModel.fieldsViewModelConfigurations
            .sink { [weak self] configurations in
                self?.generateSubviews(configurations: configurations)
            }.store(in: &cancelable)
    }

    required init?(coder: NSCoder) {
        return nil
    }
}

extension TokenInfoPageView: NonFungibleTokenHeaderViewDelegate {

    func didPressViewContractWebPage(inHeaderView: NonFungibleTokenHeaderView) {
        delegate?.didPressViewContractWebPage(forContract: viewModel.transactionType.contract, in: self)
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
