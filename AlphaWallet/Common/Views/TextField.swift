// Copyright © 2018 Stormbird PTE. LTD.

import UIKit

protocol TextFieldDelegate: AnyObject {
    func shouldReturn(in textField: TextField) -> Bool
    func doneButtonTapped(for textField: TextField)
    func nextButtonTapped(for textField: TextField)
    func shouldChangeCharacters(inRange range: NSRange, replacementString string: String, for textField: TextField) -> Bool
    func didBeginEditing(in textField: TextField)
}

extension TextFieldDelegate {
    func shouldChangeCharacters(inRange range: NSRange, replacementString string: String, for textField: TextField) -> Bool {
        return true
    }
    func didBeginEditing(in textField: TextField) {
        return
    }
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
                return whileEditing ? DataEntry.Color.textFieldShadowWhileEditing : DataEntry.Color.border
            case .error:
                return DataEntry.Color.textFieldError
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
                return DataEntry.Color.textFieldError
            }
        }
    }

    private var isConfigured = false

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

        return label
    }()

    let statusLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false

        return label
    }()

    let textField: UITextField = {
        let textField = _TextField()
        textField.translatesAutoresizingMaskIntoConstraints = false

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
                textField.inputAccessoryView = UIToolbar.doneToolbarButton(#selector(nextButtonTapped), self)
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

    init(edgeInsets: UIEdgeInsets = DataEntry.Metric.TextField.Default.edgeInsets) {
        super.init(frame: .zero)

        translatesAutoresizingMaskIntoConstraints = false

        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.delegate = self
        textField.leftViewMode = .always
        textField.rightViewMode = .always

        addSubview(textField)

        NSLayoutConstraint.activate([
            textField.anchorsConstraint(to: self, edgeInsets: edgeInsets),
            heightConstraint,
        ])
    }

    func configureOnce() {
        guard !isConfigured else { return }
        isConfigured = true

        cornerRadius = DataEntry.Metric.cornerRadius

        label.font = DataEntry.Font.textFieldTitle
        label.textColor = DataEntry.Color.label
        label.textAlignment = .left

        statusLabel.font = DataEntry.Font.textFieldStatus
        statusLabel.textColor = DataEntry.Color.textFieldStatus
        statusLabel.textAlignment = .left

        textField.textColor = Configuration.Color.Semantic.defaultForegroundText
        textField.font = DataEntry.Font.textField

        layer.borderWidth = DataEntry.Metric.borderThickness
        backgroundColor = Configuration.Color.Semantic.textFieldBackground
        layer.borderColor = status.textFieldBorderColor(whileEditing: isFirstResponder).cgColor
        status = .none
    }

    required init?(coder aDecoder: NSCoder) {
        return nil
    }

    @objc func doneButtonTapped() {
        delegate?.doneButtonTapped(for: self)
    }

    @objc func nextButtonTapped() {
        delegate?.nextButtonTapped(for: self)
    }

    @discardableResult override func becomeFirstResponder() -> Bool {
        super.becomeFirstResponder()
        return textField.becomeFirstResponder()
    }

    @discardableResult override func resignFirstResponder() -> Bool {
        super.resignFirstResponder()
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
        delegate?.didBeginEditing(in: self)
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        guard let delegate = delegate else { return true }
        return delegate.shouldReturn(in: self)
    }

    public func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
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
    static var textField: TextField {
        let textField = TextField(edgeInsets: DataEntry.Metric.TextField.Default.edgeInsets)
        textField.configureOnce()
        textField.cornerRadius = DataEntry.Metric.TextField.Default.cornerRadius
        textField.textInset = DataEntry.Metric.TextField.Default.textInset

        return textField
    }

    static var roundedTextField: TextField {
        let textField = TextField(edgeInsets: DataEntry.Metric.TextField.Rounded.edgeInsets)
        textField.configureOnce()
        textField.heightConstraint.constant = DataEntry.Metric.TextField.Rounded.height
        textField.cornerRadius = DataEntry.Metric.TextField.Rounded.cornerRadius
        textField.textInset = DataEntry.Metric.TextField.Rounded.textInset

        return textField
    }
}
