// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import UIKit

protocol NewTokenViewControllerDelegate: AnyObject {
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

extension Array where Element: UIView {
    func makeEach(isHidden: Bool) {
        for each in self {
            each.isHidden = isHidden
        }
    }
}

class NewTokenViewController: UIViewController {
    private let roundedBackground = RoundedBackground()
    private let scrollView = UIScrollView()
    private let footerBar = UIView()
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
    private lazy var balanceViews = TextField.layoutSubviews(for: balanceTextField)
    private lazy var decimalsViews = TextField.layoutSubviews(for: decimalsTextField)

    private lazy var addressViews: [UIView] = [
        addressTextField.label,
        .spacer(height: 4),
        addressTextField.defaultLayout(),
        .spacer(height: 4),
    ]

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
        changeServerButton.addTarget(self, action: #selector(changeServerAction), for: .touchUpInside)
        navigationItem.rightBarButtonItem = .init(customView: changeServerButton)

        roundedBackground.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(roundedBackground)

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        roundedBackground.addSubview(scrollView)

        addressTextField.delegate = self
        addressTextField.returnKeyType = .next
        addressTextField.value = "0x63cCEF733a093E5Bd773b41C96D3eCE361464942" //initialState.addressStringValue
        symbolTextField.delegate = self
        symbolTextField.returnKeyType = .next

        decimalsTextField.delegate = self
        decimalsTextField.inputAccessoryButtonType = .next
        decimalsTextField.keyboardType = .decimalPad
        decimalsTextField.returnKeyType = .next

        balanceTextField.delegate = self
        balanceTextField.inputAccessoryButtonType = .next
        balanceTextField.keyboardType = .numbersAndPunctuation
        balanceViews.makeEach(isHidden: true)

        nameTextField.delegate = self
        nameTextField.returnKeyType = .done

        let stackView = (
            [.spacer(height: 30)] +
            addressViews +
            TextField.layoutSubviews(for: symbolTextField) +
            decimalsViews +
            balanceViews +
            TextField.layoutSubviews(for: nameTextField)
        ).asStackView(axis: .vertical)

        stackView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stackView)

        buttonsBar.buttons[0].isEnabled = true

        footerBar.translatesAutoresizingMaskIntoConstraints = false
        footerBar.backgroundColor = .clear
        roundedBackground.addSubview(footerBar)

        footerBar.addSubview(buttonsBar)

        let xMargin  = CGFloat(16)
        scrollViewBottomAnchorConstraint = scrollView.bottomAnchor.constraint(equalTo: footerBar.topAnchor, constant: 0)
        NSLayoutConstraint.activate([

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

        ] + roundedBackground.createConstraintsWithContainer(view: view))

        configure()

        resizeViewToAccommodateKeyboard()
    }

    required init?(coder aDecoder: NSCoder) {
        return nil
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
        navigationItem.title = viewModel.title

        updateChangeServer(title: server.name)

        addressTextField.label.text = viewModel.addressLabel

        addressTextField.configureOnce()
        symbolTextField.configureOnce()
        decimalsTextField.configureOnce()
        balanceTextField.configureOnce()
        nameTextField.configureOnce()

        symbolTextField.label.textAlignment = .left
        symbolTextField.label.text = viewModel.symbolLabel
        symbolTextField.placeholder = viewModel.symbolLabel
        
        decimalsTextField.label.textAlignment = .left
        decimalsTextField.label.text = viewModel.decimalsLabel
        decimalsTextField.placeholder = viewModel.decimalsLabel

        balanceTextField.label.textAlignment = .left
        balanceTextField.label.text = viewModel.balanceLabel
        balanceTextField.placeholder = viewModel.balanceLabel

        nameTextField.label.textAlignment = .left
        nameTextField.label.text = viewModel.nameLabel
        nameTextField.placeholder = viewModel.nameLabel

        buttonsBar.configure()
        let saveButton = buttonsBar.buttons[0]
        saveButton.addTarget(self, action: #selector(addToken), for: .touchUpInside)
        saveButton.setTitle(R.string.localizable.save(), for: .normal)
    }

    private func updateSaveButtonBasedOnTokenTypeDetected() {
        let saveButton = buttonsBar.buttons[0]
        if tokenType == nil {
            saveButton.isEnabled = false
            saveButton.setTitle(R.string.localizable.detectingTokenTypeTitle(), for: .normal)
        } else {
            saveButton.isEnabled = true
            saveButton.setTitle(R.string.localizable.save(), for: .normal)
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
            decimalsViews.makeEach(isHidden: false)
            balanceViews.makeEach(isHidden: true)
        case .erc721, .erc875, .erc721ForTickets, .erc1155:
            decimalsViews.makeEach(isHidden: true)
            balanceViews.makeEach(isHidden: false)
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
            case .erc721, .erc875, .erc721ForTickets, .erc1155:
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

extension TextField {
    static func layoutSubviews(for textField: TextField) -> [UIView] {
        [textField.label, .spacer(height: 4), textField, .spacer(height: 4), textField.statusLabel, .spacer(height: 24)]
    }
}
