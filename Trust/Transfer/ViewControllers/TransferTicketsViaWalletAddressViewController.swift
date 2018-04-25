// Copyright © 2018 Stormbird PTE. LTD.

import UIKit
import QRCodeReaderViewController

protocol TransferTicketsViaWalletAddressViewControllerDelegate: class {
    func didEnterWalletAddress(ticketHolder: TicketHolder, to walletAddress: String, paymentFlow: PaymentFlow, in viewController: TransferTicketsViaWalletAddressViewController)
    func didPressViewInfo(in viewController: TransferTicketsViaWalletAddressViewController)
}

class TransferTicketsViaWalletAddressViewController: UIViewController {

    //roundedBackground is used to achieve the top 2 rounded corners-only effect since maskedCorners to not round bottom corners is not available in iOS 10
    let roundedBackground = UIView()
    let header = TicketsViewControllerTitleHeader()
    let ticketView = TicketRowView()
    let targetAddressLabel = UILabel()
    let targetAddressTextField = UITextField()
    let nextButton = UIButton(type: .system)
    var viewModel: TransferTicketsViaWalletAddressViewControllerViewModel!
    var ticketHolder: TicketHolder
    var paymentFlow: PaymentFlow
    weak var delegate: TransferTicketsViaWalletAddressViewControllerDelegate?

    init(ticketHolder: TicketHolder, paymentFlow: PaymentFlow) {
        self.ticketHolder = ticketHolder
        self.paymentFlow = paymentFlow
        super.init(nibName: nil, bundle: nil)

        navigationItem.rightBarButtonItem = UIBarButtonItem(image: R.image.location(), style: .plain, target: self, action: #selector(showInfo))

        roundedBackground.translatesAutoresizingMaskIntoConstraints = false
        roundedBackground.backgroundColor = Colors.appWhite
        roundedBackground.cornerRadius = 20
        view.addSubview(roundedBackground)

        targetAddressTextField.translatesAutoresizingMaskIntoConstraints = false
        targetAddressTextField.delegate = self
        targetAddressTextField.returnKeyType = .done
        targetAddressTextField.leftViewMode = .always
        targetAddressTextField.rightViewMode = .always

        nextButton.setTitle(R.string.localizable.aWalletNextButtonTitle(), for: .normal)
        nextButton.addTarget(self, action: #selector(nextButtonTapped), for: .touchUpInside)

        ticketView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(ticketView)

        let stackView = UIStackView(arrangedSubviews: [
            header,
            ticketView,
            .spacer(height: 10),
            targetAddressLabel,
            .spacer(height: ScreenChecker().isNarrowScreen() ? 2 : 4),
            targetAddressTextField,
        ])
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .vertical
        stackView.spacing = 0
        stackView.distribution = .fill
		stackView.alignment = .center
        roundedBackground.addSubview(stackView)

        let buttonsStackView = UIStackView(arrangedSubviews: [nextButton])
        buttonsStackView.translatesAutoresizingMaskIntoConstraints = false
        buttonsStackView.axis = .horizontal
        buttonsStackView.spacing = 0
        buttonsStackView.distribution = .fillEqually
        buttonsStackView.setContentHuggingPriority(.required, for: .horizontal)

        let marginToHideBottomRoundedCorners = CGFloat(30)
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
            targetAddressTextField.heightAnchor.constraint(equalToConstant: ScreenChecker().isNarrowScreen() ? 30 : 50),

            roundedBackground.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            roundedBackground.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            roundedBackground.topAnchor.constraint(equalTo: view.topAnchor),
            roundedBackground.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: marginToHideBottomRoundedCorners),

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
        ])
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc func nextButtonTapped() {
        let address = targetAddressTextField.text?.trimmed ?? ""
        delegate?.didEnterWalletAddress(ticketHolder: ticketHolder, to: address, paymentFlow: paymentFlow, in: self)
    }

    @objc func showInfo() {
        delegate?.didPressViewInfo(in: self)
    }

