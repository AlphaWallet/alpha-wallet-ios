//
//  TransactionConfirmationRowInfoView.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 17.07.2020.
//

import UIKit
import AlphaWalletFoundation

class TransactionConfirmationRowInfoView: UIView {

    private let titleLabel: UILabel = {
        let titleLabel = UILabel(frame: .zero)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = Fonts.regular(size: ScreenChecker().isNarrowScreen ? 16 : 18)
        titleLabel.textAlignment = .left
        titleLabel.textColor = Colors.darkGray

        return titleLabel
    }()

    private let subTitleLabel: UILabel = {
        let subTitleLabel = UILabel(frame: .zero)
        subTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subTitleLabel.textAlignment = .left
        subTitleLabel.textColor = Colors.black
        subTitleLabel.font = Fonts.regular(size: ScreenChecker().isNarrowScreen ? 13 : 15)
        subTitleLabel.numberOfLines = 0

        return subTitleLabel
    }()

    init(viewModel: TransactionConfirmationRowInfoViewModel) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        let stackView = [
            titleLabel,
            subTitleLabel,
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

    private func configure(viewModel: TransactionConfirmationRowInfoViewModel) {
        titleLabel.text = viewModel.title
        subTitleLabel.text = viewModel.subtitle
        subTitleLabel.isHidden = viewModel.isSubtitleHidden
    }
}

struct TransactionConfirmationRowInfoViewModel {
    let title: String
    let subtitle: String?
    var isSubtitleHidden: Bool { subtitle?.trimmed.isEmpty ?? true }
}
