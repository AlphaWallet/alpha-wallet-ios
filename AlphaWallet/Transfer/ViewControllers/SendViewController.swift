// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit
import JSONRPCKit
import APIKit
import PromiseKit
import BigInt
import MBProgressHUD
import Combine

protocol SendViewControllerDelegate: class, CanOpenURL {
    func didPressConfirm(transaction: UnconfirmedTransaction, in viewController: SendViewController, amount: String, shortValue: String?)
    func lookup(contract: AlphaWallet.Address, in viewController: SendViewController, completion: @escaping (ContractData) -> Void)
    func openQRCode(in controller: SendViewController)
}

class SendViewController: UIViewController {
    private let recipientHeader = SendViewSectionHeader()
    private let amountHeader = SendViewSectionHeader()
    private let buttonsBar = HorizontalButtonsBar(configuration: .primary(buttons: 1))
    private var viewModel: SendViewModel
    private let session: WalletSession
    //We use weak link to make sure that token alert will be deallocated by close button tapping.
    //We storing link to make sure that only one alert is displaying on the screen.
    private weak var invalidTokenAlert: UIViewController?
    lazy var targetAddressTextField: AddressTextField = {
        let targetAddressTextField = AddressTextField(domainResolutionService: domainResolutionService)
        targetAddressTextField.translatesAutoresizingMaskIntoConstraints = false
        targetAddressTextField.delegate = self
        targetAddressTextField.returnKeyType = .done
        targetAddressTextField.pasteButton.contentHorizontalAlignment = .right

        return targetAddressTextField
    }()

    lazy var amountTextField: AmountTextField = {
        let amountTextField = AmountTextField(tokenObject: transactionType.tokenObject, buttonType: .next)
        amountTextField.translatesAutoresizingMaskIntoConstraints = false
        amountTextField.delegate = self
        amountTextField.accessoryButtonTitle = .next
        amountTextField.errorState = .none
        amountTextField.isAlternativeAmountEnabled = false
        amountTextField.allFundsAvailable = Features.default.isAvailable(.isSendAllFundsFungibleEnabled)
        amountTextField.selectCurrencyButton.hasToken = true
        return amountTextField
    }()
    weak var delegate: SendViewControllerDelegate?

    var transactionType: TransactionType {
        return viewModel.transactionType
    }

    private let tokensDataStore: TokensDataStore
    private let domainResolutionService: DomainResolutionServiceType
    @objc private (set) dynamic var isAllFunds: Bool = false
    private var observation: NSKeyValueObservation!
    private var etherToFiatRateCancelable: AnyCancellable?
    private var etherBalanceCancelable: AnyCancellable?

    private lazy var containerView: ScrollableStackView = {
        let view = ScrollableStackView()
        return view
    }()

