// Copyright © 2018 Stormbird PTE. LTD.

import UIKit

protocol TextFieldDelegate: class {
    func shouldReturn(in textField: TextField) -> Bool
    func doneButtonTapped(for textField: TextField)
    func nextButtonTapped(for textField: TextField)
    func shouldChangeCharacters(inRange range: NSRange, replacementString string: String, for textField: TextField) -> Bool
}

extension TextFieldDelegate {
    func shouldChangeCharacters(inRange range: NSRange, replacementString string: String, for textField: TextField) -> Bool {
        return true
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
            default:
                return whileEditing
            }
        }
    }
    
    private var isConfigured = false

    var returnKeyType: UIReturnKeyType {
        get {
            return textField.returnKeyType
        }
        set {
            textField.returnKeyType = newValue
        }
    }

    var keyboardType: UIKeyboardType {
        get {
            return textField.keyboardType
        }
        set {
            textField.keyboardType = newValue
        }
    }

    public var isSecureTextEntry: Bool {
        get {
            return textField.isSecureTextEntry
        }
        set {
            textField.isSecureTextEntry = newValue
        }
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
        let textField = UITextField()
        textField.translatesAutoresizingMaskIntoConstraints = false
        
        return textField
    }()
    
    weak var delegate: TextFieldDelegate?

    var value: String {
        get {
            return textField.text ?? ""
        }
        set {
            textField.text = newValue
        }
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
            
            let borderColor = status.textFieldBorderColor(whileEditing: isFirstResponder)
            let shouldDropShadow = status.textFieldShowShadow(whileEditing: isFirstResponder)
            
            layer.borderColor = borderColor.cgColor
            
            dropShadow(color: shouldDropShadow ? borderColor : .clear, radius: DataEntry.Metric.shadowRadius)
        }
    }

    var inputAccessoryButtonType = InputAccessoryButtonType.none {
        didSet {
            switch inputAccessoryButtonType {
            case .done:
                textField.inputAccessoryView = makeToolbarWithDoneButton()
            case .next:
                textField.inputAccessoryView = makeToolbarWithNextButton()
            case .none:
                textField.inputAccessoryView = nil
            }
        }
    }

    init() {
        super.init(frame: .zero)

        translatesAutoresizingMaskIntoConstraints = false

        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.delegate = self
        textField.leftViewMode = .always
        textField.rightViewMode = .always
        addSubview(textField)

        NSLayoutConstraint.activate([
            textField.anchorsConstraint(to: self, edgeInsets: DataEntry.Metric.textFieldInsets),

            heightAnchor.constraint(equalToConstant: ScreenChecker().isNarrowScreen ? 30 : 50),
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
        
        textField.textColor = DataEntry.Color.text
        textField.font = DataEntry.Font.textField
        
        layer.borderWidth = DataEntry.Metric.borderThickness
        backgroundColor = DataEntry.Color.textFieldBackground
        layer.borderColor = status.textFieldBorderColor(whileEditing: isFirstResponder).cgColor
        status = .none
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func makeToolbarWithDoneButton() -> UIToolbar {
        //Frame needed, but actual values aren't that important
        let toolbar = UIToolbar(frame: CGRect(x: 0, y: 0, width: 100, height: 40))
        toolbar.barStyle = .default

        let flexSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let done = UIBarButtonItem(title: R.string.localizable.done(), style: .done, target: self, action: #selector(doneButtonTapped))

        toolbar.items = [flexSpace, done]
        toolbar.sizeToFit()

        return toolbar
    }

    private func makeToolbarWithNextButton() -> UIToolbar {
        //Frame needed, but actual values aren't that important
        let toolbar = UIToolbar(frame: CGRect(x: 0, y: 0, width: 100, height: 40))
        toolbar.barStyle = .default

        let flexSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let next = UIBarButtonItem(title: R.string.localizable.next(), style: .plain, target: self, action: #selector(nextButtonTapped))
        toolbar.items = [flexSpace, next]
        toolbar.sizeToFit()

        return toolbar
    }

    @objc func doneButtonTapped() {
        delegate?.doneButtonTapped(for: self)
    }

    @objc func nextButtonTapped() {
        delegate?.nextButtonTapped(for: self)
    }

    override func becomeFirstResponder() -> Bool {
        super.becomeFirstResponder()
        return textField.becomeFirstResponder()
    }
}

extension TextField: UITextFieldDelegate {
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        let borderColor = status.textFieldBorderColor(whileEditing: false)
        let shouldDropShadow = status.textFieldShowShadow(whileEditing: false)
        layer.borderColor = borderColor.cgColor
        backgroundColor = DataEntry.Color.textFieldBackground
        
        dropShadow(color: shouldDropShadow ? borderColor : .clear, radius: DataEntry.Metric.shadowRadius)
    }
    
    func textFieldDidBeginEditing(_ textField: UITextField) {
        let borderColor = status.textFieldBorderColor(whileEditing: true)
        layer.borderColor = borderColor.cgColor
        backgroundColor = DataEntry.Color.textFieldBackgroundWhileEditing
        
        dropShadow(color: borderColor, radius: DataEntry.Metric.shadowRadius)
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        guard let delegate = delegate else { return true }
        return delegate.shouldReturn(in: self)
    }

    public func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        return delegate?.shouldChangeCharacters(inRange: range, replacementString: string, for: self) ?? true
    }
}
