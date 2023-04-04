// Copyright © 2018 Stormbird PTE. LTD.

import UIKit
import Combine

protocol TextFieldDelegate: AnyObject {
    func shouldReturn(in textField: TextField) -> Bool
    func shouldChangeCharacters(inRange range: NSRange, replacementString string: String, for textField: TextField) -> Bool
    func doneButtonTapped(for textField: TextField)
    func nextButtonTapped(for textField: TextField)
}

extension TextFieldDelegate {
    func shouldChangeCharacters(inRange range: NSRange, replacementString string: String, for textField: TextField) -> Bool {
        return true
    }
    func doneButtonTapped(for textField: TextField) { }
    func nextButtonTapped(for textField: TextField) { }
}

class TextField: UIControl {
    enum InputAccessoryButtonType {
        case done
        case next
        case none
    }

    enum TextFieldErrorState {
        case error(String)
        case none

        func textFieldBorderColor(whileEditing: Bool = false) -> UIColor {
            switch self {
            case .none:
                return whileEditing ? Configuration.Color.Semantic.textFieldShadowWhileEditing : Configuration.Color.Semantic.border
            case .error:
                return Configuration.Color.Semantic.defaultErrorText
            }
        }

        func textFieldShowShadow(whileEditing: Bool = false) -> Bool {
            switch self {
            case .error:
                return true
            case .none:
                return whileEditing
            }
        }

        func textFieldTextColor(whileEditing: Bool = false) -> UIColor {
            switch self {
            case .none:
                return Configuration.Color.Semantic.defaultForegroundText
            case .error:
                return Configuration.Color.Semantic.defaultErrorText
            }
        }
    }

    var returnKeyType: UIReturnKeyType {
        get { return textField.returnKeyType }
        set { textField.returnKeyType = newValue }
    }

    var keyboardType: UIKeyboardType {
        get { return textField.keyboardType }
        set { textField.keyboardType = newValue }
    }

    public var isSecureTextEntry: Bool {
        get { return textField.isSecureTextEntry }
        set { textField.isSecureTextEntry = newValue }
    }

    let label: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = Configuration.Font.textFieldTitle
        label.textColor = Configuration.Color.Semantic.defaultSubtitleText
        label.textAlignment = .left

