// Copyright © 2018 Stormbird PTE. LTD.

import UIKit
import Combine
import AlphaWalletFoundation

protocol AmountTextFieldDelegate: AnyObject {
    func shouldReturn(in textField: AmountTextField) -> Bool

    func changeAmount(in textField: AmountTextField)
    func changeType(in textField: AmountTextField)
    func doneButtonTapped(for textField: AmountTextField)
    func nextButtonTapped(for textField: AmountTextField)
}

extension AmountTextFieldDelegate {
    func changeAmount(in textField: AmountTextField) { }
    func changeType(in textField: AmountTextField) { }
    func doneButtonTapped(for textField: AmountTextField) { }
    func nextButtonTapped(for textField: AmountTextField) { }
}

final class AmountTextField: UIControl {
    private lazy var statusLabelContainer: UIView = [statusLabel].asStackView(axis: .horizontal)
    private lazy var allFundsContainer: UIView = [allFundsButton].asStackView(axis: .horizontal)
    private lazy var alternativeAmountLabelContainer: UIView = [alternativeAmountLabel].asStackView(axis: .horizontal)
    private var cancelable = Set<AnyCancellable>()
    private let tokenImageFetcher: TokenImageFetcher

    private(set) lazy var textField: UITextField = {
        let textField = UITextField()
        textField.attributedPlaceholder = NSAttributedString(string: "0", attributes: [
            .font: Configuration.Font.amountTextField, .foregroundColor: Configuration.Color.Semantic.placeholderText
        ])
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.delegate = self
        textField.keyboardType = .decimalPad
        textField.leftViewMode = .always
        textField.textColor = Configuration.Color.Semantic.defaultForegroundText
        textField.font = Configuration.Font.amountTextField
        textField.textAlignment = .right

        return textField
    }()

    let allFundsButton: Button = {
        let button = Button(size: .normal, style: .borderless)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle(R.string.localizable.sendAllFunds(), for: .normal)
        button.titleLabel?.font = Configuration.Font.accessory
        button.setTitleColor(Configuration.Color.Semantic.icon, for: .normal)
        button.setBackgroundColor(.clear, forState: .normal)
        button.contentHorizontalAlignment = .right
        button.heightConstraint.flatMap { NSLayoutConstraint.deactivate([$0]) }
        button.heightAnchor.constraint(equalToConstant: 25).isActive = true
        button.contentEdgeInsets = .zero
        button.setContentHuggingPriority(.required, for: .horizontal)
        button.setContentCompressionResistancePriority(.required, for: .horizontal)
        
        return button
    }()

    let statusLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private (set) lazy var cryptoValuePublisher: AnyPublisher<AmountTextFieldViewModel.FungibleAmount, Never> = {
        return viewModel.cryptoValueChanged
            .map { $0.amount }
            .prepend(viewModel.crypto(for: textField.text))
            .share()
            .eraseToAnyPublisher()
    }()

    var cryptoValue: AmountTextFieldViewModel.FungibleAmount {
        viewModel.crypto(for: textField.text)
    }

    var fiatValue: Double? {
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
        label.textColor = Configuration.Color.Semantic.textFieldContrastText
        label.font = Configuration.Font.label

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

    var isAllFundsEnabled: Bool {
        get { return !allFundsContainer.isHidden }
        set { allFundsContainer.isHidden = !newValue }
    }

    var inputAccessoryButtonType = TextField.InputAccessoryButtonType.none {
        didSet {
            switch inputAccessoryButtonType {
            case .done:
                textField.inputAccessoryView = UIToolbar.doneToolbarButton(#selector(doneButtonTapped), self)
            case .next:
                textField.inputAccessoryView = UIToolbar.nextToolbarButton(#selector(nextButtonTapped), self)
            case .none:
                textField.inputAccessoryView = nil
            }
        }
    }

    weak var delegate: AmountTextFieldDelegate?
    let viewModel: AmountTextFieldViewModel

    convenience init(token: Token?, debugName: String = "", tokenImageFetcher: TokenImageFetcher) {
        self.init(viewModel: .init(token: token, debugName: debugName), tokenImageFetcher: tokenImageFetcher)
    }

    init(viewModel: AmountTextFieldViewModel, tokenImageFetcher: TokenImageFetcher) {
        self.viewModel = viewModel
        self.tokenImageFetcher = tokenImageFetcher
        super.init(frame: .zero)

        translatesAutoresizingMaskIntoConstraints = false

        let stackView = [selectCurrencyButton, .spacerWidth(4), textField].asStackView(axis: .horizontal)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stackView)

        NSLayoutConstraint.activate([
            selectCurrencyButton.widthAnchor.constraint(lessThanOrEqualTo: widthAnchor, multiplier: 0.5),
            stackView.anchorsConstraint(to: self),
        ])

        bind(viewModel: viewModel)
    }

    func set(amount: AmountTextFieldViewModel.FungibleAmount) {
        viewModel.set(amount: amount)
        notifyAmountDidChange()
    }

    func defaultLayout(edgeInsets: UIEdgeInsets = .zero) -> UIView {
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
        view.backgroundColor = Configuration.Color.Semantic.defaultViewBackground
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
                    .font: Configuration.Font.amountTextField, .foregroundColor: errorState.textFieldPlaceholderTextColor
                ])
            }.store(in: &cancelable)

        output.currentPair
            .sink { [weak selectCurrencyButton, weak self] in
                guard let `self` = self else { return }
                
                if let pair = $0 {
                    selectCurrencyButton?.hasToken = true
                    selectCurrencyButton?.text = pair.symbol
                    selectCurrencyButton?.set(imageSource: self.currencyOrTokenImage(for: pair))
                } else {
                    selectCurrencyButton?.hasToken = false
                }

                self.delegate?.changeType(in: self)
            }.store(in: &cancelable)

        output.alternativeAmount
            .assign(to: \.text, on: alternativeAmountLabel)
            .store(in: &cancelable)

        output.text
            .assign(to: \.text, on: textField)
            .store(in: &cancelable)
    }
    
    @discardableResult override func becomeFirstResponder() -> Bool {
        return textField.becomeFirstResponder()
    }

    @discardableResult override func resignFirstResponder() -> Bool {
        return textField.resignFirstResponder()
    }

    required init?(coder aDecoder: NSCoder) {
        return nil
    }

    @objc private func doneButtonTapped() {
        delegate?.doneButtonTapped(for: self)
    }

    @objc private func nextButtonTapped() {
        delegate?.nextButtonTapped(for: self)
    }

    private func currencyOrTokenImage(for pair: AmountTextField.Pair) -> TokenImagePublisher {
        switch pair.left {
        case .cryptoCurrency(let token):
            return tokenImageFetcher.image(token: token, size: .s120)
        case .fiatCurrency(let currency):
            let imageSource = currency.icon.flatMap { RawImage.loaded(image: $0) } ?? .none

            return .just(.init(image: .image(imageSource), isFinal: true, overlayServerIcon: nil))
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

        let allowChange = viewModel.isValid(string: string)

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
}
