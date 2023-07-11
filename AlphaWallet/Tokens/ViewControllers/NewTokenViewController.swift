// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import UIKit
import struct AlphaWalletCore.CryptoAddressValidator
import AlphaWalletFoundation

protocol NewTokenViewControllerDelegate: AnyObject {
    func didAddToken(ercToken: ErcToken, in viewController: NewTokenViewController)
    func didAddAddress(address: AlphaWallet.Address, in viewController: NewTokenViewController)
    func didTapChangeServer(in viewController: NewTokenViewController)
    func openQRCode(in controller: NewTokenViewController)
    func didClose(viewController: NewTokenViewController)
}

extension RPCServerOrAuto {
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
    private var viewModel = NewTokenViewModel()
    private var tokenType: TokenType? {
        didSet {
            updateSaveButtonBasedOnTokenTypeDetected()
        }
    }
    private lazy var addressTextField: AddressTextField = {
        let textField = AddressTextField(server: RPCServer.forResolvingDomainNames, domainResolutionService: domainResolutionService)
        textField.returnKeyType = .next
        textField.inputAccessoryButtonType = .next
        textField.delegate = self

        return textField
    }()
    private lazy var symbolTextField: TextField = {
        let textField = TextField.buildTextField()
        textField.inputAccessoryButtonType = .next
        textField.returnKeyType = .next
        textField.delegate = self

        return textField
    }()
    private lazy var decimalsTextField: TextField = {
        let textField = TextField.buildTextField()
        textField.inputAccessoryButtonType = .next
        textField.keyboardType = .decimalPad
        textField.returnKeyType = .next
        textField.delegate = self

        return textField
    }()
    private lazy var balanceTextField: TextField = {
        let textField = TextField.buildTextField()
        textField.inputAccessoryButtonType = .next
        textField.keyboardType = .numbersAndPunctuation
        textField.delegate = self

        return textField
    }()
    private lazy var nameTextField: TextField = {
        let textField = TextField.buildTextField()
        textField.inputAccessoryButtonType = .done
        textField.returnKeyType = .done
        textField.delegate = self

        return textField
    }()

    private let buttonsBar = HorizontalButtonsBar(configuration: .primary(buttons: 1))
    private let changeServerButton: UIButton = {
        let button = UIButton()
        button.setTitleColor(Configuration.Color.Semantic.navigationBarButtonItemTint, for: .normal)

        return button
    }()
    private var shouldFireDetectionWhenAppear: Bool
    private let domainResolutionService: DomainNameResolutionServiceType
    private lazy var balanceTextFieldLayout = balanceTextField.defaultLayout()
    private lazy var decimalsTextFieldLayout: UIView = {
        let view = decimalsTextField.defaultLayout()
        view.isHidden = true

        return view
    }()

    var server: RPCServerOrAuto
    weak var delegate: NewTokenViewControllerDelegate?

    private lazy var containerView: ScrollableStackView = {
        let containerView = ScrollableStackView()
        containerView.stackView.spacing = ScreenChecker.size(big: 24, medium: 24, small: 20)
        containerView.stackView.axis = .vertical
        containerView.scrollView.showsVerticalScrollIndicator = false

        return containerView
    }()

