// Copyright © 2018 Stormbird PTE. LTD.

import UIKit

protocol AmountTextFieldDelegate: class {
    func changeAmount(in textField: AmountTextField)
    func changeType(in textField: AmountTextField)
}

class AmountTextField: UIControl {
    struct Pair {
        let left: String
        let right: String

        func swapPair() -> Pair {
            return Pair(left: right, right: left)
        }
    }
    var ethToDollarRate: Double? = nil {
        didSet {
            if let ethToDollarRate = ethToDollarRate {
                updateAlternatePricingDisplay()
            }
        }
    }
    var ethCost: String {
        if currentPair.left == "ETH" {
            return textField.text ?? "0"
        } else {
            return convertToAlternateAmount()
        }
    }
    var dollarCost: String {
        if currentPair.left == "ETH" {
            return convertToAlternateAmount()
        } else {
            return textField.text ?? "0"
        }
    }
    var currentPair: Pair
    let textField = UITextField()
    let alternativeAmountLabel = UILabel()
    let fiatButton = Button(size: .normal, style: .borderless)
    weak var delegate: AmountTextFieldDelegate?

    private var allowedCharacters: String = {
        let decimalSeparator = Locale.current.decimalSeparator ?? "."
        return "0123456789" + decimalSeparator
    }()
    lazy var decimalFormatter: DecimalFormatter = {
        return DecimalFormatter()
    }()

    init() {
        currentPair = Pair(left: "ETH", right: "USD")

        super.init(frame: .zero)

        translatesAutoresizingMaskIntoConstraints = false
        layer.borderColor = Colors.appBackground.cgColor
        layer.borderWidth = 1

        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.delegate = self
        textField.keyboardType = .decimalPad
        textField.leftViewMode = .always
        textField.rightViewMode = .always
        textField.inputAccessoryView = makeToolbarWithDoneButton()
        textField.leftView = .spacerWidth(22)
        textField.rightView = makeAmountRightView()
        textField.textColor = Colors.appBackground
        textField.font = Fonts.bold(size: 21)
        addSubview(textField)

        alternativeAmountLabel.translatesAutoresizingMaskIntoConstraints = false
        alternativeAmountLabel.numberOfLines = 0
        alternativeAmountLabel.textColor = Colors.appGrayLabelColor
        alternativeAmountLabel.font = Fonts.regular(size: 10)!
        alternativeAmountLabel.textAlignment = .center

        computeAlternateAmount()

        NSLayoutConstraint.activate([
            textField.leadingAnchor.constraint(equalTo: leadingAnchor),
            textField.trailingAnchor.constraint(equalTo: trailingAnchor),
            textField.topAnchor.constraint(equalTo: topAnchor),
            textField.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    private func makeAmountRightView() -> UIView {
        fiatButton.translatesAutoresizingMaskIntoConstraints = false
        fiatButton.setTitle(currentPair.left, for: .normal)
        fiatButton.setTitleColor(Colors.appGrayLabelColor, for: .normal)
        fiatButton.addTarget(self, action: #selector(fiatAction), for: .touchUpInside)

        let amountRightView = [fiatButton].asStackView(distribution: .equalSpacing)
        amountRightView.translatesAutoresizingMaskIntoConstraints = false

        return amountRightView
    }

    @objc func fiatAction(button: UIButton) {
        guard ethToDollarRate != nil else { return }
        let swappedPair = currentPair.swapPair()
        //New pair for future calculation we should swap pair each time we press fiat button.
        self.currentPair = swappedPair
        fiatButton.setTitle(currentPair.left, for: .normal)
        button.setTitle(currentPair.left, for: .normal)
        textField.text = nil
        computeAlternateAmount()
        activateAmountView()
        delegate?.changeType(in: self)
    }

    private func activateAmountView() {
        becomeFirstResponder()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func makeToolbarWithDoneButton() -> UIToolbar {
        //Frame needed, but actual values aren't that important
        let toolbar = UIToolbar(frame: CGRect(x: 0, y: 0, width: 100, height: 40))
        toolbar.barStyle = .default

        let flexSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let done = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(closeKeyboard))

        toolbar.items = [flexSpace, done]
        toolbar.sizeToFit()

        return toolbar
    }

    @objc func closeKeyboard() {
        endEditing(true)
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
            if currentPair.left == "ETH" {
                alternativeAmountLabel.text = "~ \(amount) USD"
            } else {
                alternativeAmountLabel.text = "~ \(amount) ETH"
            }
        }
    }

    private func convertToAlternateAmount() -> String {
        if let ethToDollarRate = ethToDollarRate, let string = textField.text, let amount = Double(string) {
            if currentPair.left == "ETH" {
                return String(amount * ethToDollarRate)
            } else {
                return String(amount / ethToDollarRate)
            }
        } else {
            return ""
        }
    }

    private func updateAlternatePricingDisplay() {
        self.computeAlternateAmount()
        self.delegate?.changeAmount(in: self)
    }
}

extension AmountTextField: UITextFieldDelegate {
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        let allowChange = amountChanged(in: range, to: string)
        if allowChange {
            //We have to allow the text field the chance to update, so we have to use asyncAfter..
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.updateAlternatePricingDisplay()
            }

        }
        return allowChange
    }
}
