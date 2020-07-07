// Copyright © 2018 Stormbird PTE. LTD.

import UIKit

protocol TransferTokensCardViaWalletAddressViewControllerDelegate: class, CanOpenURL {
    func didEnterWalletAddress(tokenHolder: TokenHolder, to walletAddress: AlphaWallet.Address, paymentFlow: PaymentFlow, in viewController: TransferTokensCardViaWalletAddressViewController)
    func didPressViewInfo(in viewController: TransferTokensCardViaWalletAddressViewController)
    func openQRCode(in controller: TransferTokensCardViaWalletAddressViewController)
}

class TransferTokensCardViaWalletAddressViewController: UIViewController, TokenVerifiableStatusViewController, CanScanQRCode {
    private let token: TokenObject
    private let roundedBackground = RoundedBackground()
    private let header = TokensCardViewControllerTitleHeader()
    private let scrollView = UIScrollView()
    private let tokenRowView: TokenRowView & UIView
    private let targetAddressLabel = UILabel()
    private let targetAddressTextField = AddressTextField()
    private let buttonsBar = ButtonsBar(configuration: .green(buttons: 1))
    private var viewModel: TransferTokensCardViaWalletAddressViewControllerViewModel
    private var tokenHolder: TokenHolder
    private var paymentFlow: PaymentFlow

    var contract: AlphaWallet.Address {
        return token.contractAddress
    }
    var server: RPCServer {
        return token.server
    }
    let assetDefinitionStore: AssetDefinitionStore
    weak var delegate: TransferTokensCardViaWalletAddressViewControllerDelegate?

    init(
            token: TokenObject,
            tokenHolder: TokenHolder,
            paymentFlow: PaymentFlow,
            viewModel: TransferTokensCardViaWalletAddressViewControllerViewModel,
            assetDefinitionStore: AssetDefinitionStore
    ) {
        self.token = token
        self.tokenHolder = tokenHolder
        self.paymentFlow = paymentFlow
        self.viewModel = viewModel
        self.assetDefinitionStore = assetDefinitionStore

        let tokenType = OpenSeaBackedNonFungibleTokenHandling(token: token, assetDefinitionStore: assetDefinitionStore, tokenViewType: .viewIconified)
        switch tokenType {
        case .backedByOpenSea:
            tokenRowView = OpenSeaNonFungibleTokenCardRowView(tokenView: .viewIconified)
        case .notBackedByOpenSea:
            tokenRowView = TokenCardRowView(server: token.server, tokenView: .viewIconified, assetDefinitionStore: assetDefinitionStore)
        }

        super.init(nibName: nil, bundle: nil)

        updateNavigationRightBarButtons(withTokenScriptFileStatus: nil)

        roundedBackground.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(roundedBackground)

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        roundedBackground.addSubview(scrollView)

        targetAddressTextField.delegate = self
        targetAddressTextField.returnKeyType = .done

        view.addSubview(tokenRowView)

        let addressControlsContainer = UIView()
        addressControlsContainer.translatesAutoresizingMaskIntoConstraints = false
        addressControlsContainer.backgroundColor = .clear

        targetAddressTextField.pasteButton.contentHorizontalAlignment = .right
        
        let addressControlsStackView = [
            targetAddressTextField.pasteButton,
            targetAddressTextField.clearButton
        ].asStackView(axis: .horizontal, alignment: .trailing)
        addressControlsStackView.translatesAutoresizingMaskIntoConstraints = false
        addressControlsStackView.setContentHuggingPriority(.required, for: .horizontal)
        addressControlsStackView.setContentCompressionResistancePriority(.required, for: .horizontal)

        addressControlsContainer.addSubview(addressControlsStackView)

        let stackView = [
            header,
            tokenRowView,
            .spacer(height: 10),
            [.spacerWidth(16), targetAddressLabel].asStackView(axis: .horizontal),
            .spacer(height: 4),
            targetAddressTextField,
            .spacer(height: 4), [
                [.spacerWidth(16), targetAddressTextField.ensAddressView, targetAddressTextField.statusLabel].asStackView(axis: .horizontal, alignment: .leading),
                addressControlsContainer
            ].asStackView(axis: .horizontal),
        ].asStackView(axis: .vertical)

        stackView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stackView)

        let footerBar = UIView()
        footerBar.translatesAutoresizingMaskIntoConstraints = false
        footerBar.backgroundColor = .clear
        roundedBackground.addSubview(footerBar)

        footerBar.addSubview(buttonsBar)