    func configure(viewModel: TransferTicketsViaWalletAddressViewControllerViewModel) {
        let firstConfigure = self.viewModel == nil
        self.viewModel = viewModel

        if firstConfigure {
            targetAddressTextField.leftView = .spacerWidth(viewModel.textFieldHorizontalPadding)
            targetAddressTextField.rightView = makeTargetAddressRightView()
        }

        view.backgroundColor = viewModel.backgroundColor

        header.configure(title: viewModel.headerTitle)

        ticketView.configure(viewModel: .init())

        ticketView.stateLabel.isHidden = true

        ticketView.ticketCountLabel.text = viewModel.ticketCount

        ticketView.titleLabel.text = viewModel.title

        ticketView.venueLabel.text = viewModel.venue

        ticketView.dateLabel.text = viewModel.date

        ticketView.seatRangeLabel.text = viewModel.seatRange

        ticketView.zoneNameLabel.text = viewModel.zoneName

        targetAddressTextField.textColor = viewModel.textFieldTextColor
        targetAddressTextField.font = viewModel.textFieldFont
        targetAddressTextField.layer.borderColor = viewModel.textFieldBorderColor.cgColor
        targetAddressTextField.layer.borderWidth = viewModel.textFieldBorderWidth

        targetAddressLabel.text = R.string.localizable.aSendRecipientAddressTitle()
        targetAddressLabel.font = viewModel.textFieldsLabelFont
        targetAddressLabel.textColor = viewModel.textFieldsLabelTextColor

        nextButton.setTitleColor(viewModel.buttonTitleColor, for: .normal)
		nextButton.backgroundColor = viewModel.buttonBackgroundColor
        nextButton.titleLabel?.font = viewModel.buttonFont
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        roundCornersBasedOnHeight()
    }

    private func roundCornersBasedOnHeight() {
        targetAddressTextField.layer.cornerRadius = targetAddressTextField.frame.size.height / 2
    }

    @objc func openReader() {
        let controller = QRCodeReaderViewController()
        controller.delegate = self
        present(controller, animated: true, completion: nil)
    }

    @objc func pasteAction() {
        guard let value = UIPasteboard.general.string?.trimmed else {
            return displayError(error: SendInputErrors.emptyClipBoard)
        }

        guard CryptoAddressValidator.isValidAddress(value) else {
            return displayError(error: Errors.invalidAddress)
        }
        targetAddressTextField.text = value
    }

    private func makeTargetAddressRightView() -> UIView {
        let pasteButton = Button(size: .normal, style: .borderless)
        pasteButton.translatesAutoresizingMaskIntoConstraints = false
        pasteButton.setTitle(R.string.localizable.sendPasteButtonTitle(), for: .normal)
        pasteButton.titleLabel?.font = Fonts.regular(size: 14)!
        pasteButton.setTitleColor(Colors.appGrayLabelColor, for: .normal)
        pasteButton.addTarget(self, action: #selector(pasteAction), for: .touchUpInside)

        let scanQRCodeButton = Button(size: .normal, style: .borderless)
        scanQRCodeButton.translatesAutoresizingMaskIntoConstraints = false
        scanQRCodeButton.setImage(R.image.qr_code_icon(), for: .normal)
        scanQRCodeButton.setTitleColor(Colors.appGrayLabelColor, for: .normal)
        scanQRCodeButton.addTarget(self, action: #selector(openReader), for: .touchUpInside)

        let targetAddressRightView = UIStackView(arrangedSubviews: [
            pasteButton,
            scanQRCodeButton,
        ])
        targetAddressRightView.translatesAutoresizingMaskIntoConstraints = false
        targetAddressRightView.distribution = .equalSpacing
        targetAddressRightView.spacing = 0
        targetAddressRightView.axis = .horizontal

        return targetAddressRightView
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
        targetAddressTextField.text = result.address
    }
}

extension TransferTicketsViaWalletAddressViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        view.endEditing(true)
        return true
    }
}
