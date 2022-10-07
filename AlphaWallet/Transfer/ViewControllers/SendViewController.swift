// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit
import PromiseKit
import BigInt
import MBProgressHUD
import Combine
import AlphaWalletFoundation

protocol SendViewControllerDelegate: class, CanOpenURL {
    func didPressConfirm(transaction: UnconfirmedTransaction, in viewController: SendViewController, amount: String, shortValue: String?)
    func lookup(contract: AlphaWallet.Address, in viewController: SendViewController, completion: @escaping (ContractData) -> Void)
    func openQRCode(in viewController: SendViewController)
    func didClose(in viewController: SendViewController)
}

class SendViewController: UIViewController {
    private let recipientHeader = SendViewSectionHeader()
    private let amountHeader = SendViewSectionHeader()
    private let buttonsBar = HorizontalButtonsBar(configuration: .primary(buttons: 1))
    private var viewModel: SendViewModel
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
        let amountTextField = AmountTextField(token: transactionType.tokenObject, buttonType: .next)
        amountTextField.translatesAutoresizingMaskIntoConstraints = false
        amountTextField.delegate = self
        amountTextField.viewModel.accessoryButtonTitle = .next
        amountTextField.viewModel.errorState = .none
        amountTextField.isAlternativeAmountEnabled = false
        amountTextField.allFundsAvailable = true
        amountTextField.selectCurrencyButton.hasToken = true

