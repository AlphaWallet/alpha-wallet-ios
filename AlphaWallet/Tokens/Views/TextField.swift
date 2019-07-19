// Copyright © 2018 Stormbird PTE. LTD.

import UIKit

protocol TextFieldDelegate: class {
    func shouldReturn(in textField: TextField) -> Bool
    func doneButtonTapped(for textField: TextField)
    func nextButtonTapped(for textField: TextField)
}

class TextField: UIControl {
    enum InputAccessoryButtonType {
        case done
        case next
        case none
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

    let label = UILabel()
    let textField = UITextField()
    weak var delegate: TextFieldDelegate?

    var value: String {
        get {
            return textField.text ?? ""
        }
        set {
            textField.text = newValue
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
            textField.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 22),
            textField.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -22),
            textField.topAnchor.constraint(equalTo: topAnchor),
            textField.bottomAnchor.constraint(equalTo: bottomAnchor),
            heightAnchor.constraint(equalToConstant: ScreenChecker().isNarrowScreen ? 30 : 50),
        ])
    }

    func configureOnce() {
        guard !isConfigured else { return }
        isConfigured = true

        label.font = Fonts.regular(size: 10)!
        label.textColor = Colors.appGrayLabelColor

        textField.textColor = Colors.appBackground
        textField.font = Fonts.bold(size: 21)
        layer.borderColor = Colors.appBackground.cgColor
        layer.borderWidth = 1
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        roundCornersBasedOnHeight()
    }

    private func roundCornersBasedOnHeight() {
        layer.cornerRadius = frame.size.height / 2
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
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        guard let delegate = delegate else { return true }
        return delegate.shouldReturn(in: self)
    }
}
