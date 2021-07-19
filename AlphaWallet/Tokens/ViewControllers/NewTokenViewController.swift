// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import UIKit

protocol NewTokenViewControllerDelegate: class {
    func didAddToken(token: ERCToken, in viewController: NewTokenViewController)
    func didAddAddress(address: AlphaWallet.Address, in viewController: NewTokenViewController)
    func didTapChangeServer(in viewController: NewTokenViewController)
    func openQRCode(in controller: NewTokenViewController)
    func didClose(viewController: NewTokenViewController)
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

enum NewTokenInitialState {
    case address(AlphaWallet.Address)
    case empty

    var addressStringValue: String {
        switch self {
        case .address(let address):
            return address.eip55String
        default:
            return String()
        }
    }
}

class NewTokenViewController: UIViewController {
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
    private let buttonsBar = ButtonsBar(configuration: .green(buttons: 1))
    private let changeServerButton = UIButton()
    private var scrollViewBottomAnchorConstraint: NSLayoutConstraint!
    private var shouldFireDetectionWhenAppear: Bool

    var server: RPCServerOrAuto
    weak var delegate: NewTokenViewControllerDelegate?

// swiftlint:disable function_body_length
    init(server: RPCServerOrAuto, initialState: NewTokenInitialState) {
        self.server = server
        switch initialState {
        case .address:
            shouldFireDetectionWhenAppear = true
        case .empty:
            shouldFireDetectionWhenAppear = false
        }
        super.init(nibName: nil, bundle: nil)

        hidesBottomBarWhenPushed = true

        changeServerButton.setTitleColor(Colors.navigationButtonTintColor, for: .normal)
        changeServerButton.addTarget(self, action: #selector(changeServerAction(_:)), for: .touchUpInside)
        navigationItem.rightBarButtonItem = .init(customView: changeServerButton)

        roundedBackground.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(roundedBackground)

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        roundedBackground.addSubview(scrollView)

        addressTextField.delegate = self
        addressTextField.returnKeyType = .next
        addressTextField.value = initialState.addressStringValue

        symbolTextField.delegate = self
        symbolTextField.returnKeyType = .next

        decimalsTextField.delegate = self
        decimalsTextField.inputAccessoryButtonType = .next
        decimalsTextField.keyboardType = .decimalPad
        decimalsTextField.returnKeyType = .next

        balanceTextField.delegate = self
        balanceTextField.inputAccessoryButtonType = .next
        balanceTextField.keyboardType = .numbersAndPunctuation
        balanceTextField.isHidden = true
        balanceTextField.label.isHidden = true

        nameTextField.delegate = self
        nameTextField.returnKeyType = .done

        let addressControlsContainer = UIView()
        addressControlsContainer.translatesAutoresizingMaskIntoConstraints = false
        addressControlsContainer.backgroundColor = .clear

        let addressControlsStackView = [
            addressTextField.pasteButton,
            addressTextField.clearButton
        ].asStackView(axis: .horizontal)
        addressControlsStackView.translatesAutoresizingMaskIntoConstraints = false

        addressControlsContainer.addSubview(addressControlsStackView)

        let stackView = [
            header,
            addressTextField.label,
            .spacer(height: 4),
            addressTextField,

            .spacer(height: 4), [
                [addressTextField.ensAddressView, addressTextField.statusLabel].asStackView(axis: .horizontal, alignment: .leading),
                addressControlsContainer
            ].asStackView(axis: .horizontal),
            .spacer(height: 4),

            symbolTextField.label,
            .spacer(height: 4),
            symbolTextField,
            .spacer(height: 4),
            symbolTextField.statusLabel,

            .spacer(height: 10),

            decimalsTextField.label,
            .spacer(height: 4),
            decimalsTextField,
            .spacer(height: 4),
            decimalsTextField.statusLabel,

            balanceTextField.label,
            .spacer(height: 4),
            balanceTextField,
            .spacer(height: 4),
            balanceTextField.statusLabel,
            .spacer(height: 6),

            nameTextField.label,
            .spacer(height: 4),
            nameTextField,
            .spacer(height: 4),
            nameTextField.statusLabel

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
            footerBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -ButtonsBar.buttonsHeight - ButtonsBar.marginAtBottomScreen),
            footerBar.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollViewBottomAnchorConstraint,

            addressControlsStackView.trailingAnchor.constraint(equalTo: addressControlsContainer.trailingAnchor),
            addressControlsStackView.topAnchor.constraint(equalTo: addressControlsContainer.topAnchor),
            addressControlsStackView.bottomAnchor.constraint(equalTo: addressControlsContainer.bottomAnchor),
            addressControlsStackView.leadingAnchor.constraint(greaterThanOrEqualTo: addressControlsContainer.leadingAnchor),
            addressControlsContainer.heightAnchor.constraint(equalToConstant: 30)

        ] + roundedBackground.createConstraintsWithContainer(view: view))

