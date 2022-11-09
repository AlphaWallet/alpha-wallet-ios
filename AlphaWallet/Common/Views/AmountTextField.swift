// Copyright © 2018 Stormbird PTE. LTD.

import UIKit
import Combine
import AlphaWalletFoundation

protocol AmountTextFieldDelegate: AnyObject {
    func changeAmount(in textField: AmountTextField)
    func changeType(in textField: AmountTextField)
    func shouldReturn(in textField: AmountTextField) -> Bool
}

final class AmountTextField: UIControl {
    private lazy var statusLabelContainer: UIView = [statusLabel].asStackView(axis: .horizontal)
    private lazy var allFundsContainer: UIView = [allFundsButton].asStackView(axis: .horizontal)
    private lazy var alternativeAmountLabelContainer: UIView = [alternativeAmountLabel].asStackView(axis: .horizontal)
    let inputAccessoryButton: UIButton = {
        let button = UIButton()
        button.setTitleColor(Configuration.Color.Semantic.defaultForegroundText, for: .normal)
        return button
    }()

    private var cancelable = Set<AnyCancellable>()

    private(set) lazy var textField: UITextField = {
        let textField = UITextField()
        textField.attributedPlaceholder = NSAttributedString(string: "0", attributes: [
            .font: DataEntry.Font.amountTextField, .foregroundColor: Configuration.Color.Semantic.placeholderText
        ])
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.adjustsFontSizeToFitWidth = true
        textField.delegate = self
        textField.keyboardType = .decimalPad
        textField.leftViewMode = .always
        textField.inputAccessoryView = UIToolbar.doneToolbarButton(#selector(closeKeyboard), self)
        textField.textColor = Configuration.Color.Semantic.defaultForegroundText
        textField.font = DataEntry.Font.amountTextField
        textField.textAlignment = .right

        return textField
    }()

    let allFundsButton: Button = {
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

    let statusLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private (set) lazy var cryptoValuePublisher: AnyPublisher<String, Never> = {
        return viewModel.cryptoValueChanged
            .map { $0.crypto }
            .prepend(viewModel.crypto(for: textField.text))
            .share()
            .eraseToAnyPublisher()
    }()

    var cryptoValue: String {
        viewModel.crypto(for: textField.text)
    }

    var fiatValue: NSDecimalNumber? {
        return viewModel.fiatRawValue
    }

    var value: String? {
        textField.text
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

    let selectCurrencyButton: SelectCurrencyButton = {
        let button = SelectCurrencyButton()
        return button
    }()

    var isAlternativeAmountEnabled: Bool {
        get { return !alternativeAmountLabelContainer.isHidden }
        set { alternativeAmountLabelContainer.isHidden = !newValue }
    }

    var availableTextHidden: Bool {
        get { return statusLabelContainer.isHidden }
        set { statusLabelContainer.isHidden = newValue }
    }

    var allFundsAvailable: Bool {
        get { return !allFundsContainer.isHidden }
        set { allFundsContainer.isHidden = !newValue }
    }

    weak var delegate: AmountTextFieldDelegate?
    let viewModel: AmountTextFieldViewModel

    convenience init(token: Token?, debugName: String = "", buttonType: AmountTextField.AccessoryButtonTitle = .done) {
        self.init(viewModel: .init(token: token, debugName: debugName))
    }

    init(viewModel: AmountTextFieldViewModel, buttonType: AmountTextField.AccessoryButtonTitle = .done) {
        self.viewModel = viewModel
        super.init(frame: .zero)

        translatesAutoresizingMaskIntoConstraints = false

        let stackView = [selectCurrencyButton, .spacerWidth(4), textField].asStackView(axis: .horizontal)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.anchorsConstraint(to: self),
        ])

        updateInputAccessoryView(buttonType: buttonType)

        inputAccessoryButton.addTarget(self, action: #selector(closeKeyboard), for: .touchUpInside)
        bind(viewModel: viewModel)
    }

    func set(crypto: String, shortCrypto: String? = .none, useFormatting: Bool) {
        viewModel.set(crypto: crypto, shortCrypto: shortCrypto, useFormatting: useFormatting)
        notifyAmountDidChange()
    }

    func defaultLayout(edgeInsets: UIEdgeInsets = .zero, backgroundColor: UIColor = Configuration.Color.Semantic.defaultViewBackground) -> UIView {
        let col1 = [
            //NOTE: remove spacers when refactor send token screen, there is to many lines related to constraints
            //remove spacers for inner containers like: statusLabelContainer, alternativeAmountLabelContainer
            //left it for now, too many changes for 1 pr.
            self,
            .spacer(height: 4),
            [statusLabelContainer, allFundsContainer].asStackView(axis: .horizontal, alignment: .fill),
            alternativeAmountLabelContainer,
        ].asStackView(axis: .vertical)

        let view = UIView()
        view.backgroundColor = backgroundColor
        view.translatesAutoresizingMaskIntoConstraints = false

        let stackView = col1
        view.addSubview(stackView)
        stackView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            view.heightAnchor.constraint(equalTo: stackView.heightAnchor),
            stackView.anchorsConstraint(to: view, edgeInsets: edgeInsets),
            alternativeAmountLabelContainer.heightAnchor.constraint(greaterThanOrEqualToConstant: 27)
        ])

        return view
    }

