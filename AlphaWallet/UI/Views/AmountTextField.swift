// Copyright © 2018 Stormbird PTE. LTD.

import UIKit

protocol AmountTextFieldDelegate: class {
    func changeAmount(in textField: AmountTextField)
    func changeType(in textField: AmountTextField)
    func shouldReturn(in textField: AmountTextField) -> Bool
}

class AmountTextField: UIControl {

    enum AccessoryButtonTitle {
        case done
        case next

        fileprivate var buttonTitle: String {
            switch self {
            case .done:
                return R.string.localizable.done()
            case .next:
                return R.string.localizable.next()
            }
        }
    }

    enum ErrorState: Error {
        case error
        case none

        var textColor: UIColor {
            switch self {
            case .error:
                return DataEntry.Color.textFieldStatus!
            case .none:
                return R.color.black()!
            }
        }

        var statusLabelTextColor: UIColor {
            switch self {
            case .error:
                return DataEntry.Color.textFieldStatus!
            case .none:
                return R.color.dove()!
            }
        }

        var statusLabelFont: UIFont {
            switch self {
            case .error:
                return Fonts.semibold(size: 13)!
            case .none:
                return Fonts.regular(size: 13)!
            }
        }

        var textFieldTextColor: UIColor {
            switch self {
            case .error:
                return DataEntry.Color.textFieldStatus!
            case .none:
                return R.color.black()!
            }
        }

        var textFieldPlaceholderTextColor: UIColor {
            switch self {
            case .error:
                return DataEntry.Color.textFieldStatus!
            case .none:
                return DataEntry.Color.placeholder
            }

        }
    }

    enum Currency {
        case cryptoCurrency(String, UIImage)
        case usd(String)

        var icon: UIImage {
            switch self {
            case .cryptoCurrency(_, let image):
                return image
            case .usd:
                return R.image.usaFlag()!
            }
        }
    }

    struct Pair {
        let left: Currency
        let right: Currency

        init(left: Currency, right: Currency = .usd("USD")) {
            self.left = left
            self.right = right
        }

        func swapPair() -> Pair {
            return Pair(left: right, right: left)
        }
    }

    private lazy var textField: UITextField = {
        let textField = UITextField()
        textField.attributedPlaceholder = NSAttributedString(string: "0", attributes: [
            .font: DataEntry.Font.amountTextField!, .foregroundColor: DataEntry.Color.placeholder
        ])
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.adjustsFontSizeToFitWidth = true
        textField.delegate = self
        textField.keyboardType = .decimalPad
        textField.leftViewMode = .always
        textField.inputAccessoryView = makeToolbarWithDoneButton()
        textField.textColor = R.color.black()!
        textField.font = DataEntry.Font.amountTextField
        textField.textAlignment = .right

        return textField
    }()

    private lazy var inputAccessoryButton: UIButton = {
        let button = UIButton()
        button.setTitle(accessoryButtonTitle.buttonTitle, for: .normal)
        button.setTitleColor(R.color.black(), for: .normal)

        return button
    }()

    private var allowedCharacters: String = {
        let decimalSeparator = Locale.current.decimalSeparator ?? ""
        return "0123456789" + decimalSeparator + EtherNumberFormatter.decimalPoint
    }()

    let statusLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false

