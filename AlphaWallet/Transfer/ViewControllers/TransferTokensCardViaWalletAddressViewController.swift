// Copyright © 2018 Stormbird PTE. LTD.

import UIKit
import QRCodeReaderViewController

protocol TransferTokensCardViaWalletAddressViewControllerDelegate: class, CanOpenURL {
    func didEnterWalletAddress(tokenHolder: TokenHolder, to walletAddress: AlphaWallet.Address, paymentFlow: PaymentFlow, in viewController: TransferTokensCardViaWalletAddressViewController)
    func didPressViewInfo(in viewController: TransferTokensCardViaWalletAddressViewController)
}

class TransferTokensCardViaWalletAddressViewController: UIViewController, TokenVerifiableStatusViewController, CanScanQRCode {
    private let token: TokenObject
    private let roundedBackground = RoundedBackground()
    private let header = TokensCardViewControllerTitleHeader()
    private let scrollView = UIScrollView()
    private let tokenRowView: TokenRowView & UIView
    private let targetAddressLabel = UILabel()
    private let targetAddressTextField = AddressTextField()
    private let buttonsBar = ButtonsBar(numberOfButtons: 1)
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

        let stackView = [
            header,
            tokenRowView,
            .spacer(height: 10),
            targetAddressLabel,
            .spacer(height: ScreenChecker().isNarrowScreen ? 2 : 4),
            targetAddressTextField,
            targetAddressTextField.ensAddressLabel,
        ].asStackView(axis: .vertical, alignment: .center)
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

            targetAddressTextField.leadingAnchor.constraint(equalTo: roundedBackground.leadingAnchor, constant: 30),
            targetAddressTextField.trailingAnchor.constraint(equalTo: roundedBackground.trailingAnchor, constant: -30),

            stackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
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
        fatalError("init(coder:) has not been implemented")
    }

    @objc func nextButtonTapped() {
        guard let address = AlphaWallet.Address(string: targetAddressTextField.value.trimmed) else {
            navigationController?.displayError(error: Errors.invalidAddress)
            return
        }

        delegate?.didEnterWalletAddress(tokenHolder: tokenHolder, to: address, paymentFlow: paymentFlow, in: self)
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

extension TransferTokensCardViaWalletAddressViewController: QRCodeReaderDelegate {
    func readerDidCancel(_ reader: QRCodeReaderViewController!) {
        reader.stopScanning()
        reader.dismiss(animated: true, completion: nil)
    }

    func reader(_ reader: QRCodeReaderViewController!, didScanResult result: String!) {
        reader.stopScanning()
        reader.dismiss(animated: true)

        guard let result = QRCodeValueParser.from(string: result) else { return }
        switch result {
        case .address(let address):
            targetAddressTextField.value = address.eip55String
        case .eip681:
            break
        }
    }
}

extension TransferTokensCardViaWalletAddressViewController: AddressTextFieldDelegate {
    func displayError(error: Error, for textField: AddressTextField) {
        displayError(error: error)
    }

    func openQRCodeReader(for textField: AddressTextField) {
        guard AVCaptureDevice.authorizationStatus(for: .video) != .denied else {
            promptUserOpenSettingsToChangeCameraPermission()
            return
        }
        let controller = QRCodeReaderViewController(cancelButtonTitle: nil, chooseFromPhotoLibraryButtonTitle: R.string.localizable.photos())
        controller.delegate = self
        present(controller, animated: true, completion: nil)
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
