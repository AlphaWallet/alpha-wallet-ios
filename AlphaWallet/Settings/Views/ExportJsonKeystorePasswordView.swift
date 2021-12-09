//
//  ExportJsonKeystorePasswordView.swift
//  AlphaWallet
//
//  Created by Jerome Chan on 1/12/21.
//

import UIKit

class ExportJsonKeystorePasswordView: UIView {
    private lazy var label: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.adjustsFontForContentSizeCategory = true
        label.backgroundColor = R.color.white()!
        label.font = UIFontMetrics(forTextStyle: .subheadline).scaledFont(for: Fonts.regular(size: 13.0))
        label.textColor = R.color.dove()!
        label.text = R.string.localizable.settingsAdvancedExportJSONKeystorePasswordLabel()
        label.heightAnchor.constraint(equalToConstant: 22.0).isActive = true
        return label
    }()
    lazy var passwordTextField: UITextField = {
        let textField: UITextField = UITextField()
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.adjustsFontForContentSizeCategory = true
        textField.backgroundColor = R.color.white()!
        textField.font = UIFontMetrics(forTextStyle: .body).scaledFont(for: Fonts.regular(size: 17.0))
        textField.textColor = R.color.mine()!
        textField.borderStyle = .roundedRect
        textField.isSecureTextEntry = true
        textField.placeholder = R.string.localizable.enterPasswordPasswordTextFieldPlaceholder()
        textField.autocorrectionType = .no
        textField.spellCheckingType = .no
        _ = textField.heightAnchor.constraint(equalToConstant: 50.0).isActive = true
        textField.borderColor = R.color.azure()
        textField.borderWidth = 1.0
        textField.layer.cornerRadius = 5.0
        textField.returnKeyType = .done
        textField.spellCheckingType = .no
        textField.autocorrectionType = .no
        return textField
    }()
    private let buttonsBar = ButtonsBar(configuration: .green(buttons: 1))

    var bottomConstraint: NSLayoutConstraint?

    convenience init() {
        self.init(frame: .zero)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureView()
    }

    required init?(coder: NSCoder) {
        return nil
    }

    func addExportButtonTarget(_ target: Any?, action: Selector) {
        let button = buttonsBar.buttons[0]
        button.removeTarget(target, action: action, for: .touchUpInside)
        button.addTarget(target, action: action, for: .touchUpInside)
    }

    func setButton(title: String) {
        buttonsBar.buttons[0].setTitle(title, for: .normal)
    }

    func enableButton() {
        buttonsBar.buttons[0].isEnabled = true
    }

    func disableButton() {
        buttonsBar.buttons[0].isEnabled = false
    }

    private func configureView() {
        backgroundColor = R.color.white()!
        configureTapToDismissKeyboard()
        configurePasswordTextField()
        let footerBar = configureButtonsBar()
        footerBar.backgroundColor = R.color.white()
        addSubview(label)
        addSubview(passwordTextField)
        addSubview(footerBar)
        bottomConstraint = footerBar.bottomAnchor.constraint(equalTo: self.bottomAnchor)
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: topAnchor, constant: 34.0),
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16.0),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16.0),
            label.bottomAnchor.constraint(equalTo: passwordTextField.topAnchor, constant: -4.0),

            passwordTextField.leadingAnchor.constraint(equalTo: label.leadingAnchor),
            passwordTextField.trailingAnchor.constraint(equalTo: label.trailingAnchor),
            passwordTextField.bottomAnchor.constraint(lessThanOrEqualTo: footerBar.topAnchor, constant: -4.0),

            footerBar.leadingAnchor.constraint(equalTo: leadingAnchor),
            footerBar.trailingAnchor.constraint(equalTo: trailingAnchor),
            bottomConstraint!
        ])
    }

    private func configurePasswordTextField() {
        let buttonFrame = UIView(frame: CGRect(x: 0.0, y: 0.0, width: 30.0, height: 30.0))
        buttonFrame.translatesAutoresizingMaskIntoConstraints = false
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.frame = CGRect(x: 0.0, y: 0.0, width: 24.0, height: 24.0)
        button.setImage(R.image.togglePassword(), for: .normal)
        button.tintColor = .init(red: 111, green: 111, blue: 111)
        button.addTarget(self, action: #selector(toggleMaskPassword), for: .touchUpInside)
        buttonFrame.addSubview(button)
        NSLayoutConstraint.activate([
            buttonFrame.heightAnchor.constraint(equalToConstant: 32.0),
            buttonFrame.widthAnchor.constraint(equalToConstant: 32.0),
            buttonFrame.centerYAnchor.constraint(equalTo: button.centerYAnchor),
            button.widthAnchor.constraint(equalToConstant: 24.0),
            button.heightAnchor.constraint(equalToConstant: 24.0),
            buttonFrame.leadingAnchor.constraint(equalTo: button.leadingAnchor),
        ])
        passwordTextField.rightViewMode = .always
        passwordTextField.rightView = buttonFrame
    }

    private func configureButtonsBar() -> ButtonsBarBackgroundView {
        buttonsBar.configure()
        let edgeInsets = UIEdgeInsets(top: 16.0, left: 0.0, bottom: 16.0, right: 0.0)
        let footerBar = ButtonsBarBackgroundView(buttonsBar: buttonsBar, edgeInsets: edgeInsets, separatorHeight: 1.0)
        return footerBar
    }

    @objc private func toggleMaskPassword() {
        passwordTextField.isSecureTextEntry = !passwordTextField.isSecureTextEntry
        guard let button = passwordTextField.rightView as? UIButton else { return }
        if passwordTextField.isSecureTextEntry {
            button.tintColor = Colors.navigationTitleColor
        } else {
            button.tintColor = .init(red: 111, green: 111, blue: 111)
        }
    }

    private func configureTapToDismissKeyboard() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        self.addGestureRecognizer(tap)
    }

    @objc private func handleTap(_ sender: Any) {
        endEditing(true)
    }
}
