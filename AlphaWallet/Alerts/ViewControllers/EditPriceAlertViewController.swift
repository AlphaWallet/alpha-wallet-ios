//
//  AlertsViewController.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 16.09.2021.
//

import UIKit
import Combine
import AlphaWalletFoundation

protocol EditPriceAlertViewControllerDelegate: AnyObject {
    func didUpdateAlert(in viewController: EditPriceAlertViewController)
    func didClose(in viewController: EditPriceAlertViewController)
}

class EditPriceAlertViewController: UIViewController {

    private lazy var headerView: SendViewSectionHeader = {
        let view = SendViewSectionHeader()
        view.configure(viewModel: .init(text: R.string.localizable.priceAlertEnterTargetPrice().uppercased()))

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
        textField.isAllFundsEnabled = false
        textField.selectCurrencyButton.isHidden = false
        textField.selectCurrencyButton.expandIconHidden = true
        textField.statusLabel.text = nil
        textField.availableTextHidden = false
        textField.selectCurrencyButton.hasToken = true

        return textField
    }()

    private let buttonsBar: HorizontalButtonsBar = {
        let buttonsBar = HorizontalButtonsBar(configuration: .primary(buttons: 1))
        buttonsBar.configure()

        return buttonsBar
    }()
    private lazy var containerView: ScrollableStackView = {
        let view = ScrollableStackView()
        return view
    }()

    private let viewModel: EditPriceAlertViewModel
    private let willAppear = PassthroughSubject<Void, Never>()
    private var cancelable = Set<AnyCancellable>()
    private var saveButton: UIButton { return buttonsBar.buttons[0] }

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

        saveButton.setTitle(R.string.localizable.priceAlertSet(), for: .normal)
        view.backgroundColor = Configuration.Color.Semantic.defaultViewBackground

        bind(viewModel: viewModel)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        willAppear.send(())
    }

    private func bind(viewModel: EditPriceAlertViewModel) {
        navigationItem.title = viewModel.title

        let input = EditPriceAlertViewModelInput(
            willAppear: willAppear.eraseToAnyPublisher(),
            save: saveButton.publisher(forEvent: .touchUpInside).eraseToAnyPublisher(),
            amountToSend: amountTextField.cryptoValuePublisher)

        let output = viewModel.transform(input: input)

        output.cryptoToFiatRate
            .assign(to: \.value, on: amountTextField.viewModel.cryptoToFiatRate, ownership: .weak)
            .store(in: &cancelable)

        output.cryptoInitial
            .sink { [weak amountTextField] in amountTextField?.set(amount: .amount($0)) }
            .store(in: &cancelable)

        output.marketPrice
            .sink { [weak amountTextField] in amountTextField?.statusLabel.text = $0 }
            .store(in: &cancelable)

        output.isEnabled
            .sink { [weak self] in self?.saveButton.isEnabled = $0 }
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
