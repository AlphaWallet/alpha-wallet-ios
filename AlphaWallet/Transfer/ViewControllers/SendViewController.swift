// Copyright SIX DAY LLC. All rights reserved.
// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit
import JSONRPCKit
import APIKit
import PromiseKit
import BigInt
import MBProgressHUD

protocol SendViewControllerDelegate: class, CanOpenURL {
    func didPressConfirm(transaction: UnconfirmedTransaction, in viewController: SendViewController, amount: String, shortValue: String?)
    func lookup(contract: AlphaWallet.Address, in viewController: SendViewController, completion: @escaping (ContractData) -> Void)
    func openQRCode(in controller: SendViewController)
}

// swiftlint:disable type_body_length
class SendViewController: UIViewController {
    private let roundedBackground = RoundedBackground()
    private let scrollView = UIScrollView()
    private let recipientHeader = SendViewSectionHeader()
    private let amountHeader = SendViewSectionHeader()
    private let recipientAddressLabel = UILabel()
    private let amountLabel = UILabel()
    private let buttonsBar = ButtonsBar(configuration: .green(buttons: 1))
    private var viewModel: SendViewModel
    private var balanceViewModel: BalanceBaseViewModel?
    private let session: WalletSession
    private let account: AlphaWallet.Address
    private let ethPrice: Subscribable<Double>
    private let assetDefinitionStore: AssetDefinitionStore
    private var currentSubscribableKeyForNativeCryptoCurrencyBalance: Subscribable<BalanceBaseViewModel>.SubscribableKey?
    private var currentSubscribableKeyForNativeCryptoCurrencyPrice: Subscribable<Double>.SubscribableKey?
    private let amountViewModel = SendViewSectionHeaderViewModel(
        text: R.string.localizable.sendAmount().uppercased(),
        showTopSeparatorLine: false
    )
    private let recipientViewModel = SendViewSectionHeaderViewModel(
        text: R.string.localizable.sendRecipient().uppercased()
    )
    //We use weak link to make sure that token alert will be deallocated by close button tapping.
    //We storing link to make sure that only one alert is displaying on the screen.
    private weak var invalidTokenAlert: UIViewController?
    let targetAddressTextField = AddressTextField()
    lazy var amountTextField = AmountTextField(tokenObject: transactionType.tokenObject)
    weak var delegate: SendViewControllerDelegate?

    var transactionType: TransactionType {
        return viewModel.transactionType
    }

    let storage: TokensDataStore
    @objc private (set) dynamic var isAllFunds: Bool = false
    private var observation: NSKeyValueObservation!

// swiftlint:disable function_body_length
    init(
            session: WalletSession,
            storage: TokensDataStore,
            account: AlphaWallet.Address,
            transactionType: TransactionType,
            cryptoPrice: Subscribable<Double>,
            assetDefinitionStore: AssetDefinitionStore
    ) {
        self.session = session
        self.account = account
        self.storage = storage
        self.ethPrice = cryptoPrice
        self.assetDefinitionStore = assetDefinitionStore
        self.viewModel = .init(transactionType: transactionType, session: session, storage: storage)

        super.init(nibName: nil, bundle: nil)

        configureBalanceViewModel()

        roundedBackground.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(roundedBackground)

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        roundedBackground.addSubview(scrollView)

        targetAddressTextField.translatesAutoresizingMaskIntoConstraints = false
        targetAddressTextField.delegate = self
        targetAddressTextField.returnKeyType = .done

        amountTextField.translatesAutoresizingMaskIntoConstraints = false
        amountTextField.delegate = self
        amountTextField.accessoryButtonTitle = .next
        amountTextField.errorState = .none

        let addressControlsContainer = UIView()
        addressControlsContainer.translatesAutoresizingMaskIntoConstraints = false
        addressControlsContainer.backgroundColor = .clear

        targetAddressTextField.pasteButton.contentHorizontalAlignment = .right
        let addressControlsStackView = [
            targetAddressTextField.pasteButton,
            targetAddressTextField.clearButton
        ].asStackView(axis: .horizontal, alignment: .trailing)
        addressControlsStackView.translatesAutoresizingMaskIntoConstraints = false
        addressControlsStackView.setContentHuggingPriority(.required, for: .horizontal)
        addressControlsStackView.setContentCompressionResistancePriority(.required, for: .horizontal)

        addressControlsContainer.addSubview(addressControlsStackView)

        let stackView = [
            amountHeader,
            .spacer(height: ScreenChecker().isNarrowScreen ? 7 : 27),
            amountLabel,
            .spacer(height: ScreenChecker().isNarrowScreen ? 2 : 4),
            amountTextField,
            .spacer(height: 4),
            [amountTextField.statusLabelContainer, amountTextField.allFundsContainer].asStackView(axis: .horizontal, alignment: .fill),
            amountTextField.alternativeAmountLabelContainer,
            .spacer(height: ScreenChecker().isNarrowScreen ? 7: 14),
            recipientHeader,
            .spacer(height: ScreenChecker().isNarrowScreen ? 7: 16),
            [.spacerWidth(16), recipientAddressLabel].asStackView(axis: .horizontal),
            .spacer(height: ScreenChecker().isNarrowScreen ? 2 : 4),
            targetAddressTextField,
            .spacer(height: 4), [
                [.spacerWidth(16), targetAddressTextField.ensAddressView, targetAddressTextField.statusLabel].asStackView(axis: .horizontal, alignment: .leading),
                addressControlsContainer
            ].asStackView(axis: .horizontal),
        ].asStackView(axis: .vertical)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stackView)

