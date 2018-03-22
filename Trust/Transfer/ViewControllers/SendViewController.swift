// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import UIKit
import Eureka
import JSONRPCKit
import APIKit
import QRCodeReaderViewController
import BigInt
import TrustKeystore

protocol SendViewControllerDelegate: class {
    func didPressConfirm(
            transaction: UnconfirmedTransaction,
            transferType: TransferType,
            in viewController: SendViewController
    )
}

class SendViewController: FormViewController {
    private lazy var viewModel: SendViewModel = {
        return SendViewModel(transferType: self.transferType,
                             config: Config(),
                             ticketHolders: self.ticketHolders)
    }()
    weak var delegate: SendViewControllerDelegate?

    struct Values {
        static let address = "address"
        static let amount = "amount"
        static let existingTicketIds = "existingTicketIds"
        static let ticketIdsToSend = "ticketIdsToSend"
    }

    struct Pair {
        let left: String
        let right: String

        func swapPair() -> Pair {
            return Pair(left: right, right: left)
        }
    }

    var pairValue = 0.0
    let session: WalletSession
    let account: Account
    let transferType: TransferType
    let storage: TokensDataStore
    let ticketHolders: [TicketHolder]!

    var addressRow: TextFloatLabelRow? {
        return form.rowBy(tag: Values.address) as? TextFloatLabelRow
    }
    var amountRow: TextFloatLabelRow? {
        return form.rowBy(tag: Values.amount) as? TextFloatLabelRow
    }
    var ticketIdsRow: TextFloatLabelRow? {
        return form.rowBy(tag: Values.ticketIdsToSend) as? TextFloatLabelRow
    }
    private var allowedCharacters: String = {
        let decimalSeparator = Locale.current.decimalSeparator ?? "."
        return "0123456789" + decimalSeparator
    }()
    private var gasPrice: BigInt?
    private var data = Data()
    lazy var currentPair: Pair = {
        return Pair(left: viewModel.symbol, right: session.config.currency.rawValue)
    }()
    lazy var decimalFormatter: DecimalFormatter = {
        return DecimalFormatter()
    }()
    lazy var stringFormatter: StringFormatter = {
        return StringFormatter()
    }()

