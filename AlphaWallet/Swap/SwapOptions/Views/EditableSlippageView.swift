//
//  EditableSlippageView.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 14.03.2022.
//

import UIKit
import Combine

class EditableSlippageView: UIControl {

    lazy var textField: TextField = {
        let textField = TextField()
        textField.configureOnce()
        textField.keyboardType = .decimalPad

        return textField
    }()

    private lazy var cancelable = Set<AnyCancellable>()

    init(viewModel: EditableSlippageViewModel) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        let stachView = [textField.label, textField].asStackView(spacing: 5)
        stachView.translatesAutoresizingMaskIntoConstraints = false

        addSubview(stachView)

        NSLayoutConstraint.activate([
            stachView.anchorsConstraint(to: self),
            textField.widthAnchor.constraint(equalToConstant: 80)
        ])

        configure(viewModel: viewModel)
    }

    required init?(coder: NSCoder) {
        return nil
    }

    func configure(viewModel: EditableSlippageViewModel) {
        textField.label.attributedText = viewModel.titleAttributedString
        textField.placeholder = viewModel.placeholderString
        textField.textField.text = viewModel.text

        viewModel.slippage(text: textField.textField.textPublisher)
            .sink { slippage in
                viewModel.set(slippage: slippage)
            }.store(in: &cancelable)

        viewModel
            .shouldResignActive
            .receive(on: RunLoop.main)
            .sink { [weak textField] _ in
                guard let target = textField else { return }
                target.resignFirstResponder()
            }.store(in: &cancelable)
    }
}