        let footerBar = UIView()
        footerBar.translatesAutoresizingMaskIntoConstraints = false
        footerBar.backgroundColor = .clear
        roundedBackground.addSubview(footerBar)

        footerBar.addSubview(buttonsBar)

        NSLayoutConstraint.activate([
            amountHeader.leadingAnchor.constraint(equalTo: roundedBackground.leadingAnchor, constant: 0),
            amountHeader.trailingAnchor.constraint(equalTo: roundedBackground.trailingAnchor, constant: 0),
            amountHeader.heightAnchor.constraint(equalToConstant: 50),

            recipientHeader.leadingAnchor.constraint(equalTo: roundedBackground.leadingAnchor, constant: 0),
            recipientHeader.trailingAnchor.constraint(equalTo: roundedBackground.trailingAnchor, constant: 0),
            recipientHeader.heightAnchor.constraint(equalToConstant: 50),

            recipientAddressLabel.heightAnchor.constraint(equalToConstant: 22),
            targetAddressTextField.leadingAnchor.constraint(equalTo: roundedBackground.leadingAnchor, constant: 16),
            targetAddressTextField.trailingAnchor.constraint(equalTo: roundedBackground.trailingAnchor, constant: -16),

            amountTextField.leadingAnchor.constraint(equalTo: roundedBackground.leadingAnchor, constant: 16),
            amountTextField.trailingAnchor.constraint(equalTo: roundedBackground.trailingAnchor, constant: -16),
            amountTextField.heightAnchor.constraint(equalToConstant: ScreenChecker().isNarrowScreen ? 30 : 50),

            stackView.leadingAnchor.constraint(equalTo: roundedBackground.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: roundedBackground.trailingAnchor),
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
            scrollView.bottomAnchor.constraint(equalTo: footerBar.topAnchor),

            addressControlsStackView.trailingAnchor.constraint(equalTo: addressControlsContainer.trailingAnchor, constant: -7),
            addressControlsStackView.topAnchor.constraint(equalTo: addressControlsContainer.topAnchor),
            addressControlsStackView.bottomAnchor.constraint(equalTo: addressControlsContainer.bottomAnchor),
            addressControlsStackView.leadingAnchor.constraint(greaterThanOrEqualTo: addressControlsContainer.leadingAnchor),
            addressControlsContainer.heightAnchor.constraint(equalToConstant: 30)

        ] + roundedBackground.createConstraintsWithContainer(view: view))

        storage.updatePrices()

