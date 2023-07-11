// Copyright © 2018 Stormbird PTE. LTD.

import UIKit
import Combine
import AlphaWalletFoundation

protocol SendViewControllerDelegate: AnyObject, CanOpenURL {
    func didPressConfirm(transaction: UnconfirmedTransaction, in viewController: SendViewController)
    func openQRCode(in viewController: SendViewController)
    func didClose(in viewController: SendViewController)
}

class SendViewController: UIViewController {
    private let tokenImageFetcher: TokenImageFetcher
    private let recipientHeader = SendViewSectionHeader()
    private let amountHeader = SendViewSectionHeader()
    private let buttonsBar: HorizontalButtonsBar = {
        let buttonsBar = HorizontalButtonsBar(configuration: .primary(buttons: 1))
        buttonsBar.configure()
        buttonsBar.buttons[0].setTitle(R.string.localizable.send(), for: .normal)

        return buttonsBar
    }()
    //NOTE: Internal, for tests
    let viewModel: SendViewModel
    //We use weak link to make sure that token alert will be deallocated by close button tapping.
    //We storing link to make sure that only one alert is displaying on the screen.
    private weak var invalidTokenAlert: UIViewController?
    private let domainResolutionService: DomainNameResolutionServiceType
    private var cancelable = Set<AnyCancellable>()
    private let qrCode = PassthroughSubject<String, Never>()
    private let didAppear = PassthroughSubject<Void, Never>()
    private var sendButton: UIButton { buttonsBar.buttons[0] }
    private lazy var containerView: ScrollableStackView = {
        let view = ScrollableStackView()
        return view
    }()
    lazy var targetAddressTextField: AddressTextField = {
        let targetAddressTextField = AddressTextField(server: viewModel.transactionType.server, domainResolutionService: domainResolutionService)
        targetAddressTextField.delegate = self
        targetAddressTextField.returnKeyType = .done
        targetAddressTextField.pasteButton.contentHorizontalAlignment = .right
        targetAddressTextField.inputAccessoryButtonType = .done

        return targetAddressTextField
    }()

    lazy var amountTextField: AmountTextField = {
        let amountTextField = AmountTextField(viewModel: viewModel.amountTextFieldViewModel, tokenImageFetcher: tokenImageFetcher)
        amountTextField.delegate = self
        amountTextField.inputAccessoryButtonType = .next
        amountTextField.viewModel.errorState = .none
        amountTextField.isAlternativeAmountEnabled = true
        amountTextField.isAllFundsEnabled = true
        amountTextField.selectCurrencyButton.hasToken = true

        return amountTextField
    }()
    weak var delegate: SendViewControllerDelegate?

    init(viewModel: SendViewModel,
         domainResolutionService: DomainNameResolutionServiceType,
         tokenImageFetcher: TokenImageFetcher) {

        self.tokenImageFetcher = tokenImageFetcher
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

        view.backgroundColor = Configuration.Color.Semantic.defaultViewBackground
        amountHeader.configure(viewModel: viewModel.amountViewModel)
        recipientHeader.configure(viewModel: viewModel.recipientViewModel)

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
            amountToSend: amountTextField.cryptoValuePublisher,
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
            .receive(on: RunLoop.main)
            .sink { [weak self] in
                guard let strongSelf = self else { return }
                strongSelf.delegate?.didPressConfirm(transaction: $0, in: strongSelf)
            }.store(in: &cancelable)

        output.amountTextFieldState
            .sink { [weak amountTextField] in amountTextField?.set(amount: $0.amount) }
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

                amountTextField.selectCurrencyButton.expandIconHidden = viewState.selectCurrencyButtonState.expandIconHidden
                amountTextField.statusLabel.text = viewState.amountStatusLabelState.text
                amountTextField.availableTextHidden = viewState.amountStatusLabelState.isHidden
                amountTextField.viewModel.cryptoToFiatRate.value = viewState.rate

                if let recipient = viewState.recipientTextFieldState.recipient {
                    targetAddressTextField.value = recipient
                }

            }.store(in: &cancelable)
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
}

extension SendViewController: AddressTextFieldDelegate {
    func doneButtonTapped(for textField: AddressTextField) {
        view.endEditing(true)
    }

    func displayError(error: Error, for textField: AddressTextField) {
        textField.errorState = .error(error.localizedDescription)
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
