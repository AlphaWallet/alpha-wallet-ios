//
//  EditableSlippageView.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 14.03.2022.
//

import UIKit
import Combine

final class EditableSlippageView: UIControl {

    private lazy var textField: TextField = {
        let textField: TextField = .roundedTextField
        textField.keyboardType = .decimalPad
        textField.textField.textAlignment = .center

        return textField
    }()

    private var cancelable = Set<AnyCancellable>()
    private let viewModel: EditableSlippageViewModel

    init(viewModel: EditableSlippageViewModel) {
        self.viewModel = viewModel
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        let stachView = [textField.label, textField].asStackView(spacing: 5)
        stachView.translatesAutoresizingMaskIntoConstraints = false

        addSubview(stachView)
        NSLayoutConstraint.activate([
            stachView.anchorsConstraint(to: self),
            textField.widthAnchor.constraint(equalToConstant: 70)
        ])

        bind(viewModel: viewModel)
    }

    required init?(coder: NSCoder) {
        return nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        textField.textField.cornerRadius = DataEntry.Metric.TextField.Rounded.cornerRadius
    }

    private func bind(viewModel: EditableSlippageViewModel) {
        textField.label.attributedText = viewModel.titleAttributedString
        textField.placeholder = viewModel.placeholderString
        textField.textField.text = viewModel.text

        let input = EditableSlippageViewModelInput(text: textField.textField.textPublisher)
        let output = viewModel.transform(input: input)

        output.shouldResignActive
            .sink { [weak textField] _ in
                guard let target = textField else { return }
                target.resignFirstResponder()
            }.store(in: &cancelable)
    }
}
