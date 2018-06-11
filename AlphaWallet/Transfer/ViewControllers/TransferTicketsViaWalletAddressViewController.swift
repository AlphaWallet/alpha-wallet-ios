// Copyright © 2018 Stormbird PTE. LTD.

import UIKit
import QRCodeReaderViewController

protocol TransferTicketsViaWalletAddressViewControllerDelegate: class {
    func didEnterWalletAddress(ticketHolder: TicketHolder, to walletAddress: String, paymentFlow: PaymentFlow, in viewController: TransferTicketsViaWalletAddressViewController)
    func didPressViewInfo(in viewController: TransferTicketsViaWalletAddressViewController)
    func didPressViewContractWebPage(in viewController: TransferTicketsViaWalletAddressViewController)
}

class TransferTicketsViaWalletAddressViewController: UIViewController {

    let roundedBackground = RoundedBackground()
    let header = TicketsViewControllerTitleHeader()
    let ticketView = TicketRowView()
    let targetAddressTextField = AddressTextField()
    let nextButton = UIButton(type: .system)
    var viewModel: TransferTicketsViaWalletAddressViewControllerViewModel!
    var ticketHolder: TicketHolder
    var paymentFlow: PaymentFlow
    weak var delegate: TransferTicketsViaWalletAddressViewControllerDelegate?

    init(ticketHolder: TicketHolder, paymentFlow: PaymentFlow) {
        self.ticketHolder = ticketHolder
        self.paymentFlow = paymentFlow
        super.init(nibName: nil, bundle: nil)

        navigationItem.rightBarButtonItems = [
            UIBarButtonItem(image: R.image.location(), style: .plain, target: self, action: #selector(showInfo)),
            UIBarButtonItem(image: R.image.settings_lock(), style: .plain, target: self, action: #selector(showContractWebPage))
        ]

        roundedBackground.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(roundedBackground)

        targetAddressTextField.label.translatesAutoresizingMaskIntoConstraints = false

        targetAddressTextField.translatesAutoresizingMaskIntoConstraints = false
        targetAddressTextField.delegate = self
        targetAddressTextField.textField.returnKeyType = .done

        nextButton.setTitle(R.string.localizable.aWalletNextButtonTitle(), for: .normal)
        nextButton.addTarget(self, action: #selector(nextButtonTapped), for: .touchUpInside)

        ticketView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(ticketView)

        let stackView = [
            header,
            ticketView,
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

            ticketView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            ticketView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

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
        delegate?.didEnterWalletAddress(ticketHolder: ticketHolder, to: address, paymentFlow: paymentFlow, in: self)
    }

    @objc func showInfo() {
        delegate?.didPressViewInfo(in: self)
    }

    @objc func showContractWebPage() {
        let url = Config().server.etherscanContractDetailsWebPageURL(for: viewModel.token.contract)
        openURL(url)
    }

    func configure(viewModel: TransferTicketsViaWalletAddressViewControllerViewModel) {
        self.viewModel = viewModel
        let contractAddress = XMLHandler().getAddressFromXML(server: RPCServer(chainID: Config().chainID)).eip55String
        if viewModel.token.contract != contractAddress {
            navigationItem.rightBarButtonItems = [UIBarButtonItem(image: R.image.settings_lock(), style: .plain, target: self, action: #selector(showContractWebPage))]
        }

        view.backgroundColor = viewModel.backgroundColor

        header.configure(title: viewModel.headerTitle)

        ticketView.configure(viewModel: .init(ticketHolder: ticketHolder))

        ticketView.stateLabel.isHidden = true

        targetAddressTextField.label.text = R.string.localizable.aSendRecipientAddressTitle()

        targetAddressTextField.configureOnce()

        nextButton.setTitleColor(viewModel.buttonTitleColor, for: .normal)
		nextButton.backgroundColor = viewModel.buttonBackgroundColor
        nextButton.titleLabel?.font = viewModel.buttonFont
    }

}

extension TransferTicketsViaWalletAddressViewController: QRCodeReaderDelegate {
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

extension TransferTicketsViaWalletAddressViewController: AddressTextFieldDelegate {
    func displayError(error: Error, for textField: AddressTextField) {
        displayError(error: error)
    }

    func openQRCodeReader(for textField: AddressTextField) {
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