        observation = observe(\.isAllFunds, options: [.initial, .new]) { [weak self] _, _ in
            guard let strongSelf = self else { return }

            strongSelf.amountTextField.isAllFunds = strongSelf.isAllFunds
        }
    }
// swiftlint:enable function_body_length

    override func viewDidLoad() {
        super.viewDidLoad()
        activateAmountView()
    }

    @objc func closeKeyboard() {
        view.endEditing(true)
    }

    func configure(viewModel: SendViewModel, shouldConfigureBalance: Bool = true) {
        self.viewModel = viewModel
        //Avoids infinite recursion
        if shouldConfigureBalance {
            configureBalanceViewModel()
        }

        targetAddressTextField.configureOnce()

        view.backgroundColor = viewModel.backgroundColor

        amountHeader.configure(viewModel: amountViewModel)
        recipientHeader.configure(viewModel: recipientViewModel)

        recipientAddressLabel.text = viewModel.recipientsAddress
        recipientAddressLabel.font = viewModel.recipientLabelFont
        recipientAddressLabel.textColor = viewModel.recepientLabelTextColor

        amountLabel.font = viewModel.textFieldsLabelFont
        amountLabel.textColor = viewModel.textFieldsLabelTextColor
        amountTextField.isAlternativeAmountEnabled = false
        amountTextField.allFundsAvailable = Features.isSendAllFundsFungibleEnabled
        amountTextField.selectCurrencyButton.isHidden = viewModel.currencyButtonHidden
        amountTextField.selectCurrencyButton.expandIconHidden = viewModel.selectCurrencyButtonHidden

        amountTextField.statusLabel.text = viewModel.availableLabelText
        amountTextField.availableTextHidden = viewModel.availableTextHidden

        switch transactionType {
        case .nativeCryptocurrency(_, let recipient, let amount):
            if let recipient = recipient {
                targetAddressTextField.value = recipient.stringValue
            }
            if let amount = amount {
                amountTextField.ethCost = EtherNumberFormatter.plain.string(from: amount, units: .ether)
            }
            currentSubscribableKeyForNativeCryptoCurrencyPrice = ethPrice.subscribe { [weak self] value in
                if let value = value {
                    self?.amountTextField.cryptoToDollarRate = NSDecimalNumber(value: value)
                }
            }
        case .ERC20Token(_, let recipient, let amount):
            currentSubscribableKeyForNativeCryptoCurrencyPrice.flatMap { ethPrice.unsubscribe($0) }
            amountTextField.cryptoToDollarRate = nil

            if let recipient = recipient {
                targetAddressTextField.value = recipient.stringValue
            }
            if let amount = amount {
                amountTextField.ethCost = amount
            }
        case .ERC875Token, .ERC875TokenOrder, .ERC721Token, .ERC721ForTicketToken, .dapp, .tokenScript, .claimPaidErc875MagicLink:
            currentSubscribableKeyForNativeCryptoCurrencyPrice.flatMap { ethPrice.unsubscribe($0) }
            amountTextField.cryptoToDollarRate = nil
        }

        buttonsBar.configure()
        let nextButton = buttonsBar.buttons[0]
        nextButton.setTitle(R.string.localizable.send(), for: .normal)
        nextButton.addTarget(self, action: #selector(sendUsingKaleido), for: .touchUpInside)

        amountTextField.allFundsButton.addTarget(self, action: #selector(allFundsSelected), for: .touchUpInside)
        updateNavigationTitle()
    }

    private func updateNavigationTitle() {
        title = "\(R.string.localizable.send()) \(transactionType.symbol)"
    }

    @objc func allFundsSelected() {
        switch transactionType {
        case .nativeCryptocurrency:
            guard let ethCost = allFundsFormattedValues else { return }
            isAllFunds = true

            amountTextField.set(ethCost: ethCost.allFundsFullValue, shortEthCost: ethCost.allFundsShortValue, useFormatting: false)
        case .ERC20Token:
            guard let ethCost = allFundsFormattedValues else { return }
            isAllFunds = true

            amountTextField.set(ethCost: ethCost.allFundsFullValue, shortEthCost: ethCost.allFundsShortValue, useFormatting: false)
        case .dapp, .ERC721ForTicketToken, .ERC721Token, .ERC875Token, .ERC875TokenOrder, .tokenScript, .claimPaidErc875MagicLink:
            break
        }
    }

    private var allFundsFormattedValues: (allFundsFullValue: NSDecimalNumber?, allFundsShortValue: String)? {
        switch transactionType {
        case .nativeCryptocurrency:
            guard let balance = session.balance else { return nil }

            let fullValue = EtherNumberFormatter.plain.string(from: balance.value, units: .ether).droppedTrailingZeros
            let shortValue = EtherNumberFormatter.shortPlain.string(from: balance.value, units: .ether).droppedTrailingZeros

            return (fullValue.optionalDecimalValue, shortValue)
        case .ERC20Token(let token, _, _):
            let fullValue = EtherNumberFormatter.plain.string(from: token.valueBigInt, decimals: token.decimals).droppedTrailingZeros
            let shortValue = EtherNumberFormatter.shortPlain.string(from: token.valueBigInt, decimals: token.decimals).droppedTrailingZeros

            return (fullValue.optionalDecimalValue, shortValue)
        case .dapp, .ERC721ForTicketToken, .ERC721Token, .ERC875Token, .ERC875TokenOrder, .tokenScript, .claimPaidErc875MagicLink:
            return nil
        }
    }

    // MARK: add new "send" func to reuse VC UI and send KaleidoService requests instead for testing
    @objc private func sendUsingKaleido() {
        let input = targetAddressTextField.value.trimmed
        guard let recipient = AlphaWallet.Address(string: input) else {
            targetAddressTextField.errorState = .error(Errors.invalidAddress.prettyError)
            return
        }

        self.buttonsBar.isHidden = true
        let ind = UIActivityIndicatorView(frame: CGRect(origin: roundedBackground.center, size: CGSize(width: 30, height: 30)))
        ind.style = .gray
        roundedBackground.addSubview(ind)
        ind.startAnimating()
    
        func showAlert(with hash: String) {
            ind.stopAnimating()
            self.buttonsBar.isHidden = false
            self.buttonsBar.buttons[0].backgroundColor = .green
            let alert = UIAlertController(title: "Send result", message: hash, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
            present(alert, animated: true, completion: nil)
        }

        switch transactionType {
        case .nativeCryptocurrency:
            let hash = KaleidoService.send(to: recipient)
            showAlert(with: hash)
        case .ERC20Token:
            KaleidoService.fundAccount(with: transactionType.contract.eip55String,
                                                     to: recipient.eip55String,
                                                     amount: "0") { hash in
                showAlert(with: hash)
            }
        default:
            return
        }
    }
    
    @objc private func send() {
        let input = targetAddressTextField.value.trimmed
        targetAddressTextField.errorState = .none
        amountTextField.errorState = .none
        let checkIfGreaterThanZero: Bool
        switch transactionType {
        case .nativeCryptocurrency, .dapp, .tokenScript, .claimPaidErc875MagicLink:
            checkIfGreaterThanZero = false
        case .ERC20Token, .ERC875Token, .ERC875TokenOrder, .ERC721Token, .ERC721ForTicketToken:
            checkIfGreaterThanZero = true
        }

        guard let value = viewModel.validatedAmount(value: amountTextField.ethCost, checkIfGreaterThanZero: checkIfGreaterThanZero) else {
            amountTextField.errorState = .error
            return
        }
        guard let recipient = AlphaWallet.Address(string: input) else {
            targetAddressTextField.errorState = .error(Errors.invalidAddress.prettyError)
            return
        }

        let transaction = UnconfirmedTransaction(
                transactionType: transactionType,
                value: value,
                recipient: recipient,
                contract: transactionType.contractForFungibleSend,
                data: nil
        )

        delegate?.didPressConfirm(transaction: transaction, in: self, amount: amountTextField.ethCost, shortValue: shortValueForAllFunds)
    }

    var shortValueForAllFunds: String? {
        return isAllFunds ? allFundsFormattedValues?.allFundsShortValue : .none
    }

    func activateAmountView() {
        amountTextField.becomeFirstResponder()
    }

    required init?(coder aDecoder: NSCoder) {
        return nil
    }

    private func configureBalanceViewModel() {
        currentSubscribableKeyForNativeCryptoCurrencyBalance.flatMap { session.balanceViewModel.unsubscribe($0) }
        currentSubscribableKeyForNativeCryptoCurrencyPrice.flatMap { ethPrice.unsubscribe($0) }
        switch transactionType {
        case .nativeCryptocurrency(_, let recipient, let amount):
            currentSubscribableKeyForNativeCryptoCurrencyBalance = session.balanceViewModel.subscribe { [weak self] viewModel in
                guard let celf = self else { return }
                guard celf.storage.token(forContract: celf.viewModel.transactionType.contract) != nil else { return }
                celf.configureFor(contract: celf.viewModel.transactionType.contract, recipient: recipient, amount: amount, shouldConfigureBalance: false)
            }
            session.refresh(.ethBalance)
        case .ERC20Token(let token, let recipient, let amount):
            let amount = amount.flatMap { EtherNumberFormatter.plain.number(from: $0, decimals: token.decimals) }
            configureFor(contract: viewModel.transactionType.contract, recipient: recipient, amount: amount, shouldConfigureBalance: false)
        case .ERC875Token, .ERC875TokenOrder, .ERC721Token, .ERC721ForTicketToken, .dapp, .tokenScript, .claimPaidErc875MagicLink:
            break
        }
    }

    func didScanQRCode(_ result: String) {
        guard let result = QRCodeValueParser.from(string: result) else { return }
        switch result {
        case .address(let recipient):
            guard let tokenObject = storage.token(forContract: viewModel.transactionType.contract) else { return }
            let amountAsIntWithDecimals = EtherNumberFormatter.plain.number(from: amountTextField.ethCost, decimals: tokenObject.decimals)
            configureFor(contract: transactionType.contract, recipient: .address(recipient), amount: amountAsIntWithDecimals)
            activateAmountView()
        case .eip681(let protocolName, let address, let functionName, let params):
            checkAndFillEIP681Details(protocolName: protocolName, address: address, functionName: functionName, params: params)
        }
    }

    private func showInvalidToken() {
        guard invalidTokenAlert == nil else { return }

        invalidTokenAlert = UIAlertController.alert(
            message: R.string.localizable.sendInvalidToken(),
            alertButtonTitles: [R.string.localizable.oK()],
            alertButtonStyles: [.cancel],
            viewController: self
        )
    }

    private func checkAndFillEIP681Details(protocolName: String, address: AddressOrEnsName, functionName: String?, params: [String: String]) {
        //TODO error display on returns
        Eip681Parser(protocolName: protocolName, address: address, functionName: functionName, params: params).parse().done { result in
            guard let (contract: contract, optionalServer, recipient, maybeScientificAmountString) = result.parameters else { return }
            let amount = self.convertMaybeScientificAmountToBigInt(maybeScientificAmountString)
            //For user-safety and simpler implementation, we ignore the link if it is for a different chain
            if let server = optionalServer {
                guard self.session.server == server else { return }
            }

            if self.storage.token(forContract: contract) != nil {
                //For user-safety and simpler implementation, we ignore the link if it is for a different chain
                self.configureFor(contract: contract, recipient: recipient, amount: amount)
                self.activateAmountView()
            } else {
                self.delegate?.lookup(contract: contract, in: self) { data in
                    switch data {
                    case .name, .symbol, .balance, .decimals:
                        break
                    case .nonFungibleTokenComplete:
                        self.showInvalidToken()
                    case .fungibleTokenComplete(let name, let symbol, let decimals):
                        //TODO update fetching to retrieve balance too so we can display the correct balance in the view controller
                        let token = ERCToken(
                                contract: contract,
                                server: self.storage.server,
                                name: name,
                                symbol: symbol,
                                decimals: Int(decimals),
                                type: .erc20,
                                balance: ["0"]
                        )
                        self.storage.addCustom(token: token)
                        self.configureFor(contract: contract, recipient: recipient, amount: amount)
                        self.activateAmountView()
                    case .delegateTokenComplete:
                        self.showInvalidToken()
                    case .failed:
                        break
                    }
                }
            }
        }.cauterize()
    }

    //This function is required because BigInt.init(String) doesn't handle scientific notation
    private func convertMaybeScientificAmountToBigInt(_ maybeScientificAmountString: String) -> BigInt? {
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .decimal
        numberFormatter.usesGroupingSeparator = false
        let amountString = numberFormatter.number(from: maybeScientificAmountString).flatMap { numberFormatter.string(from: $0) }
        return amountString.flatMap { BigInt($0) }
    }

    private func configureFor(contract: AlphaWallet.Address, recipient: AddressOrEnsName?, amount: BigInt?, shouldConfigureBalance: Bool = true) {
        guard let tokenObject = storage.token(forContract: contract) else { return }
        let amount = amount.flatMap { EtherNumberFormatter.plain.string(from: $0, decimals: tokenObject.decimals) }
        let transactionType: TransactionType
        if let amount = amount, amount != "0" {
            transactionType = TransactionType(token: tokenObject, recipient: recipient, amount: amount)
        } else {
            switch viewModel.transactionType {
            case .nativeCryptocurrency(_, _, let amount):
                transactionType = TransactionType(token: tokenObject, recipient: recipient, amount: amount.flatMap { EtherNumberFormatter().string(from: $0, units: .ether) })
            case .ERC20Token(_, _, let amount):
                transactionType = TransactionType(token: tokenObject, recipient: recipient, amount: amount)
            case .ERC875Token, .ERC875TokenOrder, .ERC721Token, .ERC721ForTicketToken, .dapp, .tokenScript, .claimPaidErc875MagicLink:
                transactionType = TransactionType(token: tokenObject, recipient: recipient, amount: nil)
            }
        }

        configure(viewModel: .init(transactionType: transactionType, session: session, storage: storage), shouldConfigureBalance: shouldConfigureBalance)
    }
}
// swiftlint:enable type_body_length

extension SendViewController: AmountTextFieldDelegate {

    func shouldReturn(in textField: AmountTextField) -> Bool {
        targetAddressTextField.becomeFirstResponder()
        return false
    }

    func changeAmount(in textField: AmountTextField) {
        textField.errorState = .none
        textField.statusLabel.text = viewModel.availableLabelText
        textField.availableTextHidden = viewModel.availableTextHidden

        guard viewModel.validatedAmount(value: textField.ethCost, checkIfGreaterThanZero: false) != nil else {
            textField.errorState = .error
            return
        }
        resetAllFundsIfNeeded(ethCostRawValue: textField.ethCostRawValue)
    }

    func changeType(in textField: AmountTextField) {
        updateNavigationTitle()
    }

    //NOTE: not sure if we need to set `isAllFunds` to true if edited value quals to balance value
    private func resetAllFundsIfNeeded(ethCostRawValue: NSDecimalNumber?) {
        if let allFunds = allFundsFormattedValues, allFunds.allFundsFullValue.localizedString.nonEmpty {
            guard let value = allFunds.allFundsFullValue, ethCostRawValue != value else { return }

            isAllFunds = false
        } else {
            //no op
        }
    }
}

extension SendViewController: AddressTextFieldDelegate {

    func displayError(error: Error, for textField: AddressTextField) {
        textField.errorState = .error(error.prettyError)
    }

    func openQRCodeReader(for textField: AddressTextField) {
        delegate?.openQRCode(in: self)
    }

    func didPaste(in textField: AddressTextField) {
        textField.errorState = .none

        activateAmountView()
    }

    func shouldReturn(in textField: AddressTextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }

    func didChange(to string: String, in textField: AddressTextField) {
    }
}
