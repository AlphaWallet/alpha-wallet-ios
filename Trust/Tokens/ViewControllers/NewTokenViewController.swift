// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import Eureka
import TrustKeystore
import QRCodeReaderViewController

protocol NewTokenViewControllerDelegate: class {
    func didAddToken(token: ERC20Token, in viewController: NewTokenViewController)
    func didAddAddress(address: String, in viewController: NewTokenViewController)
}

class NewTokenViewController: FormViewController {

    let viewModel = NewTokenViewModel()
    var isStormBirdToken: Bool = false

    private struct Values {
        static let contract = "contract"
        static let name = "name"
        static let symbol = "symbol"
        static let decimals = "decimals"
        static let balance = "balance"
    }

    weak var delegate: NewTokenViewControllerDelegate?

    private var contractRow: TextFloatLabelRow? {
        return form.rowBy(tag: Values.contract) as? TextFloatLabelRow
    }
    private var nameRow: TextFloatLabelRow? {
        return form.rowBy(tag: Values.name) as? TextFloatLabelRow
    }
    private var symbolRow: TextFloatLabelRow? {
        return form.rowBy(tag: Values.symbol) as? TextFloatLabelRow
    }
    private var decimalsRow: TextFloatLabelRow? {
        return form.rowBy(tag: Values.decimals) as? TextFloatLabelRow
    }
    private var balanceRow: TextFloatLabelRow? {
        return form.rowBy(tag: Values.balance) as? TextFloatLabelRow
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        title = viewModel.title

        let recipientRightView = FieldAppereance.addressFieldRightView(
            pasteAction: { [unowned self] in self.pasteAction() },
            qrAction: { [unowned self] in self.openReader() }
        )

        form = Section()

            +++ Section()

            <<< AppFormAppearance.textFieldFloat(tag: Values.contract) {
                $0.add(rule: EthereumAddressRule())
                $0.validationOptions = .validatesOnDemand
                $0.title = NSLocalizedString("Contract Address", value: "Contract Address", comment: "")
            }.cellUpdate { cell, _ in
                cell.textField.textAlignment = .left
                cell.textField.rightView = recipientRightView
                cell.textField.rightViewMode = .always
            }

            <<< AppFormAppearance.textFieldFloat(tag: Values.name) {
                $0.add(rule: RuleRequired())
                $0.validationOptions = .validatesOnDemand
                $0.title = NSLocalizedString("Name", value: "Name", comment: "")
            }

            <<< AppFormAppearance.textFieldFloat(tag: Values.symbol) {
                $0.add(rule: RuleRequired())
                $0.validationOptions = .validatesOnDemand
                $0.title = NSLocalizedString("Symbol", value: "Symbol", comment: "")
            }

            <<< AppFormAppearance.textFieldFloat(tag: Values.decimals) {
                $0.add(rule: RuleClosure<String> { rowValue in
                    return (rowValue == nil || rowValue!.isEmpty) && !self.isStormBirdToken ? ValidationError(msg: "Field required!") : nil
                })
                $0.validationOptions = .validatesOnDemand
                $0.title = NSLocalizedString("Decimals", value: "Decimals", comment: "")
                $0.cell.textField.keyboardType = .decimalPad
            }

            <<< AppFormAppearance.textFieldFloat(tag: Values.balance) {
                $0.add(rule: RuleClosure<String> { rowValue in
                    return (rowValue == nil || rowValue!.isEmpty) && self.isStormBirdToken ? ValidationError(msg: "Field required!") : nil
                })
                $0.validationOptions = .validatesOnDemand
                $0.title = NSLocalizedString("Balance", value: "Balance", comment: "")
                $0.hidden = true
                $0.cell.textField.keyboardType = .numbersAndPunctuation
            }

        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(addToken))
    }

    public func updateSymbolValue(_ symbol: String) {
        symbolRow?.value = symbol
        symbolRow?.reload()
    }

    public func updateNameValue(_ name: String) {
        nameRow?.value = name
        nameRow?.reload()
    }

    public func updateDecimalsValue(_ decimals: UInt8) {
        decimalsRow?.value = String(decimals)
        decimalsRow?.reload()
    }

    public func updateBalanceValue(_ balance: [UInt16]) {
        balanceRow?.value = (balance.map { String($0) }).joined(separator: ",")
        balanceRow?.reload()
    }

    public func updateFormForStormBirdToken(_ isStormBirdToken: Bool) {
        self.isStormBirdToken = isStormBirdToken
        if isStormBirdToken {
            decimalsRow?.hidden = true
            balanceRow?.hidden = false
        } else {
            decimalsRow?.hidden = false
            balanceRow?.hidden = true
        }
        decimalsRow?.evaluateHidden()
        balanceRow?.evaluateHidden()
        form.rows.forEach { row in
            row.baseCell.isUserInteractionEnabled = false
        }
    }

    @objc func addToken() {
        guard form.validate().isEmpty else {
            return
        }

        let contract = contractRow?.value ?? ""
        let name = nameRow?.value ?? ""
        let symbol = symbolRow?.value ?? ""
        let decimals = Int(decimalsRow?.value ?? "") ?? 0
        let isStormBird = self.isStormBirdToken
        let balance: [Int16] = getBalanceFromUI()

        guard let address = Address(string: contract) else {
            return displayError(error: Errors.invalidAddress)
        }

        let erc20Token = ERC20Token(
            contract: address,
            name: name,
            symbol: symbol,
            decimals: decimals,
            isStormBird: isStormBird,
            balance: balance
        )

        delegate?.didAddToken(token: erc20Token, in: self)
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

        updateContractValue(value: value)
    }

    private func updateContractValue(value: String) {
        contractRow?.value = value
        contractRow?.reload()

        delegate?.didAddAddress(address: value, in: self)
    }

    private func getBalanceFromUI() -> [Int16] {
        if let balance = balanceRow?.value {
            return balance.split(separator: ",").map({ Int16($0)! })
        }
        return []
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
