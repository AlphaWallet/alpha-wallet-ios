//
//  AlertsViewController.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 16.09.2021.
//

import UIKit
import Combine
import AlphaWalletFoundation

protocol EditPriceAlertViewControllerDelegate: class {
    func didUpdateAlert(in viewController: EditPriceAlertViewController)
    func didClose(in viewController: EditPriceAlertViewController)
}

class EditPriceAlertViewController: UIViewController {

    private lazy var headerView: SendViewSectionHeader = {
        let view = SendViewSectionHeader()
        view.configure(viewModel: .init(text: viewModel.headerTitle))

        return view
    }()

    private lazy var amountTextField: AmountTextField_v2 = {
        let view = AmountTextField_v2(token: viewModel.token)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.delegate = self
        view.viewModel.accessoryButtonTitle = .next
        view.viewModel.errorState = .none
        view.viewModel.toggleFiatAndCryptoPair()

        view.isAlternativeAmountEnabled = false
        view.allFundsAvailable = false
        view.selectCurrencyButton.isHidden = false
        view.selectCurrencyButton.expandIconHidden = true
        view.statusLabel.text = nil
        view.availableTextHidden = false
        view.selectCurrencyButton.hasToken = true

        return view
    }()

    private let buttonsBar = HorizontalButtonsBar(configuration: .primary(buttons: 1))
    private lazy var containerView: ScrollableStackView = {
        let view = ScrollableStackView()
        return view
    }()

    private let viewModel: EditPriceAlertViewModel
    private let appear = PassthroughSubject<Void, Never>()
    private var cancelable = Set<AnyCancellable>()

    weak var delegate: EditPriceAlertViewControllerDelegate?

    init(viewModel: EditPriceAlertViewModel) {
        self.viewModel = viewModel
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
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        buttonsBar.configure()
        buttonsBar.buttons[0].setTitle(viewModel.setAlertTitle, for: .normal)

        bind(viewModel: viewModel)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        appear.send(())
    }

    private func bind(viewModel: EditPriceAlertViewModel) {
        view.backgroundColor = viewModel.backgroundColor
        title = viewModel.title

        containerView.configure(viewModel: .init(backgroundColor: viewModel.backgroundColor))

        let save = buttonsBar.buttons[0].publisher(forEvent: .touchUpInside).eraseToAnyPublisher()

        let input = EditPriceAlertViewModelInput(appear: appear.eraseToAnyPublisher(), save: save, cryptoValue: amountTextField.cryptoValue)
        let output = viewModel.transform(input: input)

        output.cryptoToFiatRate
            .assign(to: \.value, on: amountTextField.viewModel.cryptoToFiatRate, ownership: .weak)
            .store(in: &cancelable)

        output.cryptoInitial
            .sink { [weak amountTextField] in amountTextField?.set(crypto: $0, useFormatting: false) }
            .store(in: &cancelable)

        output.marketPrice
            .sink { [weak amountTextField] in amountTextField?.statusLabel.text = $0 }
            .store(in: &cancelable)

        output.isEnabled
            .sink { [weak buttonsBar] in buttonsBar?.buttons[0].isEnabled = $0 }
            .store(in: &cancelable)

        output.createOrUpdatePriceAlert
            .sink {
                switch $0 {
                case .success: self.delegate?.didUpdateAlert(in: self)
                case .failure: break
                }
            }.store(in: &cancelable)
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

    required init?(coder: NSCoder) {
        return nil
    }
}

extension EditPriceAlertViewController: PopNotifiable {
    func didPopViewController(animated: Bool) {
        delegate?.didClose(in: self)
    }
}

extension EditPriceAlertViewController: AmountTextField_v2Delegate {
    func changeAmount(in textField: AmountTextField_v2) {
        // no-op
    }

    func changeType(in textField: AmountTextField_v2) {
        // no-op
    }

    func shouldReturn(in textField: AmountTextField_v2) -> Bool {
        return true
    }
}
