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

class SendViewController: UIViewController {
    private let recipientHeader = SendViewSectionHeader()
    private let amountHeader = SendViewSectionHeader()
    private let buttonsBar = ButtonsBar(configuration: .green(buttons: 1))
    private var viewModel: SendViewModel
    private let session: WalletSession
    private let ethPrice: Subscribable<Double>
    private var currentSubscribableKeyForNativeCryptoCurrencyBalance: Subscribable<BalanceBaseViewModel>.SubscribableKey?
    private var currentSubscribableKeyForNativeCryptoCurrencyPrice: Subscribable<Double>.SubscribableKey?
    //We use weak link to make sure that token alert will be deallocated by close button tapping.
    //We storing link to make sure that only one alert is displaying on the screen.
    private weak var invalidTokenAlert: UIViewController?
    lazy var targetAddressTextField: AddressTextField = {
        let targetAddressTextField = AddressTextField()
        targetAddressTextField.translatesAutoresizingMaskIntoConstraints = false
        targetAddressTextField.delegate = self
        targetAddressTextField.returnKeyType = .done
        targetAddressTextField.pasteButton.contentHorizontalAlignment = .right

        return targetAddressTextField
    }()

    lazy var amountTextField: AmountTextField = {
        let amountTextField = AmountTextField(tokenObject: transactionType.tokenObject)
        amountTextField.translatesAutoresizingMaskIntoConstraints = false
        amountTextField.delegate = self
        amountTextField.accessoryButtonTitle = .next
        amountTextField.errorState = .none
        amountTextField.isAlternativeAmountEnabled = false
        amountTextField.allFundsAvailable = Features.isSendAllFundsFungibleEnabled

        return amountTextField
    }()
    weak var delegate: SendViewControllerDelegate?

    var transactionType: TransactionType {
        return viewModel.transactionType
    }

    private let storage: TokensDataStore
    @objc private (set) dynamic var isAllFunds: Bool = false
    private var observation: NSKeyValueObservation!

    private lazy var containerView: ScrollableStackView = {
        let view = ScrollableStackView()
        return view
    }()

    init(
            session: WalletSession,
            storage: TokensDataStore,
            transactionType: TransactionType,
            cryptoPrice: Subscribable<Double>
    ) {
        self.session = session
        self.storage = storage
        self.ethPrice = cryptoPrice
        self.viewModel = .init(transactionType: transactionType, session: session, storage: storage)

        super.init(nibName: nil, bundle: nil)

        configureBalanceViewModel()

        containerView.stackView.addArrangedSubviews([
            amountHeader,
            amountTextField.defaultLayout(edgeInsets: .init(top: 16, left: 16, bottom: 0, right: 16)),
            recipientHeader,
            targetAddressTextField.defaultLayout(edgeInsets: .init(top: 0, left: 16, bottom: 0, right: 16))
        ])

        let footerBar = ButtonsBarBackgroundView(buttonsBar: buttonsBar, separatorHeight: 0)
        view.addSubview(footerBar)
        view.addSubview(containerView)

        NSLayoutConstraint.activate([
            containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            containerView.topAnchor.constraint(equalTo: view.topAnchor),
            containerView.bottomAnchor.constraint(equalTo: footerBar.topAnchor),

            footerBar.anchorsConstraint(to: view),
        ])

        // NOTE: not sure do we need to call refresh balance here
        //session.balanceCoordinator.refresh()

        observation = observe(\.isAllFunds, options: [.initial, .new]) { [weak self] _, _ in
            guard let strongSelf = self else { return }

            strongSelf.amountTextField.isAllFunds = strongSelf.isAllFunds
        }
    }

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

        amountHeader.configure(viewModel: viewModel.amountViewModel)
        recipientHeader.configure(viewModel: viewModel.recipientViewModel)

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
        case .erc20Token(_, let recipient, let amount):
            currentSubscribableKeyForNativeCryptoCurrencyPrice.flatMap { ethPrice.unsubscribe($0) }
            amountTextField.cryptoToDollarRate = nil

