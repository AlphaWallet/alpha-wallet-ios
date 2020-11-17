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
        case cryptoCurrency(TokenObject)
        case usd
    }

    struct Pair {
        var left: Currency
        var right: Currency

        mutating func swap() {
            let currentLeft = left

            left = right
            right = currentLeft
        }

        var symbol: String {
            switch left {
            case .cryptoCurrency(let tokenObject):
                return tokenObject.symbol
            case .usd:
                return Constants.Currency.usd
            }
        }

        var icon: Subscribable<TokenImage> {
            switch left {
            case .cryptoCurrency(let tokenObject):
                return tokenObject.icon
            case .usd:
                return .init((image: R.image.usaFlag()!, symbol: ""))
            }
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
        textField.inputAccessoryView = UIToolbar.doneToolbarButton(#selector(closeKeyboard), self)
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

    //NOTE: Help to prevent recalculation for ethCostRawValue, dollarCostRawValue values, during recalculation we loose precission
    private var cryptoToDollarRatePrevValue: NSDecimalNumber?
    //NOTE: Raw values for eth and collar values, to prevent recalculation it we store user entered eth and calculated dollarCostRawValue value and vice versa.
    private var ethCostRawValue: NSDecimalNumber?
    private var dollarCostRawValue: NSDecimalNumber?
    private let cryptoCurrency: Currency
    private var currentPair: Pair

    var cryptoToDollarRate: NSDecimalNumber? = nil {
        willSet {
            cryptoToDollarRatePrevValue = cryptoToDollarRate
        }

        didSet {
            if let value = cryptoToDollarRate {
                //NOTE: Make sure value has changed
                if let prevValue = cryptoToDollarRatePrevValue, prevValue == value {
                    return
                }
                switch currentPair.left {
                case .cryptoCurrency:
                    recalculate(amountValue: ethCostRawValue)
                case .usd:
                    recalculate(amountValue: dollarCostRawValue)
                }

                updateAlternatePricingDisplay()
                update(selectCurrencyButton: selectCurrencyButton)
            }
        }
    }

    var dollarCost: NSDecimalNumber? {
        return dollarCostRawValue
    }

    var ethCost: String {
        get {
            switch currentPair.left {
            case .cryptoCurrency:
                return textField.text?.droppedTrailingZeros ?? "0"
            case .usd:
                guard let value = ethCostRawValue else { return "0" }
                return StringFormatter().alternateAmount(value: value).droppedTrailingZeros
            }
        }
        set {
            let valueToSet = newValue.optionalDecimalValue

            ethCostRawValue = valueToSet
            recalculate(amountValue: valueToSet, for: cryptoCurrency)

            switch currentPair.left {
            case .cryptoCurrency:
                textField.text = formatValueToDisplayValue(ethCostRawValue)
            case .usd:
                textField.text = formatValueToDisplayValue(dollarCostRawValue)
            }

            updateAlternatePricingDisplay()
        }
    }

    ///Returns raw (calculated) value based on selected currency
    private var alternativeAmount: NSDecimalNumber? {
        switch currentPair.left {
        case .cryptoCurrency:
            return dollarCostRawValue
        case .usd:
            return ethCostRawValue
        }
    }

    ///Formats string value for display in text field.
    private func formatValueToDisplayValue(_ value: NSDecimalNumber?) -> String {
        guard let amount = value else {
            return String()
        }

        switch currentPair.left {
        case .cryptoCurrency:
            return StringFormatter().currency(with: amount, and: Constants.Currency.usd).droppedTrailingZeros
        case .usd:
            return StringFormatter().alternateAmount(value: amount).droppedTrailingZeros
        }
    }

    ///Recalculates raw value (eth, or usd) depends on selected currency `currencyToOverride ?? currentPair.left` based on cryptoToDollarRate
    private func recalculate(amountValue: NSDecimalNumber?, for currencyToOverride: Currency? = nil) {
        guard let cryptoToDollarRate = cryptoToDollarRate else {
            return
        }

        switch currencyToOverride ?? currentPair.left {
        case .cryptoCurrency:
            if let amount = amountValue {
                dollarCostRawValue = amount.multiplying(by: cryptoToDollarRate)
            } else {
                dollarCostRawValue = nil
            }
        case .usd:
            if let amount = amountValue {
                ethCostRawValue = amount.dividing(by: cryptoToDollarRate)
            } else {
                ethCostRawValue = nil
            }
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
            alternativeAmountLabelContainer.isHidden = !newValue//true //!newValue
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
        currentPair.symbol
    }

    weak var delegate: AmountTextFieldDelegate?

    init(tokenObject: TokenObject) {
        cryptoCurrency = .cryptoCurrency(tokenObject)
        currentPair = Pair(left: cryptoCurrency, right: .usd)

        super.init(frame: .zero)

        translatesAutoresizingMaskIntoConstraints = false

        let stackView = [selectCurrencyButton, .spacerWidth(4), textField].asStackView(axis: .horizontal)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stackView)

        errorState = .none
        updateAlternateAmountLabel(alternativeAmount)

        NSLayoutConstraint.activate([
            stackView.anchorsConstraint(to: self),
        ])

        inputAccessoryButton.addTarget(self, action: #selector(closeKeyboard), for: .touchUpInside)
    }

    private func updateAlternateAmountLabel(_ value: NSDecimalNumber?) {
        let amount = formatValueToDisplayValue(value)

        if amount.isEmpty {
            let atLeastOneWhiteSpaceToKeepTextFieldHeight = " "
            alternativeAmountLabel.text = atLeastOneWhiteSpaceToKeepTextFieldHeight
        } else {
            switch currentPair.left {
            case .cryptoCurrency:
                alternativeAmountLabel.text = "~ \(amount) \(Constants.Currency.usd)"
            case .usd:
                switch currentPair.right {
                case .cryptoCurrency(let tokenObject):
                    alternativeAmountLabel.text = "~ \(amount) " + tokenObject.symbol
                case .usd:
                    break
                }
            }
        }
    }

    @discardableResult override func becomeFirstResponder() -> Bool {
        super.becomeFirstResponder()
        return textField.becomeFirstResponder()
    }

    private func update(selectCurrencyButton button: SelectCurrencyButton) {
        button.text = currentPair.symbol
        button.tokenIcon = currentPair.icon
    }

    @objc private func fiatAction(button: UIButton) {
        guard cryptoToDollarRate != nil else { return }

        let oldAlternateAmount = formatValueToDisplayValue(alternativeAmount)

        togglePair()

        textField.text = oldAlternateAmount

        updateAlternateAmountLabel(alternativeAmount)

        becomeFirstResponder()
        delegate?.changeType(in: self)
    }

    private func updateAlternatePricingDisplay() {
        updateAlternateAmountLabel(alternativeAmount)

        delegate?.changeAmount(in: self)
    }

    func togglePair() {
        currentPair.swap()
        update(selectCurrencyButton: selectCurrencyButton)
    }

    required init?(coder aDecoder: NSCoder) {
        return nil
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
}

extension AmountTextField: UITextFieldDelegate {

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        guard let delegate = delegate else { return true }
        return delegate.shouldReturn(in: self)
    }

    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        guard let enteredString = textField.stringReplacingCharacters(in: range, with: string) else { return false }

        let allowChange = textField.amountChanged(in: range, to: string, allowedCharacters: allowedCharacters)
        if allowChange {
            //NOTE: Set raw value (ethCost, dollarCost) and recalculate alternative value
            switch currentPair.left {
            case .cryptoCurrency:
                ethCostRawValue = enteredString.optionalDecimalValue

                recalculate(amountValue: ethCostRawValue)
            case .usd:
                dollarCostRawValue = enteredString.optionalDecimalValue

                recalculate(amountValue: dollarCostRawValue)
            }

            //We have to allow the text field the chance to update, so we have to use asyncAfter..
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                guard let strongSelf = self else { return }

                strongSelf.updateAlternatePricingDisplay()
            }
        }
        return allowChange
    }
}

private extension UITextField {

    func stringReplacingCharacters(in range: NSRange, with string: String) -> String? {
        (text as NSString?)?.replacingCharacters(in: range, with: string)
    }

    func amountChanged(in range: NSRange, to string: String, allowedCharacters: String) -> Bool {
        guard let input = text else {
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
} 

extension Character {
    var toString: String {
        return String(self)
    }
}

extension String {

    ///Allow to convert locale based decimal number to its Double value supports strings like `123,123.12`
    var optionalDecimalValue: NSDecimalNumber? {
        return EtherNumberFormatter.full.decimal(from: self)
    }

    var droppedTrailingZeros: String {
        var string = self
        let decimalSeparator = Locale.current.decimalSeparator ?? "."

        while string.last == "0" || string.last?.toString == decimalSeparator {
            if string.last?.toString == decimalSeparator {
                string = String(string.dropLast())
                break
            }
            string = String(string.dropLast())
        }

        return string
    }

}

extension EtherNumberFormatter {

    /// returns Double? value from `value` formatted from `EtherNumberFormatter` with appropriate `decimalSeparator` and `groupingSeparator`
    func decimal(from value: String) -> NSDecimalNumber? {

        enum Wrapper {
            static let formatter: NumberFormatter = {
                let formatter = NumberFormatter()
                formatter.numberStyle = .decimal

                return formatter
            }()
        }

        let formatter = Wrapper.formatter
        formatter.decimalSeparator = decimalSeparator
        formatter.groupingSeparator = groupingSeparator

        guard let result = formatter.number(from: value)?.decimalValue else { return nil }

        return NSDecimalNumber(decimal: result)
    }
}

extension UIToolbar {

    static func doneToolbarButton(_ selector: Selector, _ target: AnyObject) -> UIToolbar {
        //Frame needed, but actual values aren't that important
        let toolbar = UIToolbar(frame: CGRect(x: 0, y: 0, width: 100, height: 40))
        toolbar.barStyle = .default

        let flexSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let done = UIBarButtonItem(title: R.string.localizable.done(), style: .done, target: target, action: selector)

        toolbar.items = [flexSpace, done]
        toolbar.sizeToFit()

        return toolbar
    }

    static func nextToolbarButton(_ selector: Selector, _ target: AnyObject) -> UIToolbar {
        //Frame needed, but actual values aren't that important
        let toolbar = UIToolbar(frame: CGRect(x: 0, y: 0, width: 100, height: 40))
        toolbar.barStyle = .default

        let flexSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let next = UIBarButtonItem(title: R.string.localizable.next(), style: .plain, target: target, action: selector)
        toolbar.items = [flexSpace, next]
        toolbar.sizeToFit()

        return toolbar
    }
}
