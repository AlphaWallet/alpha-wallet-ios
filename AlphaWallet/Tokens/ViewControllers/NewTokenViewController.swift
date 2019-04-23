// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import TrustKeystore
import QRCodeReaderViewController

protocol NewTokenViewControllerDelegate: class {
    func didAddToken(token: ERCToken, in viewController: NewTokenViewController)
    func didAddAddress(address: String, in viewController: NewTokenViewController)
    func didTapChangeServer(in viewController: NewTokenViewController)
}

enum RPCServerOrAuto: Hashable {
    case auto
    case server(RPCServer)

    var displayName: String {
        switch self {
        case .auto:
            return R.string.localizable.detectingServerAutomatically()
        case .server(let server):
            return server.displayName
        }
    }

    var name: String {
        switch self {
        case .auto:
            return R.string.localizable.detectingServerAutomaticallyButtonTitle()
        case .server(let server):
            return server.name
        }
    }
}

class NewTokenViewController: UIViewController, CanScanQRCode {
    private let roundedBackground = RoundedBackground()
    private let scrollView = UIScrollView()
    private let footerBar = UIView()
    private let header = TokensCardViewControllerTitleHeader()
    private var viewModel = NewTokenViewModel()
    private var tokenType: TokenType? = nil {
        didSet {
            updateSaveButtonBasedOnTokenTypeDetected()
        }
    }
    private let addressTextField = AddressTextField()
    private let symbolTextField = TextField()
    private let decimalsTextField = TextField()
    private let balanceTextField = TextField()
    private let nameTextField = TextField()
    private let buttonsBar = ButtonsBar(numberOfButtons: 1)
    private let changeServerButton = UIButton()
    private var scrollViewBottomAnchorConstraint: NSLayoutConstraint!

    var server: RPCServerOrAuto
    weak var delegate: NewTokenViewControllerDelegate?

