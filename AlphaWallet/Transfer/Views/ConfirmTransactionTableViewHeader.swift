//
//  TransactionConfirmationTableViewHeader.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 10.07.2020.
//

import UIKit

class TransactionConfirmationTableViewHeader: UITableViewHeaderFooterView {

    private let placeholderLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 0
        return label
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 0
        return label
    }()

    private let detailsLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 0
        return label
    }()

    private var viewModel: TransactionConfirmationTableViewHeaderViewModel?

    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)

        let separatorLine = UIView()
        separatorLine.translatesAutoresizingMaskIntoConstraints = false
        separatorLine.backgroundColor = R.color.mercury()

        let row0 = [
            .spacerWidth(16),
            placeholderLabel,
            [titleLabel, detailsLabel].asStackView(axis: .vertical),
            .spacerWidth(16)
        ].asStackView(axis: .horizontal)

        let stackView = [
            separatorLine,
            .spacer(height: 20),
            row0,
            .spacer(height: 20)
        ].asStackView(axis: .vertical)

        stackView.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(stackView)

        NSLayoutConstraint.activate([
            placeholderLabel.widthAnchor.constraint(equalToConstant: 100),
            separatorLine.heightAnchor.constraint(equalToConstant: 1),
            stackView.anchorsConstraint(to: contentView)
        ])
    }

    required init?(coder: NSCoder) {
        return nil
    }

    func configure(viewModel: TransactionConfirmationTableViewHeaderViewModel) {
        self.viewModel = viewModel

        contentView.backgroundColor = viewModel.backgoundColor
        backgroundColor = viewModel.backgoundColor

        titleLabel.text = viewModel.title
        titleLabel.font = viewModel.titleLabelFont
        titleLabel.textColor = viewModel.titleLabelColor

        placeholderLabel.text = viewModel.placeholder
        placeholderLabel.font = viewModel.placeholderLabelFont
        placeholderLabel.textColor = viewModel.placeholderLabelColor

        detailsLabel.text = viewModel.details
        detailsLabel.font = viewModel.detailsLabelFont
        detailsLabel.textColor = viewModel.detailsLabelColor
    }
}
