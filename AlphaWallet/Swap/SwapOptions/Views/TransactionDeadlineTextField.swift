//
//  TransactionDeadlineTextField.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 14.03.2022.
//

import UIKit
import Combine

class TransactionDeadlineTextField: UIControl {

    private lazy var textField: TextField = {
        let textField = TextField()
        textField.configureOnce()
        textField.heightConstraint.constant = 40
        textField.textField.textAlignment = .right
        textField.keyboardType = .decimalPad

        return textField
    }()

    var textPublisher: AnyPublisher<String?, Never> {
        return textField.textField.textPublisher
    }

    init(viewModel: TransactionDeadlineTextFieldModel) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        let stachView = [textField, textField.label].asStackView(axis: .horizontal, spacing: 5)
        stachView.translatesAutoresizingMaskIntoConstraints = false

        addSubview(stachView)

        NSLayoutConstraint.activate([
            stachView.anchorsConstraint(to: self),
            textField.widthAnchor.constraint(equalToConstant: 70)
        ])

        configure(viewModel: viewModel)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func configure(viewModel: TransactionDeadlineTextFieldModel) {
        textField.placeholder = viewModel.placeholderString
        textField.label.attributedText = viewModel.titleAttributedString
        textField.value = viewModel.valueString
    }
}