    init(server: RPCServerOrAuto) {
        self.server = server
        super.init(nibName: nil, bundle: nil)

        changeServerButton.addTarget(self, action: #selector(changeServerAction(_:)), for: .touchUpInside)
        navigationItem.rightBarButtonItem = .init(customView: changeServerButton)

        roundedBackground.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(roundedBackground)

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        roundedBackground.addSubview(scrollView)

        addressTextField.translatesAutoresizingMaskIntoConstraints = false
        addressTextField.delegate = self
        addressTextField.returnKeyType = .next

        symbolTextField.label.translatesAutoresizingMaskIntoConstraints = false
        symbolTextField.delegate = self
        symbolTextField.translatesAutoresizingMaskIntoConstraints = false
        symbolTextField.returnKeyType = .next

        decimalsTextField.label.translatesAutoresizingMaskIntoConstraints = false
        decimalsTextField.delegate = self
        decimalsTextField.inputAccessoryButtonType = .next
        decimalsTextField.translatesAutoresizingMaskIntoConstraints = false
        decimalsTextField.keyboardType = .decimalPad
        decimalsTextField.returnKeyType = .next

        balanceTextField.label.translatesAutoresizingMaskIntoConstraints = false
        balanceTextField.delegate = self
        balanceTextField.inputAccessoryButtonType = .next
        balanceTextField.translatesAutoresizingMaskIntoConstraints = false
        balanceTextField.keyboardType = .numbersAndPunctuation
        balanceTextField.isHidden = true
        balanceTextField.label.isHidden = true

        nameTextField.label.translatesAutoresizingMaskIntoConstraints = false
        nameTextField.delegate = self
        nameTextField.translatesAutoresizingMaskIntoConstraints = false
        nameTextField.returnKeyType = .done

        let stackView = [
            header,
            addressTextField.label,
            .spacer(height: 4),
            addressTextField,
            addressTextField.ensAddressLabel,
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

        buttonsBar.buttons[0].isEnabled = true

        footerBar.translatesAutoresizingMaskIntoConstraints = false
        footerBar.backgroundColor = .clear
        roundedBackground.addSubview(footerBar)

        footerBar.addSubview(buttonsBar)

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
            
            buttonsBar.leadingAnchor.constraint(equalTo: footerBar.leadingAnchor),
            buttonsBar.trailingAnchor.constraint(equalTo: footerBar.trailingAnchor),
            buttonsBar.topAnchor.constraint(equalTo: footerBar.topAnchor),
            buttonsBar.heightAnchor.constraint(equalToConstant: ButtonsBar.buttonsHeight),

            footerBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            footerBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            footerBar.topAnchor.constraint(equalTo: view.layoutGuide.bottomAnchor, constant: -ButtonsBar.buttonsHeight - ButtonsBar.marginAtBottomScreen),
            footerBar.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollViewBottomAnchorConstraint,
        ] + roundedBackground.createConstraintsWithContainer(view: view))

        configure()

        resizeViewToAccommodateKeyboard()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func configure() {
        view.backgroundColor = viewModel.backgroundColor

        header.configure(title: viewModel.title)

        updateChangeServer(title: server.name)

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

        buttonsBar.configure()
        let saveButton = buttonsBar.buttons[0]
        saveButton.addTarget(self, action: #selector(addToken), for: .touchUpInside)
        saveButton.setTitle(R.string.localizable.done(), for: .normal)
    }

    private func updateSaveButtonBasedOnTokenTypeDetected() {
        let saveButton = buttonsBar.buttons[0]
        if tokenType == nil {
            saveButton.isEnabled = false
            saveButton.setTitle(R.string.localizable.detectingTokenTypeTitle(), for: .normal)

        } else {
            saveButton.isEnabled = true
            saveButton.setTitle(R.string.localizable.done(), for: .normal)
        }
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
        //TODO this happens to work for CryptoKitty now because of how isNonZeroBalance() is implemented. But should fix
        let filteredTokens = balance.filter { isNonZeroBalance($0) }
        viewModel.ERC875TokenBalance = filteredTokens
        balanceTextField.value = viewModel.ERC875TokenBalanceAmount.description
    }

    public func updateForm(forTokenType tokenType: TokenType) {
        self.tokenType = tokenType
        switch tokenType {
        case .nativeCryptocurrency, .erc20:
            decimalsTextField.isHidden = false
            balanceTextField.isHidden = true
            decimalsTextField.label.isHidden = false
            balanceTextField.label.isHidden = true
        case .erc721, .erc875:
            decimalsTextField.isHidden = true
            balanceTextField.isHidden = false
            decimalsTextField.label.isHidden = true
            balanceTextField.label.isHidden = false
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
        guard let tokenType = tokenType else { return false }

        switch tokenType {
        case .nativeCryptocurrency, .erc20:
            guard !decimalsTextField.value.trimmed.isEmpty else {
                displayError(title: R.string.localizable.decimals(), error: ValidationError(msg: R.string.localizable.warningFieldRequired()))
                return false
            }
        case .erc721, .erc875:
            guard !balanceTextField.value.trimmed.isEmpty else {
                displayError(title: R.string.localizable.balance(), error: ValidationError(msg: R.string.localizable.warningFieldRequired()))
                return false
            }
        }

        return true
    }

    @objc func addToken() {
        guard validate() else { return }
        let server: RPCServer
        switch self.server {
        case .auto:
            return
        case .server(let chosenServer):
            server = chosenServer
        }

        let contract = addressTextField.value
        let name = nameTextField.value
        let symbol = symbolTextField.value
        let decimals = Int(decimalsTextField.value) ?? 0
        guard let tokenType = self.tokenType else { return }
        //TODO looks wrong to mention ERC875TokenBalance specifically
        var balance: [String] = viewModel.ERC875TokenBalance
        
        guard let address = Address(string: contract) else {
            return displayError(error: Errors.invalidAddress)
        }
        
        if balance.isEmpty {
            balance.append("0")
        }

        let ercToken = ERCToken(
            contract: address,
            server: server,
            name: name,
            symbol: symbol,
            decimals: decimals,
            type: tokenType,
            balance: balance
        )

        delegate?.didAddToken(token: ercToken, in: self)
    }

    @objc private func changeServerAction(_ sender: UIView) {
        delegate?.didTapChangeServer(in: self)
    }

    private func updateContractValue(value: String) {
        tokenType = nil
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
            if let keyboardSize = (userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue, let duration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval {
                UIView.animate(withDuration: duration, animations: { [weak self] () -> Void in
                    guard let strongSelf = self else { return }
                    strongSelf.scrollViewBottomAnchorConstraint.constant = strongSelf.footerBar.bounds.size.height - keyboardSize.height
                })
            }
        }
    }

    @objc func keyboardWillHide(_ notification: Notification) {
        if let userInfo = notification.userInfo {
            if let duration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval {
                UIView.animate(withDuration: duration, animations: { [weak self] () -> Void in
                    self?.scrollViewBottomAnchorConstraint.constant = 0
                })
            }
        }
    }

    private func resizeViewToAccommodateKeyboard() {
        if UIDevice.current.userInterfaceIdiom == .pad {
            return
        }
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
    }

    func redetectToken() {
        let contract = addressTextField.value
        if CryptoAddressValidator.isValidAddress(contract) {
            updateContractValue(value: contract)
        }
    }

    private func updateChangeServer(title: String) {
        changeServerButton.setTitle(title, for: .normal)
        //Needs to re-create navigationItem.rightBarButtonItem to update button width for new title's length
        navigationItem.rightBarButtonItem = .init(customView: changeServerButton)
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
        guard AVCaptureDevice.authorizationStatus(for: .video) != .denied else {
            promptUserOpenSettingsToChangeCameraPermission()
            return
        }
        let controller = QRCodeReaderViewController(cancelButtonTitle: nil, chooseFromPhotoLibraryButtonTitle: R.string.localizable.photos())
        controller.delegate = self
        present(controller, animated: true, completion: nil)
    }

    func didPaste(in textField: AddressTextField) {
        updateContractValue(value: textField.value)
        view.endEditing(true)
    }

    func shouldReturn(in textField: AddressTextField) -> Bool {
        _ = symbolTextField.becomeFirstResponder()
        return true
    }

    func didChange(to string: String, in textField: AddressTextField) {
        if CryptoAddressValidator.isValidAddress(string) {
            updateContractValue(value: string)
        }
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
                _ = balanceTextField.becomeFirstResponder()
            } else {
                _ = decimalsTextField.becomeFirstResponder()
            }
        case decimalsTextField, balanceTextField:
            _ = nameTextField.becomeFirstResponder()
        case nameTextField:
            view.endEditing(true)
        default:
            break
        }
    }
}
