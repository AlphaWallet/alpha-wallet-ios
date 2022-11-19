// Copyright © 2018 Stormbird PTE. LTD.

import UIKit
import Combine
import AlphaWalletFoundation

protocol SendViewControllerDelegate: class, CanOpenURL {
    func didPressConfirm(transaction: UnconfirmedTransaction, in viewController: SendViewController, amount: String, shortValue: String?)
    func openQRCode(in viewController: SendViewController)
    func didClose(in viewController: SendViewController)
}

class SendViewController: UIViewController {
    private let recipientHeader = SendViewSectionHeader()
    private let amountHeader = SendViewSectionHeader()
    private let buttonsBar = HorizontalButtonsBar(configuration: .primary(buttons: 1))
    private let viewModel: SendViewModel
    //We use weak link to make sure that token alert will be deallocated by close button tapping.
    //We storing link to make sure that only one alert is displaying on the screen.
    private weak var invalidTokenAlert: UIViewController?
    private let domainResolutionService: DomainResolutionServiceType
    private var cancelable = Set<AnyCancellable>()
    private let qrCode = PassthroughSubject<String, Never>()
    private let didAppear = PassthroughSubject<Void, Never>()
    private var sendButton: UIButton { buttonsBar.buttons[0] }
    private lazy var containerView: ScrollableStackView = {
        let view = ScrollableStackView()
        return view
    }()
    lazy var targetAddressTextField: AddressTextField = {
        let targetAddressTextField = AddressTextField(domainResolutionService: domainResolutionService)
        targetAddressTextField.delegate = self
        targetAddressTextField.returnKeyType = .done
        targetAddressTextField.pasteButton.contentHorizontalAlignment = .right
        targetAddressTextField.inputAccessoryButtonType = .done

        return targetAddressTextField
    }()

    lazy var amountTextField: AmountTextField = {
        let amountTextField = AmountTextField(viewModel: viewModel.amountTextFieldViewModel)
        amountTextField.delegate = self
        amountTextField.inputAccessoryButtonType = .next
        amountTextField.viewModel.errorState = .none
        amountTextField.isAlternativeAmountEnabled = false
        amountTextField.allFundsAvailable = true
        amountTextField.selectCurrencyButton.hasToken = true

        return amountTextField
    }()
    weak var delegate: SendViewControllerDelegate?

    init(viewModel: SendViewModel, domainResolutionService: DomainResolutionServiceType) {
        self.domainResolutionService = domainResolutionService
        self.viewModel = viewModel

        super.init(nibName: nil, bundle: nil)

        containerView.stackView.addArrangedSubviews([
            amountHeader,
            .spacer(height: ScreenChecker().isNarrowScreen ? 7: 16),
            amountTextField.defaultLayout(edgeInsets: .init(top: 0, left: 16, bottom: 0, right: 16)),
            .spacer(height: ScreenChecker().isNarrowScreen ? 7: 14),
            recipientHeader,
            .spacer(height: ScreenChecker().isNarrowScreen ? 7: 16),
            targetAddressTextField.defaultLayout(edgeInsets: .init(top: 0, left: 16, bottom: 0, right: 16))
        ])

        let footerBar = ButtonsBarBackgroundView(buttonsBar: buttonsBar, separatorHeight: 0)
        view.backgroundColor = Configuration.Color.Semantic.defaultViewBackground
        view.addSubview(footerBar)
        view.addSubview(containerView)

        NSLayoutConstraint.activate([
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            containerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            containerView.bottomAnchor.constraint(equalTo: footerBar.topAnchor),

            footerBar.anchorsConstraint(to: view),
        ])
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        buttonsBar.configure()
        sendButton.setTitle(R.string.localizable.send(), for: .normal)

        configure(viewModel: viewModel)
        bind(viewModel: viewModel)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        didAppear.send(())
    }

    func allFundsSelected() {
        amountTextField.allFundsButton.sendActions(for: .touchUpInside)
    }

