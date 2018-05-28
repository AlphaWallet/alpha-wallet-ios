// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import TrustKeystore
import Eureka
import QRCodeReaderViewController

protocol NewTokenViewControllerDelegate: class {
    func didAddToken(token: ERCToken, in viewController: NewTokenViewController)
    func didAddAddress(address: String, in viewController: NewTokenViewController)
}

class NewTokenViewController: UIViewController {
    let roundedBackground = RoundedBackground()
    let scrollView = UIScrollView()
    let footerBar = UIView()
    let header = TicketsViewControllerTitleHeader()
    var viewModel = NewTokenViewModel()
    var isStormBirdToken: Bool = false

    let addressTextField = AddressTextField()
    let symbolTextField = TextField()
    let decimalsTextField = TextField()
    let balanceTextField = TextField()
    let nameTextField = TextField()
    let saveButton = UIButton(type: .system)

    var scrollViewBottomAnchorConstraint: NSLayoutConstraint!

    weak var delegate: NewTokenViewControllerDelegate?

    override func viewDidLoad() {
        super.viewDidLoad()

        roundedBackground.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(roundedBackground)

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        roundedBackground.addSubview(scrollView)

        addressTextField.label.translatesAutoresizingMaskIntoConstraints = false

        addressTextField.translatesAutoresizingMaskIntoConstraints = false
        addressTextField.delegate = self
        addressTextField.textField.returnKeyType = .next

        symbolTextField.label.translatesAutoresizingMaskIntoConstraints = false
        symbolTextField.delegate = self
        symbolTextField.translatesAutoresizingMaskIntoConstraints = false
        symbolTextField.textField.returnKeyType = .next

        decimalsTextField.label.translatesAutoresizingMaskIntoConstraints = false
        decimalsTextField.delegate = self
        decimalsTextField.inputAccessoryButtonType = .next
        decimalsTextField.translatesAutoresizingMaskIntoConstraints = false
        decimalsTextField.textField.keyboardType = .decimalPad
        decimalsTextField.textField.returnKeyType = .next

        balanceTextField.label.translatesAutoresizingMaskIntoConstraints = false
        balanceTextField.delegate = self
        balanceTextField.inputAccessoryButtonType = .next
        balanceTextField.translatesAutoresizingMaskIntoConstraints = false
        balanceTextField.textField.keyboardType = .numbersAndPunctuation
        balanceTextField.isHidden = true
        balanceTextField.label.isHidden = true

        nameTextField.label.translatesAutoresizingMaskIntoConstraints = false
        nameTextField.delegate = self
        nameTextField.translatesAutoresizingMaskIntoConstraints = false
        nameTextField.textField.returnKeyType = .done

        let stackView = [
            header,
            addressTextField.label,
            .spacer(height: 4),
            addressTextField,
            .spacer(height: 10),
            symbolTextField.label,
            .spacer(height: 4),
            symbolTextField,
            .spacer(height: 10),
            decimalsTextField.label,
            .spacer(height: 4),
            decimalsTextField,
            balanceTextField.label,
            .spacer(height: 4),
            balanceTextField,
            .spacer(height: 6),
            nameTextField.label,
            .spacer(height: 4),
            nameTextField,

        ].asStackView(axis: .vertical)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stackView)