        return label
    }()

    let statusLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.setContentHuggingPriority(.required, for: .vertical)
        label.setContentCompressionResistancePriority(.required, for: .vertical)
        label.font = Configuration.Font.textFieldStatus
        label.textColor = Configuration.Color.Semantic.textFieldStatus
        label.textAlignment = .left
        
        return label
    }()

    lazy var textField: UITextField = {
        let textField = _TextField()
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.delegate = self
        textField.leftViewMode = .always
        textField.rightViewMode = .always
        textField.textColor = Configuration.Color.Semantic.defaultForegroundText
        textField.font = Configuration.Font.textField

        return textField
    }()

    weak var delegate: TextFieldDelegate?

    var value: String {
        get { return textField.text ?? "" }
        set { textField.text = newValue }
    }

    var status: TextFieldErrorState = .none {
        didSet {
            switch status {
            case .error(let error):
                statusLabel.text = error
                statusLabel.isHidden = error.isEmpty
            case .none:
                statusLabel.text = nil
                statusLabel.isHidden = true
            }

            let textColor = status.textFieldTextColor(whileEditing: isFirstResponder)
            let borderColor = status.textFieldBorderColor(whileEditing: isFirstResponder)
            let shouldDropShadow = status.textFieldShowShadow(whileEditing: isFirstResponder)

            textField.textColor = textColor
            layer.borderColor = borderColor.cgColor

            dropShadow(color: shouldDropShadow ? borderColor : .clear, radius: DataEntry.Metric.shadowRadius)
        }
    }

    var inputAccessoryButtonType = InputAccessoryButtonType.none {
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

    var placeholder: String? {
        get { textField.placeholder }
        set { textField.placeholder = newValue }
    }

    private (set) lazy var heightConstraint: NSLayoutConstraint = {
        heightAnchor.constraint(equalToConstant: DataEntry.Metric.TextField.Default.height)
    }()

    var textInset: CGSize {
       get { return CGSize(width: (textField as! _TextField).insetX, height: (textField as! _TextField).insetY) }
       set { (textField as! _TextField).insetX = newValue.width; (textField as! _TextField).insetY = newValue.height; }
    }

    override var isFirstResponder: Bool {
        return textField.isFirstResponder
    }
    private let text = PassthroughSubject<String?, Never>()
    private let viewModel: TextFieldViewModel

    init(edgeInsets: UIEdgeInsets = DataEntry.Metric.TextField.Default.edgeInsets, viewModel: TextFieldViewModel = .init()) {
        self.viewModel = viewModel
        super.init(frame: .zero)

        translatesAutoresizingMaskIntoConstraints = false
        addSubview(textField)

        NSLayoutConstraint.activate([
            textField.anchorsConstraint(to: self, edgeInsets: edgeInsets),
            heightConstraint,
        ])

        cornerRadius = DataEntry.Metric.TextField.Default.cornerRadius
        layer.borderWidth = DataEntry.Metric.borderThickness
        backgroundColor = Configuration.Color.Semantic.textFieldBackground
        layer.borderColor = status.textFieldBorderColor(whileEditing: isFirstResponder).cgColor
        status = .none

        bind(viewModel: viewModel)
    }

    private var cancellable = Set<AnyCancellable>()
    
    private func bind(viewModel: TextFieldViewModel) {
        let input = TextFieldViewModelInput(textChanged: text.eraseToAnyPublisher())
        let output = viewModel.transform(input: input)

        output.text
            .assign(to: \.text, on: textField, ownership: .weak)
            .store(in: &cancellable)

        output.attributedPlaceholder
            .sink { [weak label] placeholder in
                label?.attributedText = placeholder
                label?.isHidden = placeholder == nil
            }.store(in: &cancellable)

        output.keyboardType
            .assign(to: \.keyboardType, on: textField, ownership: .weak)
            .store(in: &cancellable)

        output.status
            .assign(to: \.status, on: self, ownership: .weak)
            .store(in: &cancellable)

        output.allowEditing
            .assign(to: \.isUserInteractionEnabled, on: self, ownership: .weak)
            .store(in: &cancellable)
    }

    func defaultLayout(edgeInsets: UIEdgeInsets = .zero) -> UIView {
        let stackView = [
            label,
            .spacer(height: DataEntry.Metric.TextField.Default.spaceFromTitleToTextField),
            //NOTE: adding shadow inset as edgeInsets might be .zero, and the sized shadow will be clipped
            [.spacerWidth(DataEntry.Metric.shadowRadius), self, .spacerWidth(DataEntry.Metric.shadowRadius)].asStackView(axis: .horizontal),
            .spacer(height: DataEntry.Metric.TextField.Default.spaceFromTitleToTextField),
            statusLabel,
        ].asStackView(axis: .vertical)

        stackView.translatesAutoresizingMaskIntoConstraints = false

        let view = UIView()
        view.backgroundColor = Configuration.Color.Semantic.defaultViewBackground
        view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.anchorsConstraint(to: view, edgeInsets: edgeInsets),
        ])

        return view
    }

    required init?(coder aDecoder: NSCoder) {
        return nil
    }

    @objc private func doneButtonTapped(_ sender: UIButton) {
        delegate?.doneButtonTapped(for: self)
    }

    @objc private func nextButtonTapped(_ sender: UIButton) {
        delegate?.nextButtonTapped(for: self)
    }

    @discardableResult override func becomeFirstResponder() -> Bool {
        return textField.becomeFirstResponder()
    }

    @discardableResult override func resignFirstResponder() -> Bool {
        return textField.resignFirstResponder()
    }
}

extension TextField: UITextFieldDelegate {