        return label
    }()

    var cryptoToDollarRate: Double? = nil {
        didSet {
            if let _ = cryptoToDollarRate {
                updateAlternatePricingDisplay()
            }
            update(selectCurrencyButton: selectCurrencyButton)
        }
    }

    var ethCost: String {
        get {
            switch currentPair.left {
            case .cryptoCurrency:
                return textField.text ?? "0"
            case .usd:
                return convertToAlternateAmount()
            }
        }
        set {
            switch currentPair.left {
            case .cryptoCurrency:
                textField.text = newValue
            case .usd:
                if let amount = Double(newValue.withDecimalSeparatorReplacedByPeriod), let cryptoToDollarRate = cryptoToDollarRate {
                    textField.text = String(amount * cryptoToDollarRate)
                } else {
                    textField.text = ""
                }
            }
            updateAlternatePricingDisplay()
        }
    }

    var dollarCost: Double? {
        switch currentPair.left {
        case .cryptoCurrency:
            return convertToAlternateAmountNumeric()
        case .usd:
            return Double(textFieldString() ?? "")
        }
    }
    var currentPair: Pair {
        didSet {
            update(selectCurrencyButton: selectCurrencyButton)
        }
    }

    var errorState: AmountTextField.ErrorState = .none {
        didSet {
            statusLabel.textColor = errorState.statusLabelTextColor
            statusLabel.font = errorState.statusLabelFont
            textField.textColor = errorState.textFieldTextColor

            textField.attributedPlaceholder = NSAttributedString(string: "0", attributes: [
                .font: DataEntry.Font.amountTextField!, .foregroundColor: errorState.textFieldPlaceholderTextColor
            ])
        }
    }

    var accessoryButtonTitle: AccessoryButtonTitle = .done {
        didSet {
            inputAccessoryButton.setTitle(accessoryButtonTitle.buttonTitle, for: .normal)
        }
    }

    let alternativeAmountLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .left
        label.numberOfLines = 0
        label.textColor = Colors.appGreenContrastBackground
        label.font = DataEntry.Font.label

        return label
    }()

    lazy var selectCurrencyButton: SelectCurrencyButton = {
        let button = SelectCurrencyButton()

        update(selectCurrencyButton: button)

        button.addTarget(self, action: #selector(fiatAction), for: .touchUpInside)

        return button
    }()

    lazy var decimalFormatter: DecimalFormatter = {
        return DecimalFormatter()
    }()

    var isAlternativeAmountEnabled: Bool {
        get {
            return !alternativeAmountLabelContainer.isHidden
        }
        set {
            //Intentionally not sure the equivalent amount for now
            alternativeAmountLabelContainer.isHidden = true //!newValue
        }
    }

    var availableTextHidden: Bool {
        get {
            return statusLabelContainer.isHidden
        }
        set {
            statusLabelContainer.isHidden = newValue
        }
    }

    lazy var statusLabelContainer: UIView = {
        return [.spacerWidth(16), statusLabel].asStackView(axis: .horizontal)
    }()

    lazy var alternativeAmountLabelContainer: UIView = {
        return [.spacerWidth(16), alternativeAmountLabel].asStackView(axis: .horizontal)
    }()

    var currencySymbol: String {
        switch currentPair.left {
        case .cryptoCurrency(let symbol, _), .usd(let symbol):
            return symbol
        }
    }

    weak var delegate: AmountTextFieldDelegate?

    init(server: RPCServer) {
        switch server {
        case .xDai:
            currentPair = Pair(left: .cryptoCurrency("xDAI", #imageLiteral(resourceName: "xDai")), right: .usd("USD"))
        case .rinkeby, .ropsten, .main, .custom, .callisto, .classic, .kovan, .sokol, .poa, .goerli, .artis_sigma1, .artis_tau1:
            currentPair = Pair(left: .cryptoCurrency("ETH", #imageLiteral(resourceName: "eth")), right: .usd("USD"))
        }

        super.init(frame: .zero)

        translatesAutoresizingMaskIntoConstraints = false

        let stackView = [selectCurrencyButton, .spacerWidth(4), textField].asStackView(axis: .horizontal)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stackView)

        errorState = .none
        computeAlternateAmount()
        NSLayoutConstraint.activate([
            stackView.anchorsConstraint(to: self),
        ])

        inputAccessoryButton.addTarget(self, action: #selector(closeKeyboard), for: .touchUpInside)
    }

    override func becomeFirstResponder() -> Bool {
        super.becomeFirstResponder()
        return textField.becomeFirstResponder()
    }

    private func update(selectCurrencyButton button: SelectCurrencyButton) {
        switch currentPair.left {
        case .cryptoCurrency(let symbol, _), .usd(let symbol):
            button.text = symbol
            button.image = currentPair.left.icon
        }
    }

    @objc func fiatAction(button: UIButton) {
        guard cryptoToDollarRate != nil else { return }

        let oldAlternateAmount = convertToAlternateAmount()
        currentPair = currentPair.swapPair()
        updateFiatButtonTitle()
        textField.text = oldAlternateAmount
        computeAlternateAmount()
        activateAmountView()
        delegate?.changeType(in: self)
    }

    private func updateFiatButtonTitle() {
        switch currentPair.left {
        case .cryptoCurrency(let symbol, _), .usd(let symbol):
            selectCurrencyButton.text = symbol
            selectCurrencyButton.image = currentPair.left.icon
        }
    }

    private func activateAmountView() {
        _ = becomeFirstResponder()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func makeToolbarWithDoneButton() -> UIToolbar {
        //Frame needed, but actual values aren't that important
        let toolbar = UIToolbar(frame: CGRect(x: 0, y: 0, width: 100, height: 40))
        toolbar.barStyle = .default

        let flexSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let button = UIBarButtonItem(customView: inputAccessoryButton)
        toolbar.items = [flexSpace, button]
        toolbar.sizeToFit()

        return toolbar
    }

    @objc func closeKeyboard() {
        guard let delegate = delegate else {
            endEditing(true)
            return
        }

        if delegate.shouldReturn(in: self) {
            endEditing(true)
        }
    }

    private func amountChanged(in range: NSRange, to string: String) -> Bool {
        guard let input = textField.text else {
            return true
        }
        //In this step we validate only allowed characters it is because of the iPad keyboard.
        let characterSet = NSCharacterSet(charactersIn: allowedCharacters).inverted
        let separatedChars = string.components(separatedBy: characterSet)
        let filteredNumbersAndSeparator = separatedChars.joined(separator: "")
        if string != filteredNumbersAndSeparator {
            return false
        }
        //This is required to prevent user from input of numbers like 1.000.25 or 1,000,25.
        if string == "," || string == "." || string == "'" {
            return !input.contains(string)
        }
        return true
    }

    private func computeAlternateAmount() {
        let amount = convertToAlternateAmount()
        if amount.isEmpty {
            let atLeastOneWhiteSpaceToKeepTextFieldHeight = " "
            alternativeAmountLabel.text = atLeastOneWhiteSpaceToKeepTextFieldHeight
        } else {
            switch currentPair.left {
            case .cryptoCurrency:
                alternativeAmountLabel.text = "~ \(amount) USD"
            case .usd:
                switch currentPair.right {
                case .cryptoCurrency(let symbol, _):
                    alternativeAmountLabel.text = "~ \(amount) " + symbol
                case .usd:
                    break
                }
            }
        }
    }

    private func convertToAlternateAmount() -> String {
        if let cryptoToDollarRate = cryptoToDollarRate, let string = textFieldString(), let amount = Double(string) {
            switch currentPair.left {
            case .cryptoCurrency:
                return StringFormatter().currency(with: amount * cryptoToDollarRate, and: "USD")
            case .usd:
                return (amount / cryptoToDollarRate).toString(decimal: 18)
            }
        } else {
            return ""
        }
    }

    private func convertToAlternateAmountNumeric() -> Double? {
        if let cryptoToDollarRate = cryptoToDollarRate, let string = textFieldString(), let amount = Double(string) {
            switch currentPair.left {
            case .cryptoCurrency:
                return amount * cryptoToDollarRate
            case .usd:
                return amount / cryptoToDollarRate
            }
        } else {
            return nil
        }
    }

    private func updateAlternatePricingDisplay() {
        computeAlternateAmount()
        delegate?.changeAmount(in: self)
    }

    private func textFieldString() -> String? {
        textField.text?.withDecimalSeparatorReplacedByPeriod
    }
}

extension AmountTextField: UITextFieldDelegate {

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        guard let delegate = delegate else { return true }
        return delegate.shouldReturn(in: self)
    }

    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        let allowChange = amountChanged(in: range, to: string)
        if allowChange {
            //We have to allow the text field the chance to update, so we have to use asyncAfter..
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                guard let strongSelf = self else { return }
                strongSelf.updateAlternatePricingDisplay()
            }

        }
        return allowChange
    }
}

extension Double {
    func toString(decimal: Int) -> String {
        let value = decimal < 0 ? 0 : decimal
        var string = String(format: "%.\(value)f", self)

        while string.last == "0" || string.last == "." {
            if string.last == "." { string = String(string.dropLast()); break }
            string = String(string.dropLast())
        }
        return string
    }
}

fileprivate extension String {
    var withDecimalSeparatorReplacedByPeriod: String {
        guard let decimalSeparator = Locale.current.decimalSeparator else { return self }
        let period = "."
        if decimalSeparator == period {
            return self
        } else {
            return replacingOccurrences(of: decimalSeparator, with: period)
        }
    }
}