        return amountTextField
    }()
    weak var delegate: SendViewControllerDelegate?

    var transactionType: TransactionType {
        return viewModel.transactionType
    }

    private let domainResolutionService: DomainResolutionServiceType
    private var cryptoToFiatRateCancelable: AnyCancellable?
    private var fungibleBalanceCancelable: AnyCancellable?

    private lazy var containerView: ScrollableStackView = {
        let view = ScrollableStackView()
        return view
    }()

    init(viewModel: SendViewModel, domainResolutionService: DomainResolutionServiceType) {
        self.domainResolutionService = domainResolutionService
        self.viewModel = viewModel

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
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        activateAmountView()

        buttonsBar.configure()
        buttonsBar.buttons[0].setTitle(R.string.localizable.send(), for: .normal)
        buttonsBar.buttons[0].addTarget(self, action: #selector(send), for: .touchUpInside)

        amountTextField.allFundsButton.addTarget(self, action: #selector(allFundsSelected), for: .touchUpInside)
        configure(viewModel: viewModel)
    }

    private func configure(viewModel: SendViewModel, shouldConfigureBalance: Bool = true) {
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

        cryptoToFiatRateCancelable?.cancel()

        switch transactionType {
        case .nativeCryptocurrency(_, let recipient, let amount):
            if let recipient = recipient {
                targetAddressTextField.value = recipient.stringValue
            }
            if let amount = amount {
                amountTextField.set(crypto: EtherNumberFormatter.plain.string(from: amount, units: .ether), useFormatting: true)
            }
            cryptoToFiatRateCancelable = viewModel.cryptoToFiatRate
                .assign(to: \.value, on: amountTextField.viewModel.cryptoToFiatRate, ownership: .weak)
        case .erc20Token(_, let recipient, let amount):
            if let recipient = recipient {
                targetAddressTextField.value = recipient.stringValue
            }
            if let amount = amount {
                amountTextField.set(crypto: amount, useFormatting: true)
            }

            cryptoToFiatRateCancelable = viewModel.cryptoToFiatRate
                .assign(to: \.value, on: amountTextField.viewModel.cryptoToFiatRate, ownership: .weak)
        case .erc875Token, .erc875TokenOrder, .erc721Token, .erc721ForTicketToken, .erc1155Token, .dapp, .tokenScript, .claimPaidErc875MagicLink, .prebuilt:
            amountTextField.viewModel.cryptoToFiatRate.value = nil
        }

        updateNavigationTitle()
    }

    private func updateNavigationTitle() {
        title = "\(R.string.localizable.send()) \(transactionType.symbol)"
    }

    @objc func allFundsSelected() {
        guard let crypto = viewModel.allFundsFormattedValues else { return }

        amountTextField.viewModel.isAllFunds = true
        amountTextField.set(crypto: crypto.allFundsFullValue.localizedString, shortCrypto: crypto.allFundsShortValue, useFormatting: false)
    }

    @objc private func send() {
        let input = targetAddressTextField.value.trimmed
        targetAddressTextField.errorState = .none
        amountTextField.viewModel.errorState = .none

        guard let value = viewModel.validatedAmount(value: amountTextField.cryptoValue, checkIfGreaterThanZero: viewModel.checkIfGreaterThanZero) else {
            amountTextField.viewModel.errorState = .error
            return
        }
        guard let recipient = AlphaWallet.Address(string: input) else {
            targetAddressTextField.errorState = .error(InputError.invalidAddress.prettyError)
            return
        }

        let transaction = UnconfirmedTransaction(transactionType: transactionType, value: value, recipient: recipient, contract: transactionType.contractForFungibleSend, data: nil)

        delegate?.didPressConfirm(transaction: transaction, in: self, amount: amountTextField.cryptoValue, shortValue: shortValueForAllFunds)
    }

    var shortValueForAllFunds: String? {
        return amountTextField.viewModel.isAllFunds ? viewModel.allFundsFormattedValues?.allFundsShortValue : .none
    }

    func activateAmountView() {
        amountTextField.becomeFirstResponder()
    }

    required init?(coder aDecoder: NSCoder) {
        return nil
    }

    private func configureBalanceViewModel() {
        fungibleBalanceCancelable?.cancel()

        switch transactionType {
        case .nativeCryptocurrency(_, let recipient, let amount):
            fungibleBalanceCancelable = viewModel.tokensService.tokenViewModelPublisher(for: transactionType.tokenObject)
                .sink { [weak self] _ in
                    guard let celf = self else { return }
                    //NOTE: Why do we need this check?
                    guard celf.viewModel.tokensService.token(for: celf.viewModel.transactionType.contract, server: celf.viewModel.session.server) != nil else { return }
                    celf.configureFor(contract: celf.viewModel.transactionType.contract, recipient: recipient, amount: amount, shouldConfigureBalance: false)
                }
            viewModel.tokensService.refreshBalance(updatePolicy: .token(token: transactionType.tokenObject))
        case .erc20Token(let token, let recipient, let amount):
            fungibleBalanceCancelable = viewModel.tokensService.tokenViewModelPublisher(for: transactionType.tokenObject)
                .sink { [weak self] _ in
                    guard let celf = self else { return }
                    guard celf.viewModel.tokensService.token(for: celf.viewModel.transactionType.contract, server: celf.viewModel.session.server) != nil else { return }
                    let amount = amount.flatMap { EtherNumberFormatter.plain.number(from: $0, decimals: token.decimals) }
                    celf.configureFor(contract: celf.viewModel.transactionType.contract, recipient: recipient, amount: amount, shouldConfigureBalance: false)
                }
            viewModel.tokensService.refreshBalance(updatePolicy: .token(token: transactionType.tokenObject))
        case .erc875Token, .erc875TokenOrder, .erc721Token, .erc721ForTicketToken, .erc1155Token, .dapp, .tokenScript, .claimPaidErc875MagicLink, .prebuilt:
            break
        }
    }

    func didScanQRCode(_ result: String) {
        guard let result = QRCodeValueParser.from(string: result) else { return }
        switch result {
        case .address(let recipient):
            guard let token = viewModel.tokensService.token(for: viewModel.transactionType.contract, server: viewModel.session.server) else { return }
            let amountAsIntWithDecimals = EtherNumberFormatter.plain.number(from: amountTextField.cryptoValue, decimals: token.decimals)
            configureFor(contract: transactionType.contract, recipient: .address(recipient), amount: amountAsIntWithDecimals)
            activateAmountView()
        case .eip681(let protocolName, let address, let functionName, let params):
            checkAndFillEIP681Details(protocolName: protocolName, address: address, functionName: functionName, params: params)
        }
    }

    private func showInvalidToken() {
        guard invalidTokenAlert == nil else { return }

        invalidTokenAlert = UIAlertController.alert(message: R.string.localizable.sendInvalidToken(), alertButtonTitles: [R.string.localizable.oK()], alertButtonStyles: [.cancel], viewController: self)
    }

    private func checkAndFillEIP681Details(protocolName: String, address: AddressOrEnsName, functionName: String?, params: [String: String]) {
        //TODO error display on returns
        Eip681Parser(protocolName: protocolName, address: address, functionName: functionName, params: params).parse().done { result in
            guard let (contract: contract, optionalServer, recipient, maybeScientificAmountString) = result.parameters else { return }
            let amount = self.viewModel.convertMaybeScientificAmountToBigInt(maybeScientificAmountString)
            //For user-safety and simpler implementation, we ignore the link if it is for a different chain
            if let server = optionalServer {
                guard self.viewModel.session.server == server else { return }
            }

            if self.viewModel.tokensService.token(for: contract, server: self.viewModel.session.server) != nil {
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
                                server: self.viewModel.session.server,
                                name: name,
                                symbol: symbol,
                                decimals: Int(decimals),
                                type: .erc20,
                                balance: .balance(["0"])
                        )
                        self.viewModel.tokensService.addCustom(tokens: [token], shouldUpdateBalance: true)
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
        guard let token = viewModel.tokensService.token(for: contract, server: viewModel.session.server) else { return }
        let amount = amount.flatMap { EtherNumberFormatter.plain.string(from: $0, decimals: token.decimals) }
        let transactionType: TransactionType
        if let amount = amount, amount != "0" {
            transactionType = TransactionType(fungibleToken: token, recipient: recipient, amount: amount)
        } else {
            switch viewModel.transactionType {
            case .nativeCryptocurrency(_, _, let amount):
                transactionType = TransactionType(fungibleToken: token, recipient: recipient, amount: amount.flatMap { EtherNumberFormatter().string(from: $0, units: .ether) })
            case .erc20Token(_, _, let amount):
                transactionType = TransactionType(fungibleToken: token, recipient: recipient, amount: amount)
            case .erc875Token, .erc875TokenOrder, .erc721Token, .erc721ForTicketToken, .erc1155Token, .dapp, .tokenScript, .claimPaidErc875MagicLink, .prebuilt:
                transactionType = TransactionType(fungibleToken: token, recipient: recipient, amount: nil)
            }
        }

        configure(viewModel: .init(transactionType: transactionType, session: viewModel.session, tokensService: viewModel.tokensService), shouldConfigureBalance: shouldConfigureBalance)
    }
}

extension SendViewController: PopNotifiable {
    func didPopViewController(animated: Bool) {
        delegate?.didClose(in: self)
    }
}

extension SendViewController: AmountTextFieldDelegate {

    func shouldReturn(in textField: AmountTextField) -> Bool {
        targetAddressTextField.becomeFirstResponder()
        return false
    }

    func changeAmount(in textField: AmountTextField) {
        textField.viewModel.errorState = .none
        textField.statusLabel.text = viewModel.availableLabelText
        textField.availableTextHidden = viewModel.availableTextHidden

        guard viewModel.validatedAmount(value: textField.cryptoValue, checkIfGreaterThanZero: false) != nil else {
            textField.viewModel.errorState = .error
            return
        }
        resetAllFundsIfNeeded(ethCostRawValue: textField.viewModel.cryptoRawValue)
    }

    func changeType(in textField: AmountTextField) {
        updateNavigationTitle()
    }

    //NOTE: not sure if we need to set `isAllFunds` to true if edited value quals to balance value
    private func resetAllFundsIfNeeded(ethCostRawValue: NSDecimalNumber?) {
        if let allFunds = viewModel.allFundsFormattedValues, allFunds.allFundsFullValue.localizedString.nonEmpty {
            guard let value = allFunds.allFundsFullValue, ethCostRawValue != value else { return }

            amountTextField.viewModel.isAllFunds = false
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
