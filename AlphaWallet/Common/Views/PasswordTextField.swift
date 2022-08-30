//
//  PasswordTextField.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 20.01.2022.
//

import UIKit

class PasswordTextField: TextField {

    private lazy var button: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.frame = CGRect(x: 0.0, y: 0.0, width: 24.0, height: 24.0)
        button.setImage(R.image.togglePassword(), for: .normal)

        return button
    }()

    override init(edgeInsets: UIEdgeInsets = DataEntry.Metric.TextField.Default.edgeInsets) {
        super.init(edgeInsets: edgeInsets)

        isSecureTextEntry = true
        button.addTarget(self, action: #selector(toggleMaskPassword), for: .touchUpInside)

        let buttonFrame = UIView(frame: CGRect(x: 0.0, y: 0.0, width: 30.0, height: 30.0))
        buttonFrame.translatesAutoresizingMaskIntoConstraints = false
        buttonFrame.addSubview(button)

        NSLayoutConstraint.activate([
            buttonFrame.heightAnchor.constraint(equalToConstant: 32.0),
            buttonFrame.widthAnchor.constraint(equalToConstant: 32.0),
            buttonFrame.centerYAnchor.constraint(equalTo: button.centerYAnchor),
            buttonFrame.centerXAnchor.constraint(equalTo: button.centerXAnchor),

            button.widthAnchor.constraint(equalToConstant: 24.0),
            button.heightAnchor.constraint(equalToConstant: 24.0),
        ])

        textField.rightViewMode = .always
        textField.rightView = buttonFrame

        configureTintColor()
    }

    private func configureTintColor() {
        if isSecureTextEntry {
            button.tintColor = Colors.navigationTitleColor
        } else {
            button.tintColor = .init(red: 111, green: 111, blue: 111)
        }
    }

    required init?(coder aDecoder: NSCoder) {
        return nil
    }

    @objc private func toggleMaskPassword() {
        isSecureTextEntry.toggle()
        configureTintColor()
    }
}
