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
    func didPressConfirm(
            transaction: UnconfirmedTransaction,
            transferType: TransferType,
            in viewController: SendViewController
    )
    func lookup(contract: AlphaWallet.Address, in viewController: SendViewController, completion: @escaping (ContractData) -> Void)
    func openQRCode(in controller: SendViewController)
}

class SendViewController: UIViewController, CanScanQRCode {
    private let roundedBackground = RoundedBackground()
    private let scrollView = UIScrollView()
    private let recipientHeader = SendViewSectionHeader()
    private let amountHeader = SendViewSectionHeader()
    private let recepientAddressLabel = UILabel()
    private let amountLabel = UILabel()
    private let buttonsBar = ButtonsBar(numberOfButtons: 1)
    private var viewModel: SendViewModel
    private var balanceViewModel: BalanceBaseViewModel?
    private let session: WalletSession
    private let account: EthereumAccount
    private let ethPrice: Subscribable<Double>
    private let assetDefinitionStore: AssetDefinitionStore
    private var gasPrice: BigInt?
    private var data = Data()
    private lazy var decimalFormatter: DecimalFormatter = {
        return DecimalFormatter()
    }()
    private var currentSubscribableKeyForNativeCryptoCurrencyBalance: Subscribable<BalanceBaseViewModel>.SubscribableKey?
    private var currentSubscribableKeyForNativeCryptoCurrencyPrice: Subscribable<Double>.SubscribableKey?
    private let amountViewModel = SendViewSectionHeaderViewModel(
        text: R.string.localizable.sendAmount().uppercased(),
        showTopSeparatorLine: false
    )
    private let recipientViewModel = SendViewSectionHeaderViewModel(
        text: R.string.localizable.sendRecipient().uppercased()
    )
    let targetAddressTextField = AddressTextField()
    lazy var amountTextField = AmountTextField(server: session.server)
    weak var delegate: SendViewControllerDelegate?
    var transferType: TransferType {
        return viewModel.transferType
    }
    let storage: TokensDataStore

