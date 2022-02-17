//
//  AlertsViewController.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 16.09.2021.
//

import UIKit

protocol EditPriceAlertViewControllerDelegate: class {
    func didUpdateAlert(in viewController: EditPriceAlertViewController)
}

class EditPriceAlertViewController: UIViewController {

    private lazy var headerView: SendViewSectionHeader = {
        let view = SendViewSectionHeader()
        view.configure(viewModel: .init(text: viewModel.headerTitle))

        return view
    }()

    private lazy var amountTextField: AmountTextField = {
        let view = AmountTextField(tokenObject: viewModel.tokenObject)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.delegate = self
        view.accessoryButtonTitle = .next
        view.errorState = .none

        view.togglePair()

        view.isAlternativeAmountEnabled = false
        view.allFundsAvailable = false
        view.selectCurrencyButton.isHidden = false
        view.selectCurrencyButton.expandIconHidden = true
        view.statusLabel.text = nil
        view.availableTextHidden = false

        return view
    }()

    private let buttonsBar = ButtonsBar(configuration: .primary(buttons: 1))
    private lazy var containerView: ScrollableStackView = {
        let view = ScrollableStackView()
        return view
    }()

    private var viewModel: EditPriceAlertViewModel
    private let session: WalletSession
    private var subscription: Subscribable<BalanceBaseViewModel>.SubscribableKey?
    private let alertService: PriceAlertServiceType

    weak var delegate: EditPriceAlertViewControllerDelegate?

    init(viewModel: EditPriceAlertViewModel, session: WalletSession, alertService: PriceAlertServiceType) {
        self.viewModel = viewModel
        self.session = session
        self.alertService = alertService
        super.init(nibName: nil, bundle: nil)

        let footerBar = ButtonsBarBackgroundView(buttonsBar: buttonsBar, separatorHeight: 0)
        view.addSubview(footerBar)
        view.addSubview(containerView)

        NSLayoutConstraint.activate([
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            containerView.topAnchor.constraint(equalTo: view.topAnchor),
            containerView.bottomAnchor.constraint(equalTo: footerBar.topAnchor),

            footerBar.anchorsConstraint(to: view),
        ])

        generateSubviews(viewModel: viewModel)

        buttonsBar.configure()
        buttonsBar.buttons[0].setTitle(viewModel.setAlertTitle, for: .normal)
        buttonsBar.buttons[0].addTarget(self, action: #selector(saveAlertSelected), for: .touchUpInside)

        configure(viewModel: viewModel)
        //NOTE: we want to enter only fiat value, as `amountTextField` accepts eth we have to convert it with 1 to 1 rate
        amountTextField.cryptoToDollarRate = 1
        amountTextField.set(ethCost: viewModel.value, useFormatting: false)

        switch viewModel.tokenObject.type {
        case .nativeCryptocurrency:
            subscription = session.balanceCoordinator.subscribableEthBalanceViewModel.subscribe { [weak self] viewModel in
                guard let strongSelf = self else { return }

                strongSelf.viewModel.set(marketPrice: viewModel?.ticker?.price_usd)
                strongSelf.configure(viewModel: strongSelf.viewModel)
            }
        case .erc20:
            subscription = session.balanceCoordinator.subscribableTokenBalance(viewModel.tokenObject.addressAndRPCServer).subscribe { [weak self] viewModel in
                guard let strongSelf = self else { return }

                strongSelf.viewModel.set(marketPrice: viewModel?.ticker?.price_usd)
                strongSelf.configure(viewModel: strongSelf.viewModel)
            }
        case .erc875, .erc721, .erc721ForTickets, .erc1155:
            break
        }
    }

    func configure(viewModel: EditPriceAlertViewModel) {
        self.viewModel = viewModel
        view.backgroundColor = viewModel.backgroundColor
        title = viewModel.navigationTitle

        containerView.configure(viewModel: .init(backgroundColor: viewModel.backgroundColor))

        amountTextField.statusLabel.text = viewModel.marketPriceString
        buttonsBar.buttons[0].isEnabled = viewModel.isEditingAvailable
    }

    private func generateSubviews(viewModel: EditPriceAlertViewModel) {
        containerView.stackView.removeAllArrangedSubviews()

        let subViews: [UIView] = [
            headerView,
            .spacer(height: 34),
            amountTextField.defaultLayout(edgeInsets: .init(top: 0, left: 16, bottom: 0, right: 16))
        ] 

        containerView.stackView.addArrangedSubviews(subViews)
    }

    @objc private func saveAlertSelected(_ sender: UIButton) {
        guard let value = amountTextField.value.flatMap({ Formatter.default.number(from: $0) }), let marketPrice = viewModel.marketPrice else { return }

        switch viewModel.configuration {
        case .create:
            let alert: PriceAlert = .init(type: .init(value: value.doubleValue, marketPrice: marketPrice), tokenObject: viewModel.tokenObject, isEnabled: true)
            alertService.add(alert: alert).done { _ in
                self.delegate?.didUpdateAlert(in: self)
            }.cauterize()
        case .edit(let alert):
            alertService.update(alert: alert, update: .value(value: value.doubleValue, marketPrice: marketPrice)).done { _ in
                self.delegate?.didUpdateAlert(in: self)
            }.cauterize()
        }
    }

    required init?(coder: NSCoder) {
        return nil
    }
}

extension EditPriceAlertViewController: AmountTextFieldDelegate {
    func changeAmount(in textField: AmountTextField) {
        // no-op
    }

    func changeType(in textField: AmountTextField) {
        // no-op
    }

    func shouldReturn(in textField: AmountTextField) -> Bool {
        return true
    }
}