    private func bind(viewModel: AmountTextFieldViewModel) {
        let togglePair = selectCurrencyButton
            .publisher(forEvent: .touchUpInside)
            .eraseToAnyPublisher()

        let input = AmountTextFieldViewModelInput(togglePair: togglePair)
        let output = viewModel.transform(input: input)

        output.errorState
            .sink { [weak statusLabel, weak textField] errorState in
                statusLabel?.textColor = errorState.statusLabelTextColor
                statusLabel?.font = errorState.statusLabelFont
                textField?.textColor = errorState.textFieldTextColor

                textField?.attributedPlaceholder = NSAttributedString(string: "0", attributes: [
                    .font: DataEntry.Font.amountTextField, .foregroundColor: errorState.textFieldPlaceholderTextColor
                ])
            }.store(in: &cancelable)

        output.accessoryButtonTitle
            .sink { [weak inputAccessoryButton] in
                inputAccessoryButton?.setTitle($0.buttonTitle, for: .normal)
            }.store(in: &cancelable)

        output.currentPair
            .sink { [weak selectCurrencyButton, weak self] in
                guard let `self` = self else { return }
                
                if let pair = $0 {
                    selectCurrencyButton?.hasToken = true
                    selectCurrencyButton?.text = pair.symbol
                    selectCurrencyButton?.tokenIcon = pair.icon
                } else {
                    selectCurrencyButton?.hasToken = false
                }

                self.delegate?.changeType(in: self)
            }.store(in: &cancelable)

        output.alternativeAmount
            .assign(to: \.text, on: alternativeAmountLabel)
            .store(in: &cancelable)

        output.text
            .print("xxx.text")
            .assign(to: \.text, on: textField)
            .store(in: &cancelable)
    }

    private func updateInputAccessoryView(buttonType: AmountTextField.AccessoryButtonTitle) {
        switch buttonType {
        case .done:
            textField.inputAccessoryView = UIToolbar.doneToolbarButton(#selector(closeKeyboard), self)
        case .next:
            textField.inputAccessoryView = UIToolbar.nextToolbarButton(#selector(closeKeyboard), self)
        }
    }
    
    @discardableResult override func becomeFirstResponder() -> Bool {
        super.becomeFirstResponder()
        return textField.becomeFirstResponder()
    }

    @discardableResult override func resignFirstResponder() -> Bool {
        super.resignFirstResponder()
        return textField.resignFirstResponder()
    }

    required init?(coder aDecoder: NSCoder) {
        return nil
    }

    @objc private func closeKeyboard() {
        guard let delegate = delegate else {
            endEditing(true)
            return
        }

        if delegate.shouldReturn(in: self) {
            endEditing(true)
        }
    }

    ///We have to allow the text field the chance to update, so we have to use asyncAfter..
    private func notifyAmountDidChange() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let strongSelf = self else { return }

            strongSelf.delegate?.changeAmount(in: strongSelf)
        }
    }
}

extension AmountTextField: UITextFieldDelegate {

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        guard let delegate = delegate else { return true }
        return delegate.shouldReturn(in: self)
    }

    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        guard let string = textField.stringReplacingCharacters(in: range, with: string) else { return false }

        let allowChange = textField.amountChanged(in: range, to: string, allowedCharacters: AmountTextFieldViewModel.allowedCharacters)
        if allowChange {
            viewModel.set(string: string)
            notifyAmountDidChange()
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