    init(server: RPCServerOrAuto, domainResolutionService: DomainNameResolutionServiceType, initialState: NewTokenInitialState) {
        self.server = server
        self.domainResolutionService = domainResolutionService
        switch initialState {
        case .address:
            shouldFireDetectionWhenAppear = true
        case .empty:
            shouldFireDetectionWhenAppear = false
        }
        super.init(nibName: nil, bundle: nil)

        hidesBottomBarWhenPushed = true
        navigationItem.rightBarButtonItem = .init(customView: changeServerButton)

        addressTextField.value = initialState.addressStringValue
        containerView.stackView.addArrangedSubviews([
            .spacer(height: 0), //NOTE: 0 for applying insets of stack view
            addressTextField.defaultLayout(edgeInsets: .zero),
            symbolTextField.defaultLayout(),
            decimalsTextFieldLayout,
            balanceTextFieldLayout,
            nameTextField.defaultLayout()
        ])

        buttonsBar.buttons[0].isEnabled = true

        let footerBar = ButtonsBarBackgroundView(buttonsBar: buttonsBar)

        view.addSubview(footerBar)
        view.addSubview(containerView)

        NSLayoutConstraint.activate([
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: DataEntry.Metric.Container.xMargin),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -DataEntry.Metric.Container.xMargin),
            containerView.topAnchor.constraint(equalTo: view.topAnchor),
            containerView.bottomAnchor.constraint(equalTo: footerBar.topAnchor),

            footerBar.anchorsConstraint(to: view)
        ])

    }

    required init?(coder aDecoder: NSCoder) {
        return nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = Configuration.Color.Semantic.defaultViewBackground
        changeServerButton.addTarget(self, action: #selector(changeServerAction), for: .touchUpInside)
        configure()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        if shouldFireDetectionWhenAppear {
            shouldFireDetectionWhenAppear = false
            addressTextField.errorState = .none
            updateContractValue(value: addressTextField.value.trimmed)
        }
    }

    public func configure() {
        navigationItem.title = viewModel.title

        updateChangeServer(title: server.name)

        addressTextField.label.text = viewModel.addressLabel
        symbolTextField.label.text = viewModel.symbolLabel
        decimalsTextField.label.text = viewModel.decimalsLabel
        balanceTextField.label.text = viewModel.balanceLabel
        nameTextField.label.text = viewModel.nameLabel

        buttonsBar.configure()
        let saveButton = buttonsBar.buttons[0]
        saveButton.addTarget(self, action: #selector(addTokenButtonSelected), for: .touchUpInside)
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

    public func updateDecimalsValue(_ decimals: Int) {
        decimalsTextField.value = String(decimals)
    }

    //int is 64 bits, if this proves not enough later we can convert to BigUInt
    public func updateBalanceValue(_ balance: NonFungibleBalance, tokenType: TokenType) {
        //TODO this happens to work for CryptoKitty now because of how isNonZeroBalance() is implemented. But should fix
        let filteredBalance: NonFungibleBalance
        switch balance {
        case .assets(let values):
            filteredBalance = .assets(values.filter { isNonZeroBalance($0.json, tokenType: tokenType) })
        case .erc875(let values):
            filteredBalance = .erc875(values.filter { isNonZeroBalance($0, tokenType: tokenType) })
        case .erc721ForTickets(let values):
            filteredBalance = .erc721ForTickets(values.filter { isNonZeroBalance($0, tokenType: tokenType) })
        case .balance(let values):
            filteredBalance = .balance(values.filter { isNonZeroBalance($0, tokenType: tokenType) })
        }

        viewModel.nonFungibleBalance = filteredBalance
        balanceTextField.value = viewModel.nonFungibleBalanceAmount.description
    }

    public func updateForm(forTokenType tokenType: TokenType) {
        self.tokenType = tokenType
        switch tokenType {
        case .nativeCryptocurrency, .erc20:
            decimalsTextFieldLayout.isHidden = false
            balanceTextFieldLayout.isHidden = true
        case .erc721, .erc875, .erc721ForTickets, .erc1155:
            decimalsTextFieldLayout.isHidden = true
            balanceTextFieldLayout.isHidden = false
        }
    }

    private func validate() -> Bool {
        var isValid: Bool = true

        if addressTextField.value.trimmed.isEmpty {
            addressTextField.errorState = .error(R.string.localizable.warningFieldRequired())
            isValid = false
        } else {
            addressTextField.errorState = .none
        }

        if let tokenType = tokenType, !tokenType.shouldHaveNameAndSymbol {
            nameTextField.status = .none
        } else if !nameTextField.value.trimmed.isEmpty {
            nameTextField.status = .none
        } else {
            nameTextField.status = .error(R.string.localizable.warningFieldRequired())
            isValid = false
        }

        if let tokenType = tokenType, !tokenType.shouldHaveNameAndSymbol {
            symbolTextField.status = .none
        } else if !symbolTextField.value.trimmed.isEmpty {
            symbolTextField.status = .none
        } else {
            symbolTextField.status = .error(R.string.localizable.warningFieldRequired())
            isValid = false
        }

        if let tokenType = tokenType {
            decimalsTextField.status = .none
            balanceTextField.status = .none

            switch tokenType {
            case .nativeCryptocurrency, .erc20:
                if decimalsTextField.value.trimmed.isEmpty {
                    decimalsTextField.status = .error(R.string.localizable.warningFieldRequired())
                    isValid = false
                }
            case .erc721, .erc875, .erc721ForTickets, .erc1155:
                if balanceTextField.value.trimmed.isEmpty {
                    balanceTextField.status = .error(R.string.localizable.warningFieldRequired())
                    isValid = false
                }
            }
        } else {
            isValid = false
        }

        return isValid
    }

    @objc private func addTokenButtonSelected(_ sender: UIButton) {
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

        var nonFungibleBalance: NonFungibleBalance
        switch tokenType {
        case .erc875:
            if let balance = viewModel.nonFungibleBalance {
                nonFungibleBalance = balance.rawValue.isEmpty ? .erc875(["0"]) : balance
            } else {
                nonFungibleBalance = .erc875(["0"])
            }
        case .nativeCryptocurrency, .erc20, .erc721, .erc1155:
            nonFungibleBalance = viewModel.nonFungibleBalance ?? .balance([])
        case .erc721ForTickets:
            nonFungibleBalance = viewModel.nonFungibleBalance ?? .erc721ForTickets([])
        }

        guard let address = AlphaWallet.Address(string: contract) else {
            addressTextField.errorState = .error(InputError.invalidAddress.localizedDescription)
            return
        }
        addressTextField.errorState = .none

        let ercToken = ErcToken(contract: address, server: server, name: name, symbol: symbol, decimals: decimals, type: tokenType, value: .zero, balance: nonFungibleBalance)

        delegate?.didAddToken(ercToken: ercToken, in: self)
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

extension NewTokenViewController: PopNotifiable {
    func didPopViewController(animated: Bool) {
        delegate?.didClose(viewController: self)
    }
}

extension NewTokenViewController: AddressTextFieldDelegate {
    func nextButtonTapped(for textField: AddressTextField) {
        symbolTextField.becomeFirstResponder()
    }

    func didScanQRCode(_ result: String) {
        switch AddressOrEip681Parser.from(string: result) {
        case .address(let address):
            updateContractValue(value: address.eip55String)
        case .eip681, .none:
            break
        }
    }

    func displayError(error: Error, for textField: AddressTextField) {
        textField.errorState = .error(error.localizedDescription)
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
        symbolTextField.becomeFirstResponder()
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
            if decimalsTextFieldLayout.isHidden {
                balanceTextField.becomeFirstResponder()
            } else {
                decimalsTextField.becomeFirstResponder()
            }
        case decimalsTextField, balanceTextField:
            nameTextField.becomeFirstResponder()
        case nameTextField:
            view.endEditing(true)
        default:
            break
        }
    }
}