    func textFieldDidEndEditing(_ textField: UITextField) {
        let borderColor = status.textFieldBorderColor(whileEditing: false)
        let shouldDropShadow = status.textFieldShowShadow(whileEditing: false)
        layer.borderColor = borderColor.cgColor
        backgroundColor = Configuration.Color.Semantic.textFieldBackground

        dropShadow(color: shouldDropShadow ? borderColor : .clear, radius: DataEntry.Metric.shadowRadius)
    }

    func textFieldDidBeginEditing(_ textField: UITextField) {
        let borderColor = status.textFieldBorderColor(whileEditing: true)
        layer.borderColor = borderColor.cgColor
        backgroundColor = Configuration.Color.Semantic.textFieldBackground

        dropShadow(color: borderColor, radius: DataEntry.Metric.shadowRadius)
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        guard let delegate = delegate else { return true }
        return delegate.shouldReturn(in: self)
    }

    public func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        let value = (textField.text! as NSString).replacingCharacters(in: range, with: string)
        self.text.send(value)

        return delegate?.shouldChangeCharacters(inRange: range, replacementString: string, for: self) ?? true
    }
}

private class _TextField: UITextField {
    var insetX: CGFloat = 0
    var insetY: CGFloat = 0

    override func textRect(forBounds bounds: CGRect) -> CGRect {
        return bounds.insetBy(dx: insetX, dy: insetY)
    }

    override func editingRect(forBounds bounds: CGRect) -> CGRect {
        return bounds.insetBy(dx: insetX, dy: insetY)
    }

    override func placeholderRect(forBounds: CGRect) -> CGRect {
        return forBounds.insetBy(dx: insetX, dy: insetY)
    }
}

extension TextField {
    static func buildTextField(viewModel: TextFieldViewModel = .init()) -> TextField {
        let textField = TextField(edgeInsets: DataEntry.Metric.TextField.Default.edgeInsets, viewModel: viewModel)
        textField.cornerRadius = DataEntry.Metric.TextField.Default.cornerRadius
        textField.textInset = DataEntry.Metric.TextField.Default.textInset
        textField.textField.autocorrectionType = .no
        textField.textField.autocapitalizationType = .none
        textField.textField.spellCheckingType = .no
        textField.returnKeyType = .next
        
        return textField
    }

    static func buildTextField(keyboardType: UIKeyboardType, placeHolder: String, label: String) -> TextField {
        let textField = TextField.buildTextField()
        textField.keyboardType = keyboardType
        textField.placeholder = placeHolder
        textField.label.text = label

        return textField
    }

    static func buildRoundedTextField() -> TextField {
        let textField = TextField(edgeInsets: DataEntry.Metric.TextField.Rounded.edgeInsets)
        textField.heightConstraint.constant = DataEntry.Metric.TextField.Rounded.height
        textField.cornerRadius = DataEntry.Metric.TextField.Rounded.cornerRadius
        textField.textInset = DataEntry.Metric.TextField.Rounded.textInset

        return textField
    }

    static func buildPasswordTextField() -> TextField {
        let textField: TextField = .buildTextField()
        textField.textField.autocorrectionType = .no
        textField.textField.autocapitalizationType = .none
        textField.returnKeyType = .done
        textField.inputAccessoryButtonType = .done
        textField.textField.clearButtonMode = .never
        textField.textField.rightView = {
            let button = UIButton(type: .system)
            button.frame = .init(x: 0, y: 0, width: 30, height: 30)
            button.setImage(R.image.togglePassword(), for: .normal)
            button.tintColor = Configuration.Color.Semantic.textFieldPasswordTint
            button.addTarget(textField, action: #selector(toggleMaskPassword), for: .touchUpInside)
            return button
        }()
        textField.textField.rightViewMode = .always
        textField.isSecureTextEntry = true

        return textField
    }
}

fileprivate extension TextField {

    @objc private func toggleMaskPassword(_ sender: UIButton) {
        isSecureTextEntry.toggle()
        if isSecureTextEntry {
            sender.tintColor = Configuration.Color.Semantic.secureIcon
        } else {
            sender.tintColor = Configuration.Color.Semantic.textFieldPasswordTint
        }
    }
}
