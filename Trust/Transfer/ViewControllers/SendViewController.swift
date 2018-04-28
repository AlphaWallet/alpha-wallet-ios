// Copyright SIX DAY LLC. All rights reserved.
// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit
import Eureka
import JSONRPCKit
import APIKit
import QRCodeReaderViewController
import BigInt
import TrustKeystore
import MBProgressHUD

protocol SendViewControllerDelegate: class {
    func didPressConfirm(
            transaction: UnconfirmedTransaction,
            transferType: TransferType,
            in viewController: SendViewController
    )
}

class SendViewController: UIViewController {
    //roundedBackground is used to achieve the top 2 rounded corners-only effect since maskedCorners to not round bottom corners is not available in iOS 10
    let roundedBackground = UIView()
    let header = SendHeaderView()
    let targetAddressTextField = UITextField()
    let amountTextField = UITextField()
    let alternativeAmountLabel = UILabel()
    let targetAddressLabel = UILabel()
    let amountLabel = UILabel()
    let myAddressContainer = UIView()
    let myAddressLabelLabel = UILabel()
    let myAddressLabel: UILabel = {
        let label = UILabel(frame: .zero)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 0
        label.textAlignment = .center
        label.minimumScaleFactor = 0.5
        label.adjustsFontSizeToFitWidth = true
        return label
    }()
    let copyButton: UIButton = {
        let button = Button(size: .normal, style: .border)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(copyAddress), for: .touchUpInside)
        return button
    }()
    let imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    let nextButton = UIButton(type: .system)

    var viewModel: SendViewModel!
    var headerViewModel = SendHeaderViewViewModel()
    var balanceViewModel: BalanceBaseViewModel?
    weak var delegate: SendViewControllerDelegate?

    struct Pair {
        let left: String
        let right: String

        func swapPair() -> Pair {
            return Pair(left: right, right: left)
        }
    }

    var pairValue = 0.0
    let session: WalletSession
    let account: Account
    let transferType: TransferType
    let storage: TokensDataStore

    private var allowedCharacters: String = {
        let decimalSeparator = Locale.current.decimalSeparator ?? "."
        return "0123456789" + decimalSeparator
    }()
    private var gasPrice: BigInt?
    private var data = Data()
    lazy var currentPair: Pair = {
        return Pair(left: viewModel.symbol, right: session.config.currency.rawValue)
    }()
    lazy var decimalFormatter: DecimalFormatter = {
        return DecimalFormatter()
    }()

    init(
            session: WalletSession,
            storage: TokensDataStore,
            account: Account,
            transferType: TransferType = .ether(destination: .none)
    ) {
        self.session = session
        self.account = account
        self.transferType = transferType
        self.storage = storage

        super.init(nibName: nil, bundle: nil)

        configureBalanceViewModel()

        roundedBackground.translatesAutoresizingMaskIntoConstraints = false
        roundedBackground.backgroundColor = Colors.appWhite
        roundedBackground.cornerRadius = 20
        view.addSubview(roundedBackground)

        targetAddressTextField.translatesAutoresizingMaskIntoConstraints = false
        targetAddressTextField.delegate = self
        targetAddressTextField.returnKeyType = .next
        targetAddressTextField.leftViewMode = .always
        targetAddressTextField.rightViewMode = .always

        amountTextField.translatesAutoresizingMaskIntoConstraints = false
        amountTextField.delegate = self
        amountTextField.keyboardType = .decimalPad
        amountTextField.leftViewMode = .always
        amountTextField.rightViewMode = .always
        amountTextField.inputAccessoryView = makeToolbarWithDoneButton()

        myAddressContainer.translatesAutoresizingMaskIntoConstraints = false

        let myAddressContainerCol0 = [
            myAddressLabelLabel,
            .spacer(height: 10),
            myAddressLabel,
            .spacer(height: 10),
            copyButton,
        ].asStackView(axis: .vertical, alignment: .center)
        myAddressContainerCol0.translatesAutoresizingMaskIntoConstraints = false

        let myAddressContainerStackView = [myAddressContainerCol0, .spacerWidth(20), imageView].asStackView(alignment: .center)
        myAddressContainerStackView.translatesAutoresizingMaskIntoConstraints = false
        myAddressContainer.addSubview(myAddressContainerStackView)

        nextButton.setTitle(R.string.localizable.aWalletTicketTokenTransferButtonTitle(), for: .normal)
        nextButton.addTarget(self, action: #selector(send), for: .touchUpInside)

        let buttonsStackView = [nextButton].asStackView(distribution: .fillEqually, contentHuggingPriority: .required)
        buttonsStackView.translatesAutoresizingMaskIntoConstraints = false

        let stackView = [
            header,
            .spacer(height: ScreenChecker().isNarrowScreen() ? 7: 20),
            targetAddressLabel,
            .spacer(height: ScreenChecker().isNarrowScreen() ? 2 : 4),
            targetAddressTextField,
            .spacer(height: ScreenChecker().isNarrowScreen() ? 7 : 14),
            amountLabel,
            .spacer(height: ScreenChecker().isNarrowScreen() ? 2 : 4),
            amountTextField,
            alternativeAmountLabel,
            .spacer(height: ScreenChecker().isNarrowScreen() ? 10: 20),
            myAddressContainer,
        ].asStackView(axis: .vertical, alignment: .center)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        roundedBackground.addSubview(stackView)


        let marginToHideBottomRoundedCorners = CGFloat(30)
        let footerBar = UIView()
        footerBar.translatesAutoresizingMaskIntoConstraints = false
        footerBar.backgroundColor = Colors.appHighlightGreen
        roundedBackground.addSubview(footerBar)

        let buttonsHeight = CGFloat(60)
        footerBar.addSubview(buttonsStackView)
        
        NSLayoutConstraint.activate([
            header.leadingAnchor.constraint(equalTo: roundedBackground.leadingAnchor, constant: 30),
            header.trailingAnchor.constraint(equalTo: roundedBackground.trailingAnchor, constant: -30),

            targetAddressTextField.leadingAnchor.constraint(equalTo: roundedBackground.leadingAnchor, constant: 30),
            targetAddressTextField.trailingAnchor.constraint(equalTo: roundedBackground.trailingAnchor, constant: -30),
            targetAddressTextField.heightAnchor.constraint(equalToConstant: ScreenChecker().isNarrowScreen() ? 30 : 50),

            amountTextField.leadingAnchor.constraint(equalTo: roundedBackground.leadingAnchor, constant: 30),
            amountTextField.trailingAnchor.constraint(equalTo: roundedBackground.trailingAnchor, constant: -30),
            amountTextField.heightAnchor.constraint(equalToConstant: ScreenChecker().isNarrowScreen() ? 30 : 50),

            myAddressContainerStackView.leadingAnchor.constraint(equalTo: myAddressContainer.leadingAnchor, constant: 20),
            myAddressContainerStackView.trailingAnchor.constraint(equalTo: myAddressContainer.trailingAnchor, constant: -20),
            myAddressContainerStackView.topAnchor.constraint(equalTo: myAddressContainer.topAnchor, constant: ScreenChecker().isNarrowScreen() ? 10 : 20),
            myAddressContainerStackView.bottomAnchor.constraint(equalTo: myAddressContainer.bottomAnchor, constant: ScreenChecker().isNarrowScreen() ? -10 : -20),

            myAddressContainer.leadingAnchor.constraint(equalTo: roundedBackground.leadingAnchor, constant: 30),
            myAddressContainer.trailingAnchor.constraint(equalTo: roundedBackground.trailingAnchor, constant: -30),

            roundedBackground.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            roundedBackground.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            roundedBackground.topAnchor.constraint(equalTo: view.topAnchor),
            roundedBackground.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: marginToHideBottomRoundedCorners),

            imageView.widthAnchor.constraint(equalTo: myAddressContainerStackView.widthAnchor, multiplier: 0.5, constant: 10),
            imageView.widthAnchor.constraint(equalTo: imageView.heightAnchor),

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

        storage.updatePrices()
        getGasPrice()
    }

    @objc func closeKeyboard() {
        view.endEditing(true)
    }

    func configure(viewModel: SendViewModel) {
        let firstConfigure = self.viewModel == nil
        self.viewModel = viewModel

        if firstConfigure {
            //Not good to rely on viewModel here on firstConfigure, which means if we change the padding on subsequent calls (which will probably never happen), it wouldn't be reflected. Unfortunately this needs to be here, otherwise while typing in the amount text field, the left and right views will move out of the text field momentarily
            amountTextField.leftView = .spacerWidth(viewModel.textFieldHorizontalPadding)
            amountTextField.rightView = makeAmountRightView()
            targetAddressTextField.leftView = .spacerWidth(viewModel.textFieldHorizontalPadding)
            targetAddressTextField.rightView = makeTargetAddressRightView()
        }

        changeQRCode(value: 0)

        view.backgroundColor = viewModel.backgroundColor

        header.configure(viewModel: headerViewModel)

        targetAddressTextField.textColor = viewModel.textFieldTextColor
        targetAddressTextField.font = viewModel.textFieldFont
        targetAddressTextField.layer.borderColor = viewModel.textFieldBorderColor.cgColor
        targetAddressTextField.layer.borderWidth = viewModel.textFieldBorderWidth

        //targetAddressLabel.text = R.string.localizable.aSendRecipientAddressTitle()
        targetAddressLabel.font = viewModel.textFieldsLabelFont
        targetAddressLabel.textColor = viewModel.textFieldsLabelTextColor

        //amountLabel.text = R.string.localizable.aSendRecipientAmountTitle()
        amountLabel.font = viewModel.textFieldsLabelFont
        amountLabel.textColor = viewModel.textFieldsLabelTextColor

        amountTextField.textColor = viewModel.textFieldTextColor
        amountTextField.font = viewModel.textFieldFont
        amountTextField.layer.borderColor = viewModel.textFieldBorderColor.cgColor
        amountTextField.layer.borderWidth = viewModel.textFieldBorderWidth

        alternativeAmountLabel.numberOfLines = 0
        alternativeAmountLabel.textColor = viewModel.alternativeAmountColor
        alternativeAmountLabel.font = viewModel.alternativeAmountFont
        alternativeAmountLabel.textAlignment = .center
        alternativeAmountLabel.text = viewModel.alternativeAmountText
        alternativeAmountLabel.isHidden = !viewModel.showAlternativeAmount

        //myAddressLabelLabel.text = R.string.localizable.aSendSenderAddressTitle()
        myAddressLabelLabel.font = viewModel.textFieldsLabelFont
        myAddressLabelLabel.textColor = viewModel.textFieldsLabelTextColor

        myAddressLabel.textColor = viewModel.myAddressTextColor
        myAddressLabel.font = viewModel.addressFont
        myAddressLabel.text = viewModel.myAddressText

        copyButton.titleLabel?.font = viewModel.copyAddressButtonFont
        copyButton.setTitle("    \(viewModel.copyAddressButtonTitle)    ", for: .normal)
        copyButton.setTitleColor(viewModel.copyAddressButtonTitleColor, for: .normal)
        copyButton.backgroundColor = viewModel.copyAddressButtonBackgroundColor

        myAddressContainer.borderColor = viewModel.myAddressBorderColor
        myAddressContainer.borderWidth = viewModel.myAddressBorderWidth
        myAddressContainer.cornerRadius = 20

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
        amountTextField.layer.cornerRadius = amountTextField.frame.size.height / 2
        copyButton.cornerRadius = copyButton.frame.size.height / 2
    }

    func getGasPrice() {
        let request = EtherServiceRequest(batch: BatchFactory().create(GasPriceRequest()))
        Session.send(request) { [weak self] result in
            switch result {
            case .success(let balance):
                self?.gasPrice = BigInt(balance.drop0x, radix: 16)
            case .failure: break
            }
        }
    }

    @objc func send() {
        let addressString = targetAddressTextField.text?.trimmed ?? ""
        var amountString = ""
        if self.currentPair.left == viewModel.symbol {
            amountString = amountTextField.text?.trimmed ?? ""
        } else {
            guard let formatedValue = decimalFormatter.string(from: NSNumber(value: self.pairValue)) else {
                return displayError(error: SendInputErrors.wrongInput)
            }
            amountString = formatedValue
        }
        guard let address = Address(string: addressString) else {
            return displayError(error: Errors.invalidAddress)
        }
        let parsedValue: BigInt? = {
            switch transferType {
            case .ether:
                return EtherNumberFormatter.full.number(from: amountString, units: .ether)
            case .token(let token):
                return EtherNumberFormatter.full.number(from: amountString, decimals: token.decimals)
            case .stormBird(let token):
                return EtherNumberFormatter.full.number(from: amountString, decimals: token.decimals)
            case .stormBirdOrder(let token):
                return EtherNumberFormatter.full.number(from: amountString, decimals: token.decimals)
            }
        }()
        guard let value = parsedValue else {
            return displayError(error: SendInputErrors.wrongInput)
        }

        let transaction = UnconfirmedTransaction(
                transferType: transferType,
                value: value,
                to: address,
                data: data,
                gasLimit: .none,
                gasPrice: gasPrice,
                nonce: .none,
                v: .none,
                r: .none,
                s: .none,
                expiry: .none,
                indices: .none
        )
        self.delegate?.didPressConfirm(transaction: transaction, transferType: transferType, in: self)
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
        activateAmountView()
    }

    @objc func fiatAction(sender: UIButton) {
        let swappedPair = currentPair.swapPair()
        //New pair for future calculation we should swap pair each time we press fiat button.
        self.currentPair = swappedPair

        if var viewModel = viewModel {
            viewModel.currentPair = currentPair
            viewModel.pairValue = 0
            configure(viewModel: viewModel)
        }

        //Update button title.
        sender.setTitle(currentPair.left, for: .normal)
        amountTextField.text = nil
        //Reset pair value.
        pairValue = 0.0
        //Update section.
        updatePriceSection()
        //Set focuse on pair change.
        activateAmountView()
    }

    @objc func copyAddress() {
        UIPasteboard.general.string = viewModel.myAddressText

        let hud = MBProgressHUD.showAdded(to: view, animated: true)
        hud.mode = .text
        hud.label.text = viewModel.addressCopiedText
        hud.hide(animated: true, afterDelay: 1.5)
    }

    func activateAmountView() {
        amountTextField.becomeFirstResponder()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func updatePriceSection() {
        guard viewModel.showAlternativeAmount else {
            return
        }

        if var viewModel = viewModel {
            viewModel.pairValue = pairValue
            configure(viewModel: viewModel)
        }
    }

    private func updatePairPrice(with amount: Double) {
        guard let rates = storage.tickers, let currentTokenInfo = rates[viewModel.destinationAddress.description], let price = Double(currentTokenInfo.price) else {
            return
        }
        if currentPair.left == viewModel.symbol {
            pairValue = amount * price
        } else {
            pairValue = amount / price
        }
        updatePriceSection()
    }

    private func addressTextFieldChanged(in range: NSRange, to string: String) -> Bool {
        return true
    }

    private func amountTextFieldChanged(in range: NSRange, to string: String) -> Bool {
        guard let input = amountTextField.text else {
            return true
        }
        //In this step we validate only allowed characters it is because of the iPad keyboard.
        let characterSet = NSCharacterSet(charactersIn: allowedCharacters).inverted
        let separatedChars = string.components(separatedBy: characterSet)
        let filteredNumbersAndSeparator = separatedChars.joined(separator: "")
        if string != filteredNumbersAndSeparator {
            return false
        }
        //This is required to prevent user from input of numbers like 1.000.25 or 1,000,25.
        if string == "," || string == "." || string == "'" {
            return !input.contains(string)
        }
        let text = (input as NSString).replacingCharacters(in: range, with: string)
        guard let amount = decimalFormatter.number(from: text) else {
            //Should be done in another way.
            pairValue = 0.0
            updatePriceSection()
            return true
        }
        updatePairPrice(with: amount.doubleValue)
        return true
    }

    private func changeQRCode(value: Int) {
        if let viewModel = viewModel {
            let string = viewModel.myAddressText
            DispatchQueue.global(qos: .background).async {
                // EIP67 format not being used much yet, use hex value for now
                // let string = "ethereum:\(account.address.address)?value=\(value)"
                let image = self.generateQRCode(from: string)
                DispatchQueue.main.async {
                    self.imageView.image = image
                }
            }
        }
    }

    private func generateQRCode(from string: String) -> UIImage? {
        return string.toQRCode()
    }

    private func configureBalanceViewModel() {
        switch transferType {
        case .ether:
            session.balanceViewModel.subscribe { viewModel in
                guard let viewModel = viewModel else { return }
                let amount = viewModel.amountShort
                self.headerViewModel.title = "\(amount) \(self.session.config.server.name) (\(viewModel.symbol))"
                let etherToken = TokensDataStore.etherToken(for: self.session.config)
                let ticker = self.storage.coinTicker(for: etherToken)
                self.headerViewModel.ticker = ticker
                self.headerViewModel.currencyAmount = self.session.balanceCoordinator.viewModel.currencyAmount
                self.headerViewModel.currencyAmountWithoutSymbol = self.session.balanceCoordinator.viewModel.currencyAmountWithoutSymbol
                if let viewModel = self.viewModel {
                    self.configure(viewModel: viewModel)
                }
            }
            session.refresh(.ethBalance)
        case .token(let token):
            let viewModel = BalanceTokenViewModel(token: token)
            let amount = viewModel.amountShort
            headerViewModel.title = "\(amount) \(viewModel.symbol)"
            let etherToken = TokensDataStore.etherToken(for: self.session.config)
            let ticker = self.storage.coinTicker(for: etherToken)
            self.headerViewModel.ticker = ticker
            self.headerViewModel.currencyAmount = self.session.balanceCoordinator.viewModel.currencyAmount
            self.headerViewModel.currencyAmountWithoutSymbol = self.session.balanceCoordinator.viewModel.currencyAmountWithoutSymbol
            if let viewModel = self.viewModel {
                configure(viewModel: self.viewModel)
            }
        default:
            break
        }
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

        let targetAddressRightView = [pasteButton, scanQRCodeButton].asStackView(distribution: .equalSpacing)
        targetAddressRightView.translatesAutoresizingMaskIntoConstraints = false

        return targetAddressRightView
    }

    private func makeAmountRightView() -> UIView {
        let fiatButton = Button(size: .normal, style: .borderless)
        fiatButton.translatesAutoresizingMaskIntoConstraints = false
        fiatButton.setTitle(currentPair.left, for: .normal)
        fiatButton.setTitleColor(Colors.appGrayLabelColor, for: .normal)
        fiatButton.addTarget(self, action: #selector(fiatAction), for: .touchUpInside)
        fiatButton.isHidden = !viewModel.showAlternativeAmount

        let amountRightView = [fiatButton].asStackView(distribution: .equalSpacing, spacing: 1)
        amountRightView.translatesAutoresizingMaskIntoConstraints = false

        return amountRightView
    }

    private func makeToolbarWithDoneButton() -> UIToolbar {
        //Frame needed, but actual values aren't that important
        let toolbar = UIToolbar(frame: CGRect(x: 0, y: 0, width: 100, height: 40))
        toolbar.barStyle = .default

        let flexSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let done = UIBarButtonItem(title: "Done", style: .done, target: self, action: #selector(closeKeyboard))

        toolbar.items = [flexSpace, done]
        toolbar.sizeToFit()

        return toolbar
    }
}

extension SendViewController: QRCodeReaderDelegate {
    func readerDidCancel(_ reader: QRCodeReaderViewController!) {
        reader.stopScanning()
        reader.dismiss(animated: true, completion: nil)
    }

    func reader(_ reader: QRCodeReaderViewController!, didScanResult result: String!) {
        reader.stopScanning()
        reader.dismiss(animated: true) { [weak self] in
            self?.activateAmountView()
        }

        guard let result = QRURLParser.from(string: result) else {
            return
        }
        targetAddressTextField.text = result.address

        if let dataString = result.params["data"] {
            data = Data(hex: dataString.drop0x)
        } else {
            data = Data()
        }

        if let value = result.params["amount"] {
            amountTextField.text = EtherNumberFormatter.full.string(from: BigInt(value) ?? BigInt(), units: .ether)
        } else {
            amountTextField.text = ""
        }
        pairValue = 0.0
        updatePriceSection()
    }
}

extension SendViewController: UITextFieldDelegate {
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        if textField == targetAddressTextField {
            return addressTextFieldChanged(in: range, to: string)
        } else if textField == amountTextField {
            return amountTextFieldChanged(in: range, to: string)
        } else {
            return true
        }
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField == targetAddressTextField {
            activateAmountView()
        } else if textField == amountTextField {
            view.endEditing(true)
        }
        return true
    }
}
