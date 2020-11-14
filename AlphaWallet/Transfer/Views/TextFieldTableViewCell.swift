//
//  TextFieldTableViewCell.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 25.08.2020.
//

import UIKit

class TextFieldTableViewCell: UITableViewCell {

    static let contentInsets: UIEdgeInsets = {
        let bottomInset: CGFloat = ScreenChecker().isNarrowScreen ? 10 : 20
        let sideInset: CGFloat = ScreenChecker().isNarrowScreen ? 8 : 16

        return .init(top: 0, left: sideInset, bottom: bottomInset, right: sideInset)
    }()

    lazy var textField: TextField = {
        let textField = TextField()
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

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none

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

        contentView.addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.anchorsConstraint(to: contentView, edgeInsets: TextFieldTableViewCell.contentInsets)
        ])

        textField.configureOnce()
    }

    required init?(coder: NSCoder) {
        return nil
    }

    func configure(viewModel: TextFieldTableViewCellViewModel) {
        textField.isUserInteractionEnabled = viewModel.allowEditing
        textField.value = viewModel.value
        textField.label.attributedText = viewModel.attributedPlaceholder
        textField.label.isHidden = viewModel.shouldHidePlaceholder
        textField.keyboardType = viewModel.keyboardType
    }
}