        configure()

        resizeViewToAccommodateKeyboard()
    }
// swiftlint:enable function_body_length

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        if shouldFireDetectionWhenAppear {
            shouldFireDetectionWhenAppear = false
            addressTextField.errorState = .none
            updateContractValue(value: addressTextField.value.trimmed)
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        if isMovingFromParent || isBeingDismissed {
            delegate?.didClose(viewController: self)
        }
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

        symbolTextField.label.textAlignment = .left
        symbolTextField.label.text = viewModel.symbolLabel

        decimalsTextField.label.textAlignment = .left
        decimalsTextField.label.text = viewModel.decimalsLabel

        balanceTextField.label.textAlignment = .left
        balanceTextField.label.text = viewModel.balanceLabel

        nameTextField.label.textAlignment = .left
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
    public func updateBalanceValue(_ balance: [String], tokenType: TokenType) {
        //TODO this happens to work for CryptoKitty now because of how isNonZeroBalance() is implemented. But should fix
        let filteredTokens = balance.filter { isNonZeroBalance($0, tokenType: tokenType) }
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
        case .erc721, .erc875, .erc721ForTickets:
            decimalsTextField.isHidden = true
            balanceTextField.isHidden = false
            decimalsTextField.label.isHidden = true
            balanceTextField.label.isHidden = false
        }
    }

    private func validate() -> Bool {
        var isValid: Bool = true

        if addressTextField.value.trimmed.isEmpty {
            let error = ValidationError(msg: R.string.localizable.warningFieldRequired())
            addressTextField.errorState = .error(error.prettyError)
            isValid = false
        } else {
            addressTextField.errorState = .none
        }

        if nameTextField.value.trimmed.isEmpty {
            let error = ValidationError(msg: R.string.localizable.warningFieldRequired())
            nameTextField.status = .error(error.prettyError)
            isValid = false
        } else {
            nameTextField.status = .none
        }

        if symbolTextField.value.trimmed.isEmpty {
            let error = ValidationError(msg: R.string.localizable.warningFieldRequired())
            symbolTextField.status = .error(error.prettyError)
            isValid = false
        } else {
            symbolTextField.status = .none
        }

        if let tokenType = tokenType {
            decimalsTextField.status = .none
            balanceTextField.status = .none

            switch tokenType {
            case .nativeCryptocurrency, .erc20:
                if decimalsTextField.value.trimmed.isEmpty {
                    let error = ValidationError(msg: R.string.localizable.warningFieldRequired())
                    decimalsTextField.status = .error(error.prettyError)
                    isValid = false
                }
            case .erc721, .erc875, .erc721ForTickets:
                if balanceTextField.value.trimmed.isEmpty {
                    let error = ValidationError(msg: R.string.localizable.warningFieldRequired())
                    balanceTextField.status = .error(error.prettyError)
                    isValid = false
                }
            }
        } else {
            isValid = false
        }

        return isValid
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

        guard let address = AlphaWallet.Address(string: contract) else {
            addressTextField.errorState = .error(Errors.invalidAddress.prettyError)
            return
        }
        addressTextField.errorState = .none

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
        guard let address = AlphaWallet.Address(string: value) else { return }
        delegate?.didAddAddress(address: address, in: self)
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
        let contract = addressTextField.value.trimmed
        if let contract = AlphaWallet.Address(string: contract) {
            updateContractValue(value: contract.eip55String)
        }
    }

    private func updateChangeServer(title: String) {
        changeServerButton.setTitle(title, for: .normal)
        //Needs to re-create navigationItem.rightBarButtonItem to update button width for new title's length
        navigationItem.rightBarButtonItem = .init(customView: changeServerButton)
    }
}

extension NewTokenViewController: AddressTextFieldDelegate {
    func didScanQRCode(_ result: String) {
        guard let result = QRCodeValueParser.from(string: result) else { return }
        switch result {
        case .address(let address):
            updateContractValue(value: address.eip55String)
        case .eip681:
            break
        }
    }

    func displayError(error: Error, for textField: AddressTextField) {
        textField.errorState = .error(error.prettyError)
    }

    func openQRCodeReader(for textField: AddressTextField) {
        delegate?.openQRCode(in: self)
    }

    func didPaste(in textField: AddressTextField) {
        textField.errorState = .none
        updateContractValue(value: textField.value.trimmed)
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
