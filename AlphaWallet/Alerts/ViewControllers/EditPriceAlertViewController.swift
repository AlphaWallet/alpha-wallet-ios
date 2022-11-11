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

    private lazy var amountTextField: AmountTextField = {
        let textField = AmountTextField(token: viewModel.token)
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.delegate = self
        textField.inputAccessoryButtonType = .done
        textField.viewModel.errorState = .none
        textField.viewModel.toggleFiatAndCryptoPair()
        textField.isAlternativeAmountEnabled = false
        textField.allFundsAvailable = false
        textField.selectCurrencyButton.isHidden = false
        textField.selectCurrencyButton.expandIconHidden = true
        textField.statusLabel.text = nil
        textField.availableTextHidden = false
        textField.selectCurrencyButton.hasToken = true

        return textField
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

        containerView.stackView.addArrangedSubviews([
            headerView,
            amountTextField.defaultLayout(edgeInsets: .init(top: 16, left: 16, bottom: 0, right: 16))
        ])

        let footerBar = ButtonsBarBackgroundView(buttonsBar: buttonsBar, separatorHeight: 0)
        view.addSubview(footerBar)
        view.addSubview(containerView)

        NSLayoutConstraint.activate([
            containerView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            containerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            containerView.bottomAnchor.constraint(equalTo: footerBar.topAnchor),

            footerBar.anchorsConstraint(to: view),
        ])
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
        navigationItem.title = viewModel.title

        containerView.configure(viewModel: .init(backgroundColor: viewModel.backgroundColor))

        let save = buttonsBar.buttons[0].publisher(forEvent: .touchUpInside).eraseToAnyPublisher()

        let input = EditPriceAlertViewModelInput(appear: appear.eraseToAnyPublisher(), save: save, cryptoValue: amountTextField.cryptoValuePublisher)
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

    required init?(coder: NSCoder) {
        return nil
    }
}

extension EditPriceAlertViewController: PopNotifiable {
    func didPopViewController(animated: Bool) {
        delegate?.didClose(in: self)
    }
}

extension EditPriceAlertViewController: AmountTextFieldDelegate {
    func doneButtonTapped(for textField: AmountTextField) {
        view.endEditing(true)
    }
    
    func shouldReturn(in textField: AmountTextField) -> Bool {
        return true
    }
}
