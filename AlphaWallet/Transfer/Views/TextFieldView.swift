//
//  TextFieldView.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 25.08.2020.
//

import UIKit
import AlphaWalletFoundation

class TextFieldView: UIView {

    static let contentInsets: UIEdgeInsets = {
        let bottomInset: CGFloat = ScreenChecker().isNarrowScreen ? 10 : 20
        let sideInset: CGFloat = ScreenChecker().isNarrowScreen ? 8 : 16

        return .init(top: 5, left: sideInset, bottom: bottomInset, right: sideInset)
    }()

    lazy var textField: TextField = {
        let textField: TextField = .textField
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.keyboardType = .decimalPad

        return textField
    }()

    var value: String {
        get {
            return textField.value
        } set {
            textField.value = newValue
        }
    }

    init() {
        super.init(frame: .zero)
        textField.statusLabel.setContentHuggingPriority(.required, for: .vertical)
        textField.statusLabel.setContentCompressionResistancePriority(.required, for: .vertical)

        let stackView = [
            textField.label,
            .spacer(height: 4),
            textField,
            .spacer(height: 4),
            textField.statusLabel
        ].asStackView(axis: .vertical)
        stackView.translatesAutoresizingMaskIntoConstraints = false

        addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.anchorsConstraint(to: self, edgeInsets: TextFieldView.contentInsets)
        ])
    }

    required init?(coder: NSCoder) {
        return nil
    }

    func configure(viewModel: TextFieldViewViewModel) {
        textField.isUserInteractionEnabled = viewModel.allowEditing
        textField.value = viewModel.value
        textField.label.attributedText = viewModel.attributedPlaceholder
        textField.label.isHidden = viewModel.shouldHidePlaceholder
        textField.keyboardType = viewModel.keyboardType
    }
}