        NSLayoutConstraint.activate([
			header.heightAnchor.constraint(equalToConstant: 90),

            tokenRowView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tokenRowView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            targetAddressLabel.heightAnchor.constraint(equalToConstant: 22),
            
            targetAddressTextField.leadingAnchor.constraint(equalTo: roundedBackground.leadingAnchor, constant: 16),
            targetAddressTextField.trailingAnchor.constraint(equalTo: roundedBackground.trailingAnchor, constant: -16),

            addressControlsStackView.trailingAnchor.constraint(equalTo: addressControlsContainer.trailingAnchor, constant: -7),
            addressControlsStackView.topAnchor.constraint(equalTo: addressControlsContainer.topAnchor),
            addressControlsStackView.bottomAnchor.constraint(equalTo: addressControlsContainer.bottomAnchor),
            addressControlsStackView.leadingAnchor.constraint(greaterThanOrEqualTo: addressControlsContainer.leadingAnchor),
            addressControlsContainer.heightAnchor.constraint(equalToConstant: 30),

            stackView.leadingAnchor.constraint(equalTo: roundedBackground.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: roundedBackground.trailingAnchor),
            stackView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            stackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),

            scrollView.leadingAnchor.constraint(equalTo: roundedBackground.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: roundedBackground.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: roundedBackground.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: footerBar.topAnchor),

            buttonsBar.leadingAnchor.constraint(equalTo: footerBar.leadingAnchor),
            buttonsBar.trailingAnchor.constraint(equalTo: footerBar.trailingAnchor),
            buttonsBar.topAnchor.constraint(equalTo: footerBar.topAnchor),
            buttonsBar.heightAnchor.constraint(equalToConstant: ButtonsBar.buttonsHeight),

            footerBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            footerBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            footerBar.topAnchor.constraint(equalTo: view.layoutGuide.bottomAnchor, constant: -ButtonsBar.buttonsHeight - ButtonsBar.marginAtBottomScreen),
            footerBar.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ] + roundedBackground.createConstraintsWithContainer(view: view))

        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
    }

    required init?(coder aDecoder: NSCoder) {
        return nil
    }

    @objc func nextButtonTapped() {
        targetAddressTextField.errorState = .none

        if let address = AlphaWallet.Address(string: targetAddressTextField.value.trimmed) {
            delegate?.didEnterWalletAddress(tokenHolder: tokenHolder, to: address, paymentFlow: paymentFlow, in: self)
        } else {
            targetAddressTextField.errorState = .error(Errors.invalidAddress.prettyError)
        }
    }

    func configure(viewModel newViewModel: TransferTokensCardViaWalletAddressViewControllerViewModel? = nil) {
        if let newViewModel = newViewModel {
            viewModel = newViewModel
        }
        updateNavigationRightBarButtons(withTokenScriptFileStatus: tokenScriptFileStatus)

        view.backgroundColor = viewModel.backgroundColor

        header.configure(title: viewModel.headerTitle)

        tokenRowView.configure(tokenHolder: tokenHolder)

        tokenRowView.stateLabel.isHidden = true

        targetAddressLabel.font = viewModel.targetAddressLabelFont
        targetAddressLabel.textColor = viewModel.targetAddressLabelTextColor
        targetAddressLabel.text = R.string.localizable.aSendRecipientAddressTitle()
        
        targetAddressTextField.configureOnce()

        buttonsBar.configure()
        let nextButton = buttonsBar.buttons[0]
        nextButton.setTitle(R.string.localizable.aWalletNextButtonTitle(), for: .normal)
        nextButton.addTarget(self, action: #selector(nextButtonTapped), for: .touchUpInside)
    }

    @objc private func keyboardWillShow(notification: NSNotification) {
        if let keyboardEndFrame = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue, let _ = notification.userInfo?[UIResponder.keyboardFrameBeginUserInfoKey] as? NSValue {
            scrollView.contentInset.bottom = keyboardEndFrame.size.height
        }
    }

    @objc private func keyboardWillHide(notification: NSNotification) {
        //If there's a external keyboard (or on simulator with software keyboard disabled):
        //    When text input starts. beginRect: size.height=0 endRect: size.height ~54. origin.y remains at ~812 (out of the screen)
        //    When text input ends. beginRect: size.height ~54 endRect: size.height = 0. origin.y remains at 812 (out of the screen)
        //Note the above. keyboardWillHide() is called for both when input starts and ends for external keyboard. Probably because the keyboard is hidden in both cases
        guard let beginRect = (notification.userInfo?[UIResponder.keyboardFrameBeginUserInfoKey] as? NSValue)?.cgRectValue, let endRect = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue else { return }
        let isExternalKeyboard = beginRect.origin == endRect.origin && (beginRect.size.height == 0 || endRect.size.height == 0)
        let isEnteringEditModeWithExternalKeyboard: Bool
        if isExternalKeyboard {
            isEnteringEditModeWithExternalKeyboard = beginRect.size.height == 0 && endRect.size.height > 0
        } else {
            isEnteringEditModeWithExternalKeyboard = false
        }
        if !isExternalKeyboard || !isEnteringEditModeWithExternalKeyboard {
            scrollView.contentInset.bottom = 0
        }
    }
}

extension TransferTokensCardViaWalletAddressViewController: VerifiableStatusViewController {
    func showInfo() {
        delegate?.didPressViewInfo(in: self)
    }

    func showContractWebPage() {
        delegate?.didPressViewContractWebPage(forContract: contract, server: server, in: self)
    }

    func open(url: URL) {
        delegate?.didPressViewContractWebPage(url, in: self)
    }
}

extension TransferTokensCardViaWalletAddressViewController: AddressTextFieldDelegate {
    func didScanQRCode(_ result: String) {
        guard let result = QRCodeValueParser.from(string: result) else { return }
        switch result {
        case .address(let address):
            targetAddressTextField.value = address.eip55String
        case .eip681:
            break
        }
    }

    func displayError(error: Error, for textField: AddressTextField) {
        targetAddressTextField.errorState = .error(Errors.invalidAddress.prettyError)
    }

    func openQRCodeReader(for textField: AddressTextField) {
        delegate?.openQRCode(in: self)
    }

    func didPaste(in textField: AddressTextField) {
        //Do nothing
    }

    func shouldReturn(in textField: AddressTextField) -> Bool {
        view.endEditing(true)
        return true
    }

    func didChange(to string: String, in textField: AddressTextField) {
    }
}