        saveButton.setTitle(R.string.localizable.done(), for: .normal)
        saveButton.addTarget(self, action: #selector(addToken), for: .touchUpInside)

        let buttonsStackView = [saveButton].asStackView(distribution: .fillEqually, contentHuggingPriority: .required)
        buttonsStackView.translatesAutoresizingMaskIntoConstraints = false

        footerBar.translatesAutoresizingMaskIntoConstraints = false
        footerBar.backgroundColor = Colors.appHighlightGreen
        roundedBackground.addSubview(footerBar)

        let buttonsHeight = CGFloat(60)
        footerBar.addSubview(buttonsStackView)

        let xMargin  = CGFloat(7)
        scrollViewBottomAnchorConstraint = scrollView.bottomAnchor.constraint(equalTo: footerBar.topAnchor, constant: 0)
        NSLayoutConstraint.activate([
            header.heightAnchor.constraint(equalToConstant: 90),
            //Strange repositioning of header horizontally while typing without this
            header.leadingAnchor.constraint(equalTo: stackView.leadingAnchor),
            header.trailingAnchor.constraint(equalTo: stackView.trailingAnchor),

            stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: xMargin),
            stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -xMargin),
            stackView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            stackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            
            buttonsStackView.leadingAnchor.constraint(equalTo: footerBar.leadingAnchor),
            buttonsStackView.trailingAnchor.constraint(equalTo: footerBar.trailingAnchor),
            buttonsStackView.topAnchor.constraint(equalTo: footerBar.topAnchor),
            buttonsStackView.heightAnchor.constraint(equalToConstant: buttonsHeight),

            footerBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            footerBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            footerBar.heightAnchor.constraint(equalToConstant: buttonsHeight),
            footerBar.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollViewBottomAnchorConstraint,
        ] + roundedBackground.createConstraintsWithContainer(view: view))

        configure()

        resizeViewToAccommodateKeyboard()
    }

    public func configure() {
        view.backgroundColor = viewModel.backgroundColor

        header.configure(title: viewModel.title)

        addressTextField.label.textAlignment = .center
        addressTextField.label.text = viewModel.addressLabel

        addressTextField.configureOnce()
        symbolTextField.configureOnce()
        decimalsTextField.configureOnce()
        balanceTextField.configureOnce()
        nameTextField.configureOnce()

        symbolTextField.label.textAlignment = .center
        symbolTextField.label.text = viewModel.symbolLabel

        decimalsTextField.label.textAlignment = .center
        decimalsTextField.label.text = viewModel.decimalsLabel

        balanceTextField.label.textAlignment = .center
        balanceTextField.label.text = viewModel.balanceLabel

        nameTextField.label.textAlignment = .center
        nameTextField.label.text = viewModel.nameLabel

        saveButton.setTitleColor(viewModel.buttonTitleColor, for: .normal)
        saveButton.backgroundColor = viewModel.buttonBackgroundColor
        saveButton.titleLabel?.font = viewModel.buttonFont
    }

    public func updateSymbolValue(_ symbol: String) {
        symbolTextField.value = symbol
    }

    public func updateNameValue(_ name: String) {
        nameTextField.value = name
    }

    public func updateDecimalsValue(_ decimals: UInt8) {
        decimalsTextField.value = String(decimals)
    }

    //int is 64 bits, if this proves not enough later we can convert to BigUInt
    public func updateBalanceValue(_ balance: [String]) {
        viewModel.stormBirdBalance = balance
        balanceTextField.value = viewModel.stormBirdBalanceAsInt.description
    }

    public func updateFormForStormBirdToken(_ isStormBirdToken: Bool) {
        self.isStormBirdToken = isStormBirdToken
        if isStormBirdToken {
            decimalsTextField.isHidden = true
            balanceTextField.isHidden = false
            decimalsTextField.label.isHidden = true
            balanceTextField.label.isHidden = false
        } else {
            decimalsTextField.isHidden = false
            balanceTextField.isHidden = true
            decimalsTextField.label.isHidden = false
            balanceTextField.label.isHidden = true
        }
    }

    private func validate() -> Bool {
        guard !addressTextField.value.trimmed.isEmpty else {
            displayError(title: R.string.localizable.contractAddress(), error: ValidationError(msg: R.string.localizable.warningFieldRequired()))
            return false
        }
        guard !nameTextField.value.trimmed.isEmpty else {
            displayError(title: R.string.localizable.name(), error: ValidationError(msg: R.string.localizable.warningFieldRequired()))
            return false
        }
        guard !symbolTextField.value.trimmed.isEmpty else {
            displayError(title: R.string.localizable.symbol(), error: ValidationError(msg: R.string.localizable.warningFieldRequired()))
            return false
        }
        if isStormBirdToken {
            guard !balanceTextField.value.trimmed.isEmpty else {
                displayError(title: R.string.localizable.balance(), error: ValidationError(msg: R.string.localizable.warningFieldRequired()))
                return false
            }
        } else {
            guard !decimalsTextField.value.trimmed.isEmpty else {
                displayError(title: R.string.localizable.decimals(), error: ValidationError(msg: R.string.localizable.warningFieldRequired()))
                return false
            }
        }

        return true
    }

    @objc func addToken() {
        guard validate() else {
            return
        }

        let contract = addressTextField.value
        let name = nameTextField.value
        let symbol = symbolTextField.value
        let decimals = Int(decimalsTextField.value) ?? 0
        let isStormBird = self.isStormBirdToken
        var balance: [String] = viewModel.stormBirdBalance

        guard let address = Address(string: contract) else {
            return displayError(error: Errors.invalidAddress)
        }
        
        if balance.isEmpty {
            balance.append("0")
        }

        let erc20Token = ERCToken(
            contract: address,
            name: name,
            symbol: symbol,
            decimals: decimals,
            isStormBird: isStormBird,
            balance: balance
        )

        delegate?.didAddToken(token: erc20Token, in: self)
    }

    private func updateContractValue(value: String) {
        addressTextField.value = value
        delegate?.didAddAddress(address: value, in: self)
    }

    struct ValidationError: LocalizedError {
        var msg: String
        var errorDescription: String? {
            return msg
        }
    }

    @objc func keyboardWillShow(_ notification: Notification) {
        if let userInfo = notification.userInfo {
            if let keyboardSize = (userInfo[UIKeyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue, let duration = userInfo[UIKeyboardAnimationDurationUserInfoKey] as? TimeInterval {
                UIView.animate(withDuration: duration, animations: { () -> Void in
                    self.scrollViewBottomAnchorConstraint.constant = self.footerBar.bounds.size.height - keyboardSize.height
                })
            }
        }
    }

    @objc func keyboardWillHide(_ notification: Notification) {
        if let userInfo = notification.userInfo {
            if let duration = userInfo[UIKeyboardAnimationDurationUserInfoKey] as? TimeInterval {
                UIView.animate(withDuration: duration, animations: { () -> Void in
                    self.scrollViewBottomAnchorConstraint.constant = 0
                })
            }
        }
    }

    private func resizeViewToAccommodateKeyboard() {
        if UIDevice.current.userInterfaceIdiom == .pad {
            return
        }
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: .UIKeyboardWillShow, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: .UIKeyboardWillHide, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: .UIKeyboardWillChangeFrame, object: nil)
    }
}

