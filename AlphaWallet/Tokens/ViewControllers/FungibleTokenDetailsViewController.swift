//
//  FungibleTokenDetailsViewController.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 19.11.2022.
//

import UIKit
import Combine
import AlphaWalletFoundation

protocol FungibleTokenDetailsViewControllerDelegate: AnyObject, CanOpenURL {
    func didTapSwap(swapTokenFlow: SwapTokenFlow, in viewController: FungibleTokenDetailsViewController)
    func didTapBridge(for token: Token, service: TokenActionProvider, in viewController: FungibleTokenDetailsViewController)
    func didTapBuy(for token: Token, service: TokenActionProvider, in viewController: FungibleTokenDetailsViewController)
    func didTapSend(for token: Token, in viewController: FungibleTokenDetailsViewController)
    func didTapReceive(for token: Token, in viewController: FungibleTokenDetailsViewController)
    func didTap(action: TokenInstanceAction, token: Token, in viewController: FungibleTokenDetailsViewController)
}

class FungibleTokenDetailsViewController: UIViewController {
    private let containerView: ScrollableStackView = ScrollableStackView()
    private let buttonsBar = HorizontalButtonsBar(configuration: .combined(buttons: 2))
    private lazy var headerView: FungibleTokenHeaderView = {
        let view = FungibleTokenHeaderView(viewModel: viewModel.headerViewModel)
        view.delegate = self

        return view
    }()
    private lazy var chartView: TokenHistoryChartView = {
        let chartView = TokenHistoryChartView(viewModel: viewModel.chartViewModel)
        return chartView
    }()
    
    private let viewModel: FungibleTokenDetailsViewModel
    private var cancelable = Set<AnyCancellable>()
    private let willAppear = PassthroughSubject<Void, Never>()

    weak var delegate: FungibleTokenDetailsViewControllerDelegate?

    init(viewModel: FungibleTokenDetailsViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)

        let footerBar = ButtonsBarBackgroundView(buttonsBar: buttonsBar)
        view.addSubview(footerBar)
        view.addSubview(containerView)

        NSLayoutConstraint.activate([
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            containerView.topAnchor.constraint(equalTo: view.topAnchor),
            containerView.bottomAnchor.constraint(equalTo: footerBar.topAnchor),

            footerBar.anchorsConstraint(to: view)
        ])

        buttonsBar.viewController = self
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = Configuration.Color.Semantic.defaultViewBackground

        bind(viewModel: viewModel)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        willAppear.send(())
    }

    private func buildSubviews(for viewTypes: [FungibleTokenDetailsViewModel.ViewType]) -> [UIView] {
        var subviews: [UIView] = []
        subviews += [headerView]

        for each in viewTypes {
            switch each {
            case .testnet:
                subviews += [UIView.spacer(height: 40)]
                subviews += [UIView.spacer(backgroundColor: Configuration.Color.Semantic.tableViewSeparator)]

                let view = TestnetTokenInfoView()
                view.configure(viewModel: .init())

                subviews += [view]
            case .charts:
                subviews += [chartView]

                subviews += [UIView.spacer(height: 10)]
                subviews += [UIView.spacer(backgroundColor: Configuration.Color.Semantic.tableViewSeparator)]
                subviews += [UIView.spacer(height: 10)]
            case .field(let viewModel):
                let view = TokenAttributeView(indexPath: IndexPath(row: 0, section: 0))
                view.configure(viewModel: viewModel)

                subviews += [view]
            case .header(let viewModel):
                let view = TokenInfoHeaderView()
                view.configure(viewModel: viewModel)

                subviews += [view]
            }
        }

        return subviews
    }

    private func layoutSubviews(_ subviews: [UIView]) {
        containerView.stackView.removeAllArrangedSubviews()
        containerView.stackView.addArrangedSubviews(subviews)
    }

    private func bind(viewModel: FungibleTokenDetailsViewModel) {
        let input = FungibleTokenDetailsViewModelInput(willAppear: willAppear.eraseToAnyPublisher())
        let output = viewModel.transform(input: input)
        output.viewState
            .sink { [weak self] viewState in
                guard let strongSelf = self else { return }

                strongSelf.layoutSubviews(strongSelf.buildSubviews(for: viewState.views))
                strongSelf.configureActionButtons(with: viewState.actions)
            }.store(in: &cancelable)
    }

    required init?(coder: NSCoder) {
        return nil
    }

    private func configureActionButtons(with actions: [TokenInstanceAction]) {
        buttonsBar.configure(.combined(buttons: actions.count))

        for (action, button) in zip(actions, buttonsBar.buttons) {
            button.setTitle(action.name, for: .normal)
            button.addTarget(self, action: #selector(actionButtonTapped), for: .touchUpInside)

            switch viewModel.buttonState(for: action) {
            case .isEnabled(let isEnabled):
                button.isEnabled = isEnabled
            case .isDisplayed(let isDisplayed):
                button.displayButton = isDisplayed
            case .noOption:
                continue
            }
        }
    }

    @objc private func actionButtonTapped(sender: UIButton) {
        for (action, button) in zip(viewModel.actions, buttonsBar.buttons) where button == sender {
            switch action.type {
            case .swap:
                delegate?.didTapSwap(swapTokenFlow: .swapToken(token: viewModel.token), in: self)
            case .erc20Send:
                delegate?.didTapSend(for: viewModel.token, in: self)
            case .erc20Receive:
                delegate?.didTapReceive(for: viewModel.token, in: self)
            case .nftRedeem, .nftSell, .nonFungibleTransfer:
                break
            case .tokenScript:
                if let message = viewModel.tokenScriptWarningMessage(for: action) {
                    guard case .warning(let string) = message else { return }
                    show(message: string)
                } else {
                    delegate?.didTap(action: action, token: viewModel.token, in: self)
                }
            case .bridge(let service):
                delegate?.didTapBridge(for: viewModel.token, service: service, in: self)
            case .buy(let service):
                delegate?.didTapBuy(for: viewModel.token, service: service, in: self)
            }
            break
        }
    }

    private func show(message: String) {
        UIAlertController.alert(message: message, alertButtonTitles: [R.string.localizable.oK()], alertButtonStyles: [.default], viewController: self)
    }

}

extension FungibleTokenDetailsViewController: FungibleTokenHeaderViewDelegate {

    func didPressViewContractWebPage(inHeaderView: FungibleTokenHeaderView) {
        delegate?.didPressViewContractWebPage(forContract: viewModel.token.contractAddress, server: viewModel.token.server, in: self)
    }
}
