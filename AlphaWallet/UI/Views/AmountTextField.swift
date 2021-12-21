// Copyright © 2018 Stormbird PTE. LTD.

import UIKit

protocol AmountTextFieldDelegate: AnyObject {
    func changeAmount(in textField: AmountTextField)
    func changeType(in textField: AmountTextField)
    func shouldReturn(in textField: AmountTextField) -> Bool
}

// swiftlint:disable type_body_length
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
                return Fonts.semibold(size: 13)
            case .none:
                return Fonts.regular(size: 13)
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
                return .init((image: .image(R.image.usaFlag()!), symbol: "", isFinal: true))
            }
        }
    }

    private lazy var textField: UITextField = {
        let textField = UITextField()
        textField.attributedPlaceholder = NSAttributedString(string: "0", attributes: [
            .font: DataEntry.Font.amountTextField, .foregroundColor: DataEntry.Color.placeholder
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

    var allFundsButton: Button = {
        let button = Button(size: .normal, style: .borderless)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle(R.string.localizable.sendAllFunds(), for: .normal)
        button.titleLabel?.font = DataEntry.Font.accessory
        button.setTitleColor(DataEntry.Color.icon, for: .normal)
        button.setBackgroundColor(.clear, forState: .normal)
        button.contentHorizontalAlignment = .right
        button.heightConstraint.flatMap { NSLayoutConstraint.deactivate([$0]) }
        button.heightAnchor.constraint(equalToConstant: 25).isActive = true
        button.contentEdgeInsets = .zero

        return button
    }()

    private lazy var inputAccessoryButton: UIButton = {
        let button = UIButton()
        button.setTitle(accessoryButtonTitle.buttonTitle, for: .normal)
        button.setTitleColor(R.color.black(), for: .normal)

        return button
    }()

    private var allowedCharacters: String = {
        let decimalSeparator = Config.locale.decimalSeparator ?? ""
        return "0123456789" + decimalSeparator + EtherNumberFormatter.decimalPoint
    }()

    let statusLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false

        return label
    }()

    //NOTE: Helps to prevent recalculation for ethCostRawValue, dollarCostRawValue values. During recalculation we loose precission
    private var cryptoToDollarRatePrevValue: NSDecimalNumber?
    //NOTE: Raw values for eth and fiat values. To prevent recalculation we store entered eth and calculated dollarCostRawValue values and vice versa.
    private (set) var ethCostRawValue: NSDecimalNumber?
    private var dollarCostRawValue: NSDecimalNumber?
    private let cryptoCurrency: Currency
    private var currentPair: Pair

    var value: String? {
        return textField.text
    }

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

    var isAllFunds: Bool = false

    private var ethCostFormatedForCurrentLocale: String {
        switch currentPair.left {
        case .cryptoCurrency:
            return textField.text?.droppedTrailingZeros ?? "0"
        case .usd:
            guard let value = ethCostRawValue else { return "0" }
            return StringFormatter().alternateAmount(value: value, usesGroupingSeparator: false)
        }
    }

    var ethCost: String {
        get {
            if isAllFunds {
                return ethCostRawValue.localizedString
            } else {
                if let value = ethCostFormatedForCurrentLocale.optionalDecimalValue {
                    return value.localizedString
                } else {
                    return "0"
                }
            }
        }
        set {
            set(ethCost: newValue, useFormatting: true)
        }
    }

    func set(ethCost: NSDecimalNumber?, shortEthCost: String? = .none, useFormatting: Bool) {
        self.set(ethCost: ethCost.localizedString, shortEthCost: shortEthCost, useFormatting: useFormatting)
    }

    func set(ethCost: String, shortEthCost: String? = .none, useFormatting: Bool) {
        let valueToSet = ethCost.optionalDecimalValue

        ethCostRawValue = valueToSet
        recalculate(amountValue: valueToSet, for: cryptoCurrency)

        switch currentPair.left {
        case .cryptoCurrency:
            if useFormatting {
                textField.text = formatValueToDisplayValue(ethCostRawValue)
            } else if let shortEthCost = shortEthCost, shortEthCost.optionalDecimalValue != 0 {
                textField.text = shortEthCost
            } else {
                textField.text = ethCost
            }
        case .usd:
            textField.text = formatValueToDisplayValue(dollarCostRawValue)
        }

        updateAlternatePricingDisplay()
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
    private func formatValueToDisplayValue(_ value: NSDecimalNumber?, usesGroupingSeparator: Bool = false) -> String {
        guard let amount = value else {
            return String()
        }

        switch currentPair.left {
        case .cryptoCurrency:
            return StringFormatter().currency(with: amount, and: Constants.Currency.usd, usesGroupingSeparator: usesGroupingSeparator)
        case .usd:
            return StringFormatter().alternateAmount(value: amount, usesGroupingSeparator: usesGroupingSeparator)
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
                .font: DataEntry.Font.amountTextField, .foregroundColor: errorState.textFieldPlaceholderTextColor
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

    var isAlternativeAmountEnabled: Bool {
        get {
            return !alternativeAmountLabelContainer.isHidden
        }
        set {
            alternativeAmountLabelContainer.isHidden = !newValue
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

    var allFundsAvailable: Bool {
        get {
            return !allFundsContainer.isHidden
        }
        set {
            allFundsContainer.isHidden = !newValue
        }
    }

    private lazy var statusLabelContainer: UIView = {
        return [statusLabel].asStackView(axis: .horizontal)
    }()

    private lazy var allFundsContainer: UIView = {
        return [allFundsButton].asStackView(axis: .horizontal)
    }()

    private lazy var alternativeAmountLabelContainer: UIView = {
        return [alternativeAmountLabel].asStackView(axis: .horizontal)
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

    func defaultLayout(edgeInsets: UIEdgeInsets = .zero) -> UIView {
        let stackView = [
            .spacer(height: edgeInsets.top),
            //NOTE: remove spacers when refactor send token screen, there is to many lines related to constraints
            //remove spacers for inner containers like: statusLabelContainer, alternativeAmountLabelContainer
            //left it for now, too many changes for 1 pr.
            self,
            .spacer(height: 4),
            [statusLabelContainer, allFundsContainer].asStackView(axis: .horizontal, alignment: .fill),
            alternativeAmountLabelContainer,
            .spacer(height: edgeInsets.bottom)
        ].asStackView(axis: .vertical)

        return [.spacerWidth(edgeInsets.left), stackView, .spacerWidth(edgeInsets.right)].asStackView()
    }

    private func updateAlternateAmountLabel(_ value: NSDecimalNumber?) {
        let amount = formatValueToDisplayValue(value, usesGroupingSeparator: true)

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
// swiftlint:enable type_body_length

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
        if let value = EtherNumberFormatter.plain.decimal(from: self) {
            return value
        //NOTE: for case when formatter configured with `,` decimal separator, but EtherNumberFormatter.plain.decimal returns value with `.` separator
        } else if let asDoubleValue = Double(self) {
            return NSDecimalNumber(value: asDoubleValue)
        } else {
            return .none
        }
    }

    var droppedTrailingZeros: String {
        var string = self
        let decimalSeparator = Config.locale.decimalSeparator ?? "."

        //NOTE: it seems like we need to remove trailing zeros only in case when string contains `decimalSeparator`
        guard string.contains(decimalSeparator) else { return string }

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

extension Optional where Self.Wrapped == NSDecimalNumber {
    var localizedString: String {
        switch self {
        case .none:
            return String()
        case .some(let value):
            return value.localizedString
        }
    }
}

extension NSDecimalNumber {
    var localizedString: String {
        return self.description(withLocale: Config.locale)
    }
}

extension EtherNumberFormatter {

    /// returns NSDecimalNumber? value from `value` formatted with `EtherNumberFormatter`s selected locale
    func decimal(from value: String) -> NSDecimalNumber? {
        let value = NSDecimalNumber(string: value, locale: locale)
        if value == .notANumber {
            return .none
        } else {
            return value
        }
    }
}