    init(
            session: WalletSession,
            storage: TokensDataStore,
            account: Account,
            transferType: TransferType = .ether(destination: .none),
            ticketHolders: [TicketHolder] = []
    ) {
        self.session = session
        self.account = account
        self.transferType = transferType
        self.storage = storage
        self.ticketHolders = ticketHolders

        super.init(nibName: nil, bundle: nil)

        storage.updatePrices()
        getGasPrice()

        if viewModel.isStormBird {
            title = viewModel.title
        } else {
            navigationItem.titleView = BalanceTitleView.make(from: self.session, transferType)
        }

        view.backgroundColor = viewModel.backgroundColor

        let recipientRightView = FieldAppereance.addressFieldRightView(
                pasteAction: { [unowned self] in self.pasteAction() },
                qrAction: { [unowned self] in self.openReader() }
        )

        let maxButton = Button(size: .normal, style: .borderless)
        maxButton.translatesAutoresizingMaskIntoConstraints = false
        maxButton.setTitle(NSLocalizedString("send.max.button.title", value: "Max", comment: ""), for: .normal)
        maxButton.addTarget(self, action: #selector(useMaxAmount), for: .touchUpInside)

        let fiatButton = Button(size: .normal, style: .borderless)
        fiatButton.translatesAutoresizingMaskIntoConstraints = false
        fiatButton.setTitle(currentPair.right, for: .normal)
        fiatButton.addTarget(self, action: #selector(fiatAction), for: .touchUpInside)
        fiatButton.isHidden = isFiatViewHidden()

        let amountRightView = UIStackView(arrangedSubviews: [
            fiatButton,
        ])

        amountRightView.translatesAutoresizingMaskIntoConstraints = false
        amountRightView.distribution = .equalSpacing
        amountRightView.spacing = 1
        amountRightView.axis = .horizontal

        if viewModel.isStormBird {
            form += [Section(viewModel.formHeaderTitle)
                <<< TextAreaRow(Values.existingTicketIds) {
                    $0.textAreaHeight = .dynamic(initialTextViewHeight: 44)
                    $0.value = viewModel.ticketNumbers
                }.cellUpdate { cell, _ in
                    cell.isUserInteractionEnabled = false
                },
            ]
        }

        form += [Section(footer: formFooterText())
            <<< AppFormAppearance.textFieldFloat(tag: Values.address) {
            $0.add(rule: EthereumAddressRule())
            $0.validationOptions = .validatesOnDemand
            }.cellUpdate { cell, _ in
                cell.textField.textAlignment = .left
                cell.textField.placeholder = NSLocalizedString("send.recipientAddress.textField.placeholder", value: "Recipient Address", comment: "")
                cell.textField.rightView = recipientRightView
                cell.textField.rightViewMode = .always
                cell.textField.accessibilityIdentifier = "amount-field"
            }
            <<< AppFormAppearance.textFieldFloat(tag: Values.amount) {
                $0.add(rule: RuleClosure<String> { [weak self] rowValue in
                    return !(self?.viewModel.isStormBird)! && (rowValue == nil || rowValue!.isEmpty) ? ValidationError(msg: "Field required!") : nil
                })
                $0.validationOptions = .validatesOnDemand
                $0.hidden = Condition(booleanLiteral: self.viewModel.isStormBird)
            }.cellUpdate { [weak self] cell, _ in
                    cell.textField.isCopyPasteDisabled = true
                    cell.textField.textAlignment = .left
                    cell.textField.delegate = self
                    cell.textField.placeholder = "\(self?.currentPair.left ?? "") " + NSLocalizedString("send.amount.textField.placeholder", value: "Amount", comment: "")
                    cell.textField.keyboardType = .decimalPad
                    cell.textField.rightView = amountRightView
                    cell.textField.rightViewMode = .always
            }
            <<< AppFormAppearance.textFieldFloat(tag: Values.ticketIdsToSend) {
                $0.add(rule: RuleClosure<String> { [weak self] rowValue in
                    if (self?.viewModel.isStormBird)! {
                        if !(self?.ticketIdsValidated())! {
                            return ValidationError(msg: "Please enter valid ticket IDs!")
                        }
                    }
                    return nil
                })
                $0.validationOptions = .validatesOnDemand
                $0.hidden = Condition(booleanLiteral: !self.viewModel.isStormBird)
            }.cellUpdate { cell, _ in
                    cell.textField.isCopyPasteDisabled = true
                    cell.textField.textAlignment = .left
                    cell.textField.placeholder =  NSLocalizedString("send.amount.textField.ticketids", value: "Enter Ticket IDs", comment: "")
                    cell.textField.keyboardType = .numbersAndPunctuation
            },
        ]

    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.applyTintAdjustment()
    }

    func getGasPrice() {
        let request = EtherServiceRequest(batch: BatchFactory().create(GasPriceRequest()))
        Session.send(request) { [weak self] result in
            switch result {
            case .success(let balance):
                self?.gasPrice = BigInt(balance.drop0x, radix: 16)
            case .failure: break
            }
        }
    }

    func clear() {
        let fields = [addressRow, amountRow, ticketIdsRow]
        for field in fields {
            field?.value = ""
            field?.reload()
        }
    }

    @objc func send() {
        let errors = form.validate()
        guard errors.isEmpty else {
            return
        }
        let addressString = addressRow?.value?.trimmed ?? ""
        var amountString = ""
        if self.currentPair.left == viewModel.symbol {
            amountString = amountRow?.value?.trimmed ?? ""
        } else {
            guard let formatedValue = decimalFormatter.string(from: NSNumber(value: self.pairValue)) else {
                return displayError(error: SendInputErrors.wrongInput)
            }
            amountString = formatedValue
        }
        guard let address = Address(string: addressString) else {
            return displayError(error: Errors.invalidAddress)
        }
        let parsedValue: BigInt? = {
            switch transferType {
            case .ether:
                return EtherNumberFormatter.full.number(from: amountString, units: .ether)
            case .token(let token):
                return EtherNumberFormatter.full.number(from: amountString, decimals: token.decimals)
            case .stormBird(let token):
                return EtherNumberFormatter.full.number(from: amountString, decimals: token.decimals)
            case .stormBirdOrder(let token):
                return EtherNumberFormatter.full.number(from: amountString, decimals: token.decimals)
            }
        }()
        guard let value = parsedValue else {
            return displayError(error: SendInputErrors.wrongInput)
        }

        let transaction = UnconfirmedTransaction(
                transferType: transferType,
                value: value,
                to: address,
                data: data,
                gasLimit: .none,
                gasPrice: gasPrice,
                nonce: .none,
                v: .none,
                r: .none,
                s: .none,
                expiry: .none,
                indices: viewModel.isStormBird ? getIndiciesFromUI() : .none
        )
        self.delegate?.didPressConfirm(transaction: transaction, transferType: transferType, in: self)
    }

    @objc func openReader() {
        let controller = QRCodeReaderViewController()
        controller.delegate = self
        present(controller, animated: true, completion: nil)
    }

    @objc func pasteAction() {
        guard let value = UIPasteboard.general.string?.trimmed else {
            return displayError(error: SendInputErrors.emptyClipBoard)
        }

        guard CryptoAddressValidator.isValidAddress(value) else {
            return displayError(error: Errors.invalidAddress)
        }
        addressRow?.value = "0x99f05a668119d8938d79f85add73c9ab8ff719b1"
        addressRow?.reload()
        activateAmountView()
    }

    @objc func useMaxAmount() {
        guard let value = session.balance?.amountFull else {
            return
        }
        amountRow?.value = value
        amountRow?.reload()
    }

    @objc func fiatAction(sender: UIButton) {
        let swappedPair = currentPair.swapPair()
        //New pair for future calculation we should swap pair each time we press fiat button.
        self.currentPair = swappedPair
        //Update button title.
        sender.setTitle(currentPair.right, for: .normal)
        //Reset amountRow value.
        amountRow?.value = nil
        amountRow?.reload()
        //Reset pair value.
        pairValue = 0.0
        //Update section.
        updatePriceSection()
        //Set focuse on pair change.
        activateAmountView()
    }

    func activateAmountView() {
        amountRow?.cell.textField.becomeFirstResponder()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func updatePriceSection() {
        //Update section only if fiat view is visible.
        guard !isFiatViewHidden() else {
            return
        }
        //We use this section update to prevent update of the all section including cells.
        UIView.setAnimationsEnabled(false)
        tableView.beginUpdates()
        if let containerView = tableView.footerView(forSection: 1) {
            containerView.textLabel!.text = valueOfPairRepresantetion()
            containerView.sizeToFit()
        }
        tableView.endUpdates()
        UIView.setAnimationsEnabled(true)
    }

    private func updatePairPrice(with amount: Double) {
        guard let rates = storage.tickers, let currentTokenInfo = rates[viewModel.destinationAddress.description], let price = Double(currentTokenInfo.price) else {
            return
        }
        if self.currentPair.left == viewModel.symbol {
            pairValue = amount * price
        } else {
            pairValue = amount / price
        }
        self.updatePriceSection()
    }

    private func isFiatViewHidden() -> Bool {
        guard let currentTokenInfo = storage.tickers?[viewModel.destinationAddress.description], let price = Double(currentTokenInfo.price), price > 0 else {
            return true
        }
        return false
    }

    private func formFooterText() -> String {
        return isFiatViewHidden() ? "" : valueOfPairRepresantetion()
    }

    private func getTicket(for id: UInt16) -> Ticket? {
        let tickets = ticketHolders.flatMap { $0.tickets }
        let filteredTickets = tickets.filter { $0.id == id }
        return filteredTickets.first
    }

    private func isTicketExisting(for id: UInt16) -> Bool {
        return getTicket(for: id) != nil
    }

    private func getTicketIds() -> [String] {
        return (ticketIdsRow?.value?.components(separatedBy: ","))!
    }

    private func ticketIdsValidated() -> Bool {
        let rowValue = ticketIdsRow?.value
        if rowValue == nil || rowValue!.isEmpty {
            return false
        }
        let ticketIds = getTicketIds()
        for id in ticketIds {
            guard id.isNumeric() else {
                return false
            }
            guard let intId = UInt16(id) else {
                return false
            }
            guard isTicketExisting(for: intId) else {
                return false
            }
        }
        return true
    }

    private func getIndiciesFromUI() -> [UInt16] {
        let ticketIds = getTicketIds()
        return ticketIds.map { (getTicket(for: UInt16($0)!)?.index)! }
    }
}

extension SendViewController: QRCodeReaderDelegate {
    func readerDidCancel(_ reader: QRCodeReaderViewController!) {
        reader.stopScanning()
        reader.dismiss(animated: true, completion: nil)
    }

    func reader(_ reader: QRCodeReaderViewController!, didScanResult result: String!) {
        reader.stopScanning()
        reader.dismiss(animated: true) { [weak self] in
            self?.activateAmountView()
        }

        guard let result = QRURLParser.from(string: result) else {
            return
        }
        addressRow?.value = result.address
        addressRow?.reload()

        if let dataString = result.params["data"] {
            data = Data(hex: dataString.drop0x)
        } else {
            data = Data()
        }

        if let value = result.params["amount"] {
            amountRow?.value = EtherNumberFormatter.full.string(from: BigInt(value) ?? BigInt(), units: .ether)
        } else {
            amountRow?.value = ""
        }
        amountRow?.reload()
        pairValue = 0.0
        updatePriceSection()
    }

    private func valueOfPairRepresantetion() -> String {
        var formattedString = ""
        if self.currentPair.left == viewModel.symbol {
            formattedString = StringFormatter().currency(with: self.pairValue, and: self.session.config.currency.rawValue)
        } else {
            formattedString = stringFormatter.formatter(for: self.pairValue)
        }
        return "~ \(formattedString) " + "\(currentPair.right)"
    }
}

extension SendViewController: UITextFieldDelegate {
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        guard let input = textField.text else {
            return true
        }
        //In this step we validate only allowed characters it is because of the iPad keyboard.
        let characterSet = NSCharacterSet(charactersIn: self.allowedCharacters).inverted
        let separatedChars = string.components(separatedBy: characterSet)
        let filteredNumbersAndSeparator = separatedChars.joined(separator: "")
        if string != filteredNumbersAndSeparator {
            return false
        }
        //This is required to prevent user from input of numbers like 1.000.25 or 1,000,25.
        if string == "," || string == "." || string == "'" {
            return !input.contains(string)
        }
        let text = (input as NSString).replacingCharacters(in: range, with: string)
        guard let amount = decimalFormatter.number(from: text) else {
            //Should be done in another way.
            pairValue = 0.0
            updatePriceSection()
            return true
        }
        self.updatePairPrice(with: amount.doubleValue)
        return true
    }
}
