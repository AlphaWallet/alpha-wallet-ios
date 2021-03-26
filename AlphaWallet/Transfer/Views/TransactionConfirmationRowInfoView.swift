//
//  TransactionConfirmationRowInfoView.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 17.07.2020.
//

import UIKit

class TransactionConfirmationRowInfoView: UIView {

    private let titleLabel: UILabel = {
        let titleLabel = UILabel(frame: .zero)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = Fonts.regular(size: ScreenChecker().isNarrowScreen ? 16 : 18)
        titleLabel.textAlignment = .left
        titleLabel.textColor = Colors.darkGray

        return titleLabel
    }()

    init(viewModel: TransactionRowInfoTableViewCellViewModel) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        let stackView = [
            titleLabel,
        ].asStackView(axis: .vertical)

        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.isLayoutMarginsRelativeArrangement = true

        addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.anchorsConstraint(to: self, edgeInsets: Screen.TransactionConfirmation.transactionRowInfoInsets),
        ])

        configure(viewModel: viewModel)
    }

    required init?(coder aDecoder: NSCoder) {
        return nil
    }

    private func configure(viewModel: TransactionRowInfoTableViewCellViewModel) {
        titleLabel.text = viewModel.title
    }
}

struct TransactionRowInfoTableViewCellViewModel {
    let title: String
    let subtitle: String?
}