    init(
            session: WalletSession,
            storage: TokensDataStore,
            account: EthereumAccount,
            transferType: TransferType,
            cryptoPrice: Subscribable<Double>,
            assetDefinitionStore: AssetDefinitionStore
    ) {
        self.session = session
        self.account = account
        self.storage = storage
        self.ethPrice = cryptoPrice
        self.assetDefinitionStore = assetDefinitionStore
        self.viewModel = .init(transferType: transferType, session: session, storage: storage)

        super.init(nibName: nil, bundle: nil)

        configureBalanceViewModel()

        roundedBackground.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(roundedBackground)

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        roundedBackground.addSubview(scrollView)

        targetAddressTextField.translatesAutoresizingMaskIntoConstraints = false
        targetAddressTextField.delegate = self
        targetAddressTextField.returnKeyType = .next

        amountTextField.translatesAutoresizingMaskIntoConstraints = false
        amountTextField.delegate = self

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
            [.spacerWidth(16), amountTextField.alternativeAmountLabel].asStackView(axis: .horizontal),
            .spacer(height: ScreenChecker().isNarrowScreen ? 7: 14),
            recipientHeader,
            .spacer(height: ScreenChecker().isNarrowScreen ? 7: 16),
            [.spacerWidth(16), recepientAddressLabel].asStackView(axis: .horizontal),
            .spacer(height: ScreenChecker().isNarrowScreen ? 2 : 4),
            targetAddressTextField,
            .spacer(height: 4), [
                [.spacerWidth(16), targetAddressTextField.ensAddressLabel, targetAddressTextField.statusLabel].asStackView(axis: .horizontal, alignment: .leading),
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

            recepientAddressLabel.heightAnchor.constraint(equalToConstant: 22),
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
            footerBar.topAnchor.constraint(equalTo: view.layoutGuide.bottomAnchor, constant: -ButtonsBar.buttonsHeight - ButtonsBar.marginAtBottomScreen),
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
        getGasPrice()
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

        amountHeader.configure(viewModel: amountViewModel)
        recipientHeader.configure(viewModel: recipientViewModel)

        recepientAddressLabel.text = viewModel.recipientsAddress
        recepientAddressLabel.font = viewModel.recepientLabelFont
        recepientAddressLabel.textColor = viewModel.recepientLabelTextColor

        amountLabel.font = viewModel.textFieldsLabelFont
        amountLabel.textColor = viewModel.textFieldsLabelTextColor

        switch transferType {
        case .nativeCryptocurrency(_, let recipient, let amount):
            amountTextField.selectCurrencyButton.isHidden = false
            if let recipient = recipient {
                targetAddressTextField.value = recipient.stringValue
                targetAddressTextField.queueEnsResolution(ofValue: recipient.stringValue)
            }
            if let amount = amount {
                amountTextField.ethCost = EtherNumberFormatter.full.string(from: amount, units: .ether)
            }
            currentSubscribableKeyForNativeCryptoCurrencyPrice = ethPrice.subscribe { [weak self] value in
                if let value = value {
                    self?.amountTextField.cryptoToDollarRate = value
                }
            }
            amountTextField.isAlternativeAmountEnabled = true
        case .ERC20Token(_, let recipient, let amount):
            amountTextField.selectCurrencyButton.isHidden = true
            if let recipient = recipient {
                targetAddressTextField.value = recipient.stringValue
                targetAddressTextField.queueEnsResolution(ofValue: recipient.stringValue)
            }
            if let amount = amount {
                amountTextField.ethCost = amount
            }
            amountTextField.isAlternativeAmountEnabled = false
            amountTextField.isFiatButtonHidden = true
        case .ERC875Token, .ERC875TokenOrder, .ERC721Token, .ERC721ForTicketToken, .dapp:
            amountTextField.selectCurrencyButton.isHidden = true
            amountTextField.isAlternativeAmountEnabled = false
            amountTextField.isFiatButtonHidden = true
        }

        buttonsBar.configure()
        let nextButton = buttonsBar.buttons[0]
        nextButton.setTitle(R.string.localizable.send(), for: .normal)
        nextButton.addTarget(self, action: #selector(send), for: .touchUpInside)

        updateNavigationTitle()
    }

    private func updateNavigationTitle() {
        title = "\(R.string.localizable.send()) \(transferType.symbol)"
    }

    func getGasPrice() {
        let request = EtherServiceRequest(server: session.server, batch: BatchFactory().create(GasPriceRequest()))
        Session.send(request) { [weak self] result in
            switch result {
            case .success(let balance):
                self?.gasPrice = BigInt(balance.drop0x, radix: 16)
            case .failure: break
            }
        }
    }

    @objc func send() {
        let input = targetAddressTextField.value.trimmed
        targetAddressTextField.errorState = .none

        guard let address = AlphaWallet.Address(string: input) else {
            targetAddressTextField.errorState = .error(Errors.invalidAddress.prettyError)
            return
        }

        let amountString = amountTextField.ethCost
        let parsedValue: BigInt? = {
            switch transferType {
            case .nativeCryptocurrency, .dapp:
                return EtherNumberFormatter.full.number(from: amountString, units: .ether)
            case .ERC20Token(let token, _, _):
                return EtherNumberFormatter.full.number(from: amountString, decimals: token.decimals)
            case .ERC875Token(let token):
                return EtherNumberFormatter.full.number(from: amountString, decimals: token.decimals)
            case .ERC875TokenOrder(let token):
                return EtherNumberFormatter.full.number(from: amountString, decimals: token.decimals)
            case .ERC721Token(let token):
                return EtherNumberFormatter.full.number(from: amountString, decimals: token.decimals)
            case .ERC721ForTicketToken(let token):
                return EtherNumberFormatter.full.number(from: amountString, decimals: token.decimals)
            }
        }()

        guard let value = parsedValue, value > 0 else {
            return displayError(error: SendInputErrors.wrongInput)
        }

        switch transferType {
        case .nativeCryptocurrency:
            if let balance = session.balance, balance.value < value {
                return displayError(title: R.string.localizable.aSendBalanceInsufficient(), error: Errors.invalidAmount)
            }
        case .ERC20Token(let token, _, _):
            if let tokenBalance = storage.token(forContract: token.contractAddress)?.valueBigInt, tokenBalance < value {
                return displayError(title: R.string.localizable.aSendBalanceInsufficient(), error: Errors.invalidAmount)
            }
        case .dapp, .ERC721ForTicketToken, .ERC721Token, .ERC875Token, .ERC875TokenOrder:
            break
        }

        let transaction = UnconfirmedTransaction(
                transferType: transferType,
                value: value,
                to: address,
                data: data,
                gasLimit: .none,
                tokenId: .none,
                gasPrice: gasPrice,
                nonce: .none,
                v: .none,
                r: .none,
                s: .none,
                expiry: .none,
                indices: .none,
                tokenIds: .none
        )
        delegate?.didPressConfirm(transaction: transaction, transferType: transferType, in: self)
    }

    func activateAmountView() {
        _ = amountTextField.becomeFirstResponder()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func configureBalanceViewModel() {
        currentSubscribableKeyForNativeCryptoCurrencyBalance.flatMap { session.balanceViewModel.unsubscribe($0) }
        currentSubscribableKeyForNativeCryptoCurrencyPrice.flatMap { ethPrice.unsubscribe($0) }
        switch transferType {
        case .nativeCryptocurrency(_, let recipient, let amount):
            currentSubscribableKeyForNativeCryptoCurrencyBalance = session.balanceViewModel.subscribe { [weak self] viewModel in
                guard let celf = self else { return }
                guard let tokenObject = celf.storage.token(forContract: celf.viewModel.transferType.contract) else { return }
                celf.configureFor(contract: celf.viewModel.transferType.contract, recipient: recipient, amount: amount, shouldConfigureBalance: false)
            }
            session.refresh(.ethBalance)
        case .ERC20Token(let token, let recipient, let amount):
            let amount = amount.flatMap { EtherNumberFormatter.full.number(from: $0, decimals: token.decimals) }
            configureFor(contract: viewModel.transferType.contract, recipient: recipient, amount: amount, shouldConfigureBalance: false)
        case .ERC875Token, .ERC875TokenOrder, .ERC721Token, .ERC721ForTicketToken, .dapp:
            break
        }
    }

    func didScanQRCode(_ result: String) {
        activateAmountView()

        guard let result = QRCodeValueParser.from(string: result) else { return }
        switch result {
        case .address(let recipient):
            guard let tokenObject = storage.token(forContract: viewModel.transferType.contract) else { return }
            let amountAsIntWithDecimals = EtherNumberFormatter.full.number(from: amountTextField.ethCost, decimals: tokenObject.decimals)
            configureFor(contract: transferType.contract, recipient: .address(recipient), amount: amountAsIntWithDecimals)
        case .eip681(let protocolName, let address, let functionName, let params):
            checkAndFillEIP681Details(protocolName: protocolName, address: address, functionName: functionName, params: params)
        }
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
            } else {
                self.delegate?.lookup(contract: contract, in: self) { data in
                    switch data {
                    case .name, .symbol, .balance, .decimals:
                        break
                    case .nonFungibleTokenComplete:
                        //Not expecting NFT
                        break
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
                    case .delegateTokenComplete:
                        break
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
        let amount = amount.flatMap { EtherNumberFormatter.full.string(from: $0, decimals: tokenObject.decimals) }
        let transferType: TransferType
        if let amount = amount, amount != "0" {
            transferType = TransferType(token: tokenObject, recipient: recipient, amount: amount)
        } else {
            switch viewModel.transferType {
            case .nativeCryptocurrency(_, _, let amount):
                transferType = TransferType(token: tokenObject, recipient: recipient, amount: amount.flatMap { EtherNumberFormatter().string(from: $0, units: .ether) })
            case .ERC20Token(_, _, let amount):
                transferType = TransferType(token: tokenObject, recipient: recipient, amount: amount)
            case .ERC875Token, .ERC875TokenOrder, .ERC721Token, .ERC721ForTicketToken, .dapp:
                transferType = TransferType(token: tokenObject, recipient: recipient, amount: nil)
            }
        }
        configure(viewModel: .init(transferType: transferType, session: session, storage: storage), shouldConfigureBalance: shouldConfigureBalance)
    }
}

extension SendViewController: AmountTextFieldDelegate {
    func changeAmount(in textField: AmountTextField) {
        //do nothing
    }

    func changeType(in textField: AmountTextField) {
        updateNavigationTitle()
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
        _ = textField.resignFirstResponder()
        return true
    }

    func didChange(to string: String, in textField: AddressTextField) {
    }
}
