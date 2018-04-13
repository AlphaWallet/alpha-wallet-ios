// Copyright © 2018 Stormbird PTE. LTD.

import UIKit
import MessageUI

enum TicketTransferMode {
    case walletAddressTextEntry
    case walletAddressFromQRCode
    case other
}

protocol ChooseTicketTransferModeViewControllerDelegate: class {
    func didChoose(transferMode: TicketTransferMode, in viewController: ChooseTicketTransferModeViewController)
}

class ChooseTicketTransferModeViewController: UIViewController {
    //roundedBackground is used to achieve the top 2 rounded corners-only effect since maskedCorners to not round bottom corners is not available in iOS 10
    let roundedBackground = UIView()
    let titleLabel = UILabel()
    let inputWalletAddressButton = TransferModeButton()
    let qrCodeScannerButton = TransferModeButton()
    let otherButton = TransferModeButton()
	let ticketHolder: TicketHolder
    var paymentFlow: PaymentFlow
    weak var delegate: ChooseTicketTransferModeViewControllerDelegate?

    init(ticketHolder: TicketHolder, paymentFlow: PaymentFlow) {
        self.ticketHolder = ticketHolder
        self.paymentFlow = paymentFlow

        super.init(nibName: nil, bundle: nil)
        view.backgroundColor = Colors.appBackground

        roundedBackground.translatesAutoresizingMaskIntoConstraints = false
        roundedBackground.cornerRadius = 20
        view.addSubview(roundedBackground)

        inputWalletAddressButton.callback = {
            self.delegate?.didChoose(transferMode: .walletAddressTextEntry, in: self)
        }
        inputWalletAddressButton.translatesAutoresizingMaskIntoConstraints = false

        qrCodeScannerButton.callback = {
            self.delegate?.didChoose(transferMode: .walletAddressFromQRCode, in: self)
        }
        qrCodeScannerButton.translatesAutoresizingMaskIntoConstraints = false

        otherButton.callback = {
            self.delegate?.didChoose(transferMode: .other, in: self)
        }
        otherButton.translatesAutoresizingMaskIntoConstraints = false

        let buttonRow1 = UIStackView(arrangedSubviews: [
            inputWalletAddressButton,
            qrCodeScannerButton,
        ])
        buttonRow1.translatesAutoresizingMaskIntoConstraints = false
        buttonRow1.axis = .horizontal
        buttonRow1.spacing = 12
        buttonRow1.distribution = .fill

        let buttonPlaceholder = UIView()
        let buttonRow2 = UIStackView(arrangedSubviews: [
            otherButton,
            buttonPlaceholder,
        ])
        buttonRow2.translatesAutoresizingMaskIntoConstraints = false
        buttonRow2.axis = .horizontal
        buttonRow2.spacing = 12
        buttonRow2.distribution = .fill

        let stackView = UIStackView(arrangedSubviews: [
            .spacer(height: 7),
            titleLabel,
            .spacer(height: 20),
            buttonRow1,
            .spacer(height: 12),
            buttonRow2,
        ])
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .vertical
        stackView.spacing = 0
        stackView.distribution = .fill
        roundedBackground.addSubview(stackView)

        let marginToHideBottomRoundedCorners = CGFloat(30)
        NSLayoutConstraint.activate([
            otherButton.widthAnchor.constraint(equalTo: inputWalletAddressButton.widthAnchor),
            otherButton.heightAnchor.constraint(equalTo: inputWalletAddressButton.heightAnchor),
            otherButton.widthAnchor.constraint(equalTo: buttonPlaceholder.widthAnchor),
            otherButton.heightAnchor.constraint(equalTo: buttonPlaceholder.heightAnchor),

            stackView.leadingAnchor.constraint(equalTo: roundedBackground.leadingAnchor, constant: 30),
            stackView.trailingAnchor.constraint(equalTo: roundedBackground.trailingAnchor, constant: -30),
            stackView.topAnchor.constraint(equalTo: roundedBackground.topAnchor, constant: 16),

            roundedBackground.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            roundedBackground.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            roundedBackground.topAnchor.constraint(equalTo: view.topAnchor),
            roundedBackground.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: marginToHideBottomRoundedCorners),
        ])
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(viewModel: ChooseTicketTransferModeViewControllerViewModel) {
        roundedBackground.backgroundColor = viewModel.contentsBackgroundColor
        roundedBackground.layer.cornerRadius = 20

        titleLabel.numberOfLines = 0
        titleLabel.textColor = viewModel.titleColor
        titleLabel.font = viewModel.titleFont
        titleLabel.textAlignment = .center
        titleLabel.text = viewModel.titleLabelText

        inputWalletAddressButton.title = viewModel.inputWalletAddressButtonTitle
        inputWalletAddressButton.image = viewModel.inputWalletAddressButtonImage

        qrCodeScannerButton.title = viewModel.qrCodeScannerButtonTitle
        qrCodeScannerButton.image = viewModel.qrCodeScannerButtonImage

        otherButton.title = viewModel.otherButtonTitle
        otherButton.image = viewModel.otherButtonImage

        inputWalletAddressButton.label.font = viewModel.buttonTitleFont
        qrCodeScannerButton.label.font = viewModel.buttonTitleFont
        otherButton.label.font = viewModel.buttonTitleFont

        inputWalletAddressButton.label.textColor = viewModel.buttonTitleColor
        qrCodeScannerButton.label.textColor = viewModel.buttonTitleColor
        otherButton.label.textColor = viewModel.buttonTitleColor
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        inputWalletAddressButton.layer.cornerRadius = inputWalletAddressButton.frame.size.height / 2
        qrCodeScannerButton.layer.cornerRadius = qrCodeScannerButton.frame.size.height / 2
    }
}

