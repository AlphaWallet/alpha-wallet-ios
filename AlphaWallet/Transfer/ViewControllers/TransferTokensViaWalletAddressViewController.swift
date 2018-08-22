// Copyright © 2018 Stormbird PTE. LTD.

import UIKit
import QRCodeReaderViewController

protocol TransferTokensViaWalletAddressViewControllerDelegate: class {
    func didEnterWalletAddress(TokenHolder: TokenHolder, to walletAddress: String, paymentFlow: PaymentFlow, in viewController: TransferTokensViaWalletAddressViewController)
    func didPressViewInfo(in viewController: TransferTokensViaWalletAddressViewController)
    func didPressViewContractWebPage(in viewController: TransferTokensViaWalletAddressViewController)
}

class TransferTokensViaWalletAddressViewController: UIViewController, TokenVerifiableStatusViewController, CanScanQRCode {
    let config: Config
    var contract: String {
        return token.contract
    }
    private let token: TokenObject
    let roundedBackground = RoundedBackground()
    let header = TokensViewControllerTitleHeader()
    let TokenView: TokenRowView & UIView
    let targetAddressTextField = AddressTextField()
    let nextButton = UIButton(type: .system)
    var viewModel: TransferTokensViaWalletAddressViewControllerViewModel
    var TokenHolder: TokenHolder
    var paymentFlow: PaymentFlow
    weak var delegate: TransferTokensViaWalletAddressViewControllerDelegate?

    init(
            config: Config,
            token: TokenObject,
            TokenHolder: TokenHolder,
            paymentFlow: PaymentFlow,
            viewModel: TransferTokensViaWalletAddressViewControllerViewModel
    ) {
        self.config = config
        self.token = token
        self.TokenHolder = TokenHolder
        self.paymentFlow = paymentFlow
        self.viewModel = viewModel

        let tokenType = CryptoKittyHandling(contract: TokenHolder.contractAddress)
        switch tokenType {
        case .cryptoKitty:
            TokenView = TokenListFormatRowView()
        case .otherNonFungibleToken:
            TokenView = TokenRowView()
        }

        super.init(nibName: nil, bundle: nil)

        updateNavigationRightBarButtons(isVerified: true)

        roundedBackground.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(roundedBackground)

        targetAddressTextField.label.translatesAutoresizingMaskIntoConstraints = false

        targetAddressTextField.translatesAutoresizingMaskIntoConstraints = false
        targetAddressTextField.delegate = self
        targetAddressTextField.textField.returnKeyType = .done

        nextButton.setTitle(R.string.localizable.aWalletNextButtonTitle(), for: .normal)
        nextButton.addTarget(self, action: #selector(nextButtonTapped), for: .touchUpInside)

        TokenView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(TokenView)

        let stackView = [
            header,
            TokenView,
            .spacer(height: 10),
            targetAddressTextField.label,
            .spacer(height: ScreenChecker().isNarrowScreen() ? 2 : 4),
            targetAddressTextField,
        ].asStackView(axis: .vertical, alignment: .center)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        roundedBackground.addSubview(stackView)

        let buttonsStackView = [nextButton].asStackView(distribution: .fillEqually, contentHuggingPriority: .required)
        buttonsStackView.translatesAutoresizingMaskIntoConstraints = false

        let footerBar = UIView()
        footerBar.translatesAutoresizingMaskIntoConstraints = false
        footerBar.backgroundColor = Colors.appHighlightGreen
        roundedBackground.addSubview(footerBar)

        let buttonsHeight = CGFloat(60)
        footerBar.addSubview(buttonsStackView)

        NSLayoutConstraint.activate([
			header.heightAnchor.constraint(equalToConstant: 90),

            TokenView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            TokenView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            targetAddressTextField.leadingAnchor.constraint(equalTo: roundedBackground.leadingAnchor, constant: 30),
            targetAddressTextField.trailingAnchor.constraint(equalTo: roundedBackground.trailingAnchor, constant: -30),

            stackView.leadingAnchor.constraint(equalTo: roundedBackground.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: roundedBackground.trailingAnchor),
            stackView.topAnchor.constraint(equalTo: roundedBackground.topAnchor),

            buttonsStackView.leadingAnchor.constraint(equalTo: footerBar.leadingAnchor),
            buttonsStackView.trailingAnchor.constraint(equalTo: footerBar.trailingAnchor),
            buttonsStackView.topAnchor.constraint(equalTo: footerBar.topAnchor),
            buttonsStackView.heightAnchor.constraint(equalToConstant: buttonsHeight),

            footerBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            footerBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            footerBar.heightAnchor.constraint(equalToConstant: buttonsHeight),
            footerBar.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ] + roundedBackground.createConstraintsWithContainer(view: view))
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc func nextButtonTapped() {
        let address = targetAddressTextField.value.trimmed
        delegate?.didEnterWalletAddress(TokenHolder: TokenHolder, to: address, paymentFlow: paymentFlow, in: self)
    }

    func showInfo() {
        delegate?.didPressViewInfo(in: self)
    }

    func showContractWebPage() {
        let url = config.server.etherscanContractDetailsWebPageURL(for: viewModel.token.contract)
        openURL(url)
    }

    func configure(viewModel newViewModel: TransferTokensViaWalletAddressViewControllerViewModel? = nil) {
        if let newViewModel = newViewModel {
            viewModel = newViewModel
        }
        updateNavigationRightBarButtons(isVerified: isContractVerified)

        view.backgroundColor = viewModel.backgroundColor

        header.configure(title: viewModel.headerTitle)

        TokenView.configure(tokenHolder: TokenHolder)

        TokenView.stateLabel.isHidden = true

        targetAddressTextField.label.text = R.string.localizable.aSendRecipientAddressTitle()

        targetAddressTextField.configureOnce()

        nextButton.setTitleColor(viewModel.buttonTitleColor, for: .normal)
		nextButton.backgroundColor = viewModel.buttonBackgroundColor
        nextButton.titleLabel?.font = viewModel.buttonFont
    }

}

extension TransferTokensViaWalletAddressViewController: QRCodeReaderDelegate {
    func readerDidCancel(_ reader: QRCodeReaderViewController!) {
        reader.stopScanning()
        reader.dismiss(animated: true, completion: nil)
    }

    func reader(_ reader: QRCodeReaderViewController!, didScanResult result: String!) {
        reader.stopScanning()
        reader.dismiss(animated: true)

        guard let result = QRURLParser.from(string: result) else {
            return
        }
        targetAddressTextField.value = result.address
    }
}

extension TransferTokensViaWalletAddressViewController: AddressTextFieldDelegate {
    func displayError(error: Error, for textField: AddressTextField) {
        displayError(error: error)
    }

    func openQRCodeReader(for textField: AddressTextField) {
        guard AVCaptureDevice.authorizationStatus(for: .video) != .denied else {
            promptUserOpenSettingsToChangeCameraPermission()
            return
        }
        let controller = QRCodeReaderViewController()
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

    func shouldChange(in range: NSRange, to string: String, in textField: AddressTextField) -> Bool {
        return true
    }
}