    private func bind(viewModel: SendViewModel) {
        let send = sendButton.publisher(forEvent: .touchUpInside).eraseToAnyPublisher()
        let recipient = send.map { [targetAddressTextField] _ in return targetAddressTextField.value.trimmed }
            .eraseToAnyPublisher()

        let input = SendViewModelInput(
            cryptoValue: amountTextField.cryptoValuePublisher,
            qrCode: qrCode.eraseToAnyPublisher(),
            allFunds: amountTextField.allFundsButton.publisher(forEvent: .touchUpInside).eraseToAnyPublisher(),
            send: send,
            recipient: recipient,
            didAppear: didAppear.eraseToAnyPublisher())

        let output = viewModel.transform(input: input)

        output.scanQrCodeError
            .sink { [weak self] in self?.showError(message: $0) }
            .store(in: &cancelable)

        output.activateAmountInput
            .sink { [weak self] _ in self?.activateAmountView() }
            .store(in: &cancelable)

        output.token
            .sink { [weak amountTextField] in amountTextField?.viewModel.set(token: $0) }
            .store(in: &cancelable)

        output.confirmTransaction
            .sink { [amountTextField] in
                self.delegate?.didPressConfirm(transaction: $0, in: self, amount: amountTextField.cryptoValue, shortValue: self.shortValueForAllFunds)
            }.store(in: &cancelable)

        output.allFundsAmount
            .sink { [weak amountTextField] in amountTextField?.set(crypto: $0.crypto, shortCrypto: $0.shortCrypto, useFormatting: false) }
            .store(in: &cancelable)

        output.cryptoErrorState
            .sink { [weak amountTextField] in amountTextField?.viewModel.errorState = $0 }
            .store(in: &cancelable)

        output.recipientErrorState
            .sink { [weak targetAddressTextField] in targetAddressTextField?.errorState = $0 }
            .store(in: &cancelable)

        output.viewState
            .sink { [navigationItem, amountTextField, targetAddressTextField] viewState in
                navigationItem.title = viewState.title

                amountTextField.selectCurrencyButton.isHidden = viewState.selectCurrencyButtonState.isHidden
                amountTextField.selectCurrencyButton.expandIconHidden = viewState.selectCurrencyButtonState.expandIconHidden

                amountTextField.statusLabel.text = viewState.amountStatusLabelState.text
                amountTextField.availableTextHidden = viewState.amountStatusLabelState.isHidden

                if let amount = viewState.amountTextFieldState.amount {
                    amountTextField.set(crypto: amount, useFormatting: true)
                }

                if let recipient = viewState.recipientTextFieldState.recipient {
                    targetAddressTextField.value = recipient
                }
                amountTextField.viewModel.cryptoToFiatRate.value = viewState.amountTextFieldState.cryptoToFiatRate
            }.store(in: &cancelable)
    }

    private func configure(viewModel: SendViewModel) {
        view.backgroundColor = viewModel.backgroundColor

        amountHeader.configure(viewModel: viewModel.amountViewModel)
        recipientHeader.configure(viewModel: viewModel.recipientViewModel)
    }

    var shortValueForAllFunds: String? {
        return viewModel.shortValueForAllFunds
    }

    private func activateAmountView() {
        amountTextField.becomeFirstResponder()
    }

    required init?(coder aDecoder: NSCoder) {
        return nil
    }

    func didScanQRCode(_ value: String) {
        qrCode.send(value)
    }

    private func showError(message: String) {
        guard invalidTokenAlert == nil else { return }

        invalidTokenAlert = UIAlertController.alert(message: message, alertButtonTitles: [R.string.localizable.oK()], alertButtonStyles: [.cancel], viewController: self)
    }
}

extension SendViewController: PopNotifiable {
    func didPopViewController(animated: Bool) {
        delegate?.didClose(in: self)
    }
}

extension SendViewController: AmountTextFieldDelegate {

    func doneButtonTapped(for textField: AmountTextField) {
        view.endEditing(true)
    }

    func nextButtonTapped(for textField: AmountTextField) {
        targetAddressTextField.becomeFirstResponder()
    }

    func shouldReturn(in textField: AmountTextField) -> Bool {
        targetAddressTextField.becomeFirstResponder()
        return false
    }

    func changeAmount(in textField: AmountTextField) {
        //no-op
    }

    func changeType(in textField: AmountTextField) {
        //no-op
    }
}

extension SendViewController: AddressTextFieldDelegate {
    func doneButtonTapped(for textField: AddressTextField) {
        view.endEditing(true)
    }

    func displayError(error: Error, for textField: AddressTextField) {
        textField.errorState = .error(error.prettyError)
    }

    func openQRCodeReader(for textField: AddressTextField) {
        delegate?.openQRCode(in: self)
    }

    func didPaste(in textField: AddressTextField) {
        textField.errorState = .none
        //NOTE: Comment it as activating amount view doesn't work properly here
        //activateAmountView()
    }

    func shouldReturn(in textField: AddressTextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }

    func didChange(to string: String, in textField: AddressTextField) {
        //no-op
    }
}