extension NewTokenViewController: QRCodeReaderDelegate {
    func readerDidCancel(_ reader: QRCodeReaderViewController!) {
        reader.stopScanning()
        reader.dismiss(animated: true, completion: nil)
    }

    func reader(_ reader: QRCodeReaderViewController!, didScanResult result: String!) {
        reader.stopScanning()
        reader.dismiss(animated: true, completion: nil)

        guard let result = QRURLParser.from(string: result) else { return }
        updateContractValue(value: result.address)
    }
}

extension NewTokenViewController: AddressTextFieldDelegate {
    func displayError(error: Error, for textField: AddressTextField) {
        displayError(error: error)
    }

    func openQRCodeReader(for textField: AddressTextField) {
        let controller = QRCodeReaderViewController()
        controller.delegate = self
        present(controller, animated: true, completion: nil)
    }

    func didPaste(in textField: AddressTextField) {
        updateContractValue(value: textField.value)
        symbolTextField.textField.becomeFirstResponder()
    }

    func shouldReturn(in textField: AddressTextField) -> Bool {
        symbolTextField.textField.becomeFirstResponder()
        return true
    }

    func shouldChange(in range: NSRange, to string: String, in textField: AddressTextField) -> Bool {
        let newValue = (textField.value as NSString?)?.replacingCharacters(in: range, with: string)
        if let newValue = newValue, CryptoAddressValidator.isValidAddress(newValue) {
            updateContractValue(value: newValue)
        }
        return true
    }
}

extension NewTokenViewController: TextFieldDelegate {
    func shouldReturn(in textField: TextField) -> Bool {
        moveFocusToTextField(after: textField)
        return true
    }

    func doneButtonTapped(for textField: TextField) {
        view.endEditing(true)
    }

    func nextButtonTapped(for textField: TextField) {
        moveFocusToTextField(after: textField)
    }

    private func moveFocusToTextField(after textField: TextField) {
        switch textField {
        case symbolTextField:
            if decimalsTextField.isHidden {
                balanceTextField.textField.becomeFirstResponder()
            } else {
                decimalsTextField.textField.becomeFirstResponder()
            }
        case decimalsTextField, balanceTextField:
            nameTextField.textField.becomeFirstResponder()
        case nameTextField:
            view.endEditing(true)
        default:
            break
        }
    }
}