            if let recipient = recipient {
                targetAddressTextField.value = recipient.stringValue
            }
            if let amount = amount {
                amountTextField.ethCost = amount
            }
        case .erc875Token, .erc875TokenOrder, .erc721Token, .erc721ForTicketToken, .erc1155Token, .dapp, .tokenScript, .claimPaidErc875MagicLink:
            currentSubscribableKeyForNativeCryptoCurrencyPrice.flatMap { ethPrice.unsubscribe($0) }
            amountTextField.cryptoToDollarRate = nil
        }

        buttonsBar.configure()
        let nextButton = buttonsBar.buttons[0]
        nextButton.setTitle(R.string.localizable.send(), for: .normal)
        nextButton.addTarget(self, action: #selector(send), for: .touchUpInside)

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
        case .erc20Token:
            guard let ethCost = allFundsFormattedValues else { return }
            isAllFunds = true

            amountTextField.set(ethCost: ethCost.allFundsFullValue, shortEthCost: ethCost.allFundsShortValue, useFormatting: false)
        case .dapp, .erc721ForTicketToken, .erc721Token, .erc875Token, .erc1155Token, .erc875TokenOrder, .tokenScript, .claimPaidErc875MagicLink:
            break
        }
    }

    private var allFundsFormattedValues: (allFundsFullValue: NSDecimalNumber?, allFundsShortValue: String)? {
        switch transactionType {
        case .nativeCryptocurrency:
            let balance = session.balanceCoordinator.ethBalanceViewModel
            let fullValue = EtherNumberFormatter.plain.string(from: balance.value, units: .ether).droppedTrailingZeros
            let shortValue = EtherNumberFormatter.shortPlain.string(from: balance.value, units: .ether).droppedTrailingZeros

            return (fullValue.optionalDecimalValue, shortValue)
        case .erc20Token(let token, _, _):
            let fullValue = EtherNumberFormatter.plain.string(from: token.valueBigInt, decimals: token.decimals).droppedTrailingZeros
            let shortValue = EtherNumberFormatter.shortPlain.string(from: token.valueBigInt, decimals: token.decimals).droppedTrailingZeros

            return (fullValue.optionalDecimalValue, shortValue)
        case .dapp, .erc721ForTicketToken, .erc721Token, .erc875Token, .erc1155Token, .erc875TokenOrder, .tokenScript, .claimPaidErc875MagicLink:
            return nil
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
        case .erc20Token, .erc875Token, .erc875TokenOrder, .erc721Token, .erc721ForTicketToken, .erc1155Token:
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
        currentSubscribableKeyForNativeCryptoCurrencyBalance.flatMap { session.balanceCoordinator.subscribableEthBalanceViewModel.unsubscribe($0) }
        currentSubscribableKeyForNativeCryptoCurrencyPrice.flatMap { ethPrice.unsubscribe($0) }
        switch transactionType {
        case .nativeCryptocurrency(_, let recipient, let amount):
            currentSubscribableKeyForNativeCryptoCurrencyBalance = session.balanceCoordinator.subscribableEthBalanceViewModel.subscribe { [weak self] viewModel in
                guard let celf = self else { return }
                guard celf.storage.token(forContract: celf.viewModel.transactionType.contract) != nil else { return }
                celf.configureFor(contract: celf.viewModel.transactionType.contract, recipient: recipient, amount: amount, shouldConfigureBalance: false)
            }
            session.refresh(.ethBalance)
        case .erc20Token(let token, let recipient, let amount):
            let amount = amount.flatMap { EtherNumberFormatter.plain.number(from: $0, decimals: token.decimals) }
            configureFor(contract: viewModel.transactionType.contract, recipient: recipient, amount: amount, shouldConfigureBalance: false)
        case .erc875Token, .erc875TokenOrder, .erc721Token, .erc721ForTicketToken, .erc1155Token, .dapp, .tokenScript, .claimPaidErc875MagicLink:
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
                        self.storage.addCustom(token: token, shouldUpdateBalance: true)
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
            case .erc20Token(_, _, let amount):
                transactionType = TransactionType(token: tokenObject, recipient: recipient, amount: amount)
            case .erc875Token, .erc875TokenOrder, .erc721Token, .erc721ForTicketToken, .erc1155Token, .dapp, .tokenScript, .claimPaidErc875MagicLink:
                transactionType = TransactionType(token: tokenObject, recipient: recipient, amount: nil)
            }
        }

        configure(viewModel: .init(transactionType: transactionType, session: session, storage: storage), shouldConfigureBalance: shouldConfigureBalance)
    }
}

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
        //NOTE: Comment it as avtivation amount view doesn't work properly here
        //activateAmountView()
    }

    func shouldReturn(in textField: AddressTextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }

    func didChange(to string: String, in textField: AddressTextField) {
    }
}