    init(session: WalletSession, tokensDataStore: TokensDataStore, transactionType: TransactionType, domainResolutionService: DomainResolutionServiceType) {
        self.session = session
        self.tokensDataStore = tokensDataStore
        self.domainResolutionService = domainResolutionService
        self.viewModel = .init(transactionType: transactionType, session: session, tokensDataStore: tokensDataStore)

        super.init(nibName: nil, bundle: nil)

        configureBalanceViewModel()

        containerView.stackView.addArrangedSubviews([
            amountHeader,
            .spacer(height: ScreenChecker().isNarrowScreen ? 7 : 27),
            amountTextField.defaultLayout(edgeInsets: .init(top: 0, left: 16, bottom: 0, right: 16)),
            .spacer(height: ScreenChecker().isNarrowScreen ? 7: 14),
            recipientHeader,
            .spacer(height: ScreenChecker().isNarrowScreen ? 7: 16),
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

            etherToFiatRateCancelable = session
                .tokenBalanceService
                .etherToFiatRatePublisher
                .compactMap { $0.flatMap { NSDecimalNumber(value: $0) } }
                .receive(on: RunLoop.main)
                .sink { [weak amountTextField] price in
                    amountTextField?.cryptoToDollarRate = price
                }
        case .erc20Token(_, let recipient, let amount):
            etherToFiatRateCancelable?.cancel()
            amountTextField.cryptoToDollarRate = nil

            if let recipient = recipient {
                targetAddressTextField.value = recipient.stringValue
            }
            if let amount = amount {
                amountTextField.ethCost = amount
            }
        case .erc875Token, .erc875TokenOrder, .erc721Token, .erc721ForTicketToken, .erc1155Token, .dapp, .tokenScript, .claimPaidErc875MagicLink, .prebuilt:
            etherToFiatRateCancelable?.cancel()
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
        guard let ethCost = viewModel.allFundsFormattedValues else { return }
        isAllFunds = true

        amountTextField.set(ethCost: ethCost.allFundsFullValue, shortEthCost: ethCost.allFundsShortValue, useFormatting: false)
    }

    @objc private func send() {
        let input = targetAddressTextField.value.trimmed
        targetAddressTextField.errorState = .none
        amountTextField.errorState = .none

        guard let value = viewModel.validatedAmount(value: amountTextField.ethCost, checkIfGreaterThanZero: viewModel.checkIfGreaterThanZero) else {
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
        return isAllFunds ? viewModel.allFundsFormattedValues?.allFundsShortValue : .none
    }

    func activateAmountView() {
        amountTextField.becomeFirstResponder()
    }

    required init?(coder aDecoder: NSCoder) {
        return nil
    }

    private func configureBalanceViewModel() {
        etherBalanceCancelable?.cancel()
        etherToFiatRateCancelable?.cancel()

        switch transactionType {
        case .nativeCryptocurrency(_, let recipient, let amount):
            etherBalanceCancelable = session.tokenBalanceService
                .etherBalance
                .receive(on: RunLoop.main)
                .sink { [weak self] _ in
                    guard let celf = self else { return }
                    guard celf.tokensDataStore.tokenObject(forContract: celf.viewModel.transactionType.contract, server: celf.session.server) != nil else { return }
                    celf.configureFor(contract: celf.viewModel.transactionType.contract, recipient: recipient, amount: amount, shouldConfigureBalance: false)
                }
            session.tokenBalanceService.refresh(refreshBalancePolicy: .eth)
        case .erc20Token(let token, let recipient, let amount):
            let amount = amount.flatMap { EtherNumberFormatter.plain.number(from: $0, decimals: token.decimals) }
            configureFor(contract: viewModel.transactionType.contract, recipient: recipient, amount: amount, shouldConfigureBalance: false)
        case .erc875Token, .erc875TokenOrder, .erc721Token, .erc721ForTicketToken, .erc1155Token, .dapp, .tokenScript, .claimPaidErc875MagicLink, .prebuilt:
            break
        }
    }

    func didScanQRCode(_ result: String) {
        guard let result = QRCodeValueParser.from(string: result) else { return }
        switch result {
        case .address(let recipient):
            guard let tokenObject = tokensDataStore.tokenObject(forContract: viewModel.transactionType.contract, server: session.server) else { return }
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
            let amount = self.viewModel.convertMaybeScientificAmountToBigInt(maybeScientificAmountString)
            //For user-safety and simpler implementation, we ignore the link if it is for a different chain
            if let server = optionalServer {
                guard self.session.server == server else { return }
            }

            if self.tokensDataStore.token(forContract: contract, server: self.session.server) != nil {
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
                                server: self.session.server,
                                name: name,
                                symbol: symbol,
                                decimals: Int(decimals),
                                type: .erc20,
                                balance: ["0"]
                        )
                        self.tokensDataStore.addCustom(tokens: [token], shouldUpdateBalance: true)
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

    private func configureFor(contract: AlphaWallet.Address, recipient: AddressOrEnsName?, amount: BigInt?, shouldConfigureBalance: Bool = true) {
        guard let tokenObject = tokensDataStore.tokenObject(forContract: contract, server: self.session.server) else { return }
        let amount = amount.flatMap { EtherNumberFormatter.plain.string(from: $0, decimals: tokenObject.decimals) }
        let transactionType: TransactionType
        if let amount = amount, amount != "0" {
            transactionType = TransactionType(fungibleToken: tokenObject, recipient: recipient, amount: amount)
        } else {
            switch viewModel.transactionType {
            case .nativeCryptocurrency(_, _, let amount):
                transactionType = TransactionType(fungibleToken: tokenObject, recipient: recipient, amount: amount.flatMap { EtherNumberFormatter().string(from: $0, units: .ether) })
            case .erc20Token(_, _, let amount):
                transactionType = TransactionType(fungibleToken: tokenObject, recipient: recipient, amount: amount)
            case .erc875Token, .erc875TokenOrder, .erc721Token, .erc721ForTicketToken, .erc1155Token, .dapp, .tokenScript, .claimPaidErc875MagicLink, .prebuilt:
                transactionType = TransactionType(fungibleToken: tokenObject, recipient: recipient, amount: nil)
            }
        }

        configure(viewModel: .init(transactionType: transactionType, session: session, tokensDataStore: tokensDataStore), shouldConfigureBalance: shouldConfigureBalance)
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
        if let allFunds = viewModel.allFundsFormattedValues, allFunds.allFundsFullValue.localizedString.nonEmpty {
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
