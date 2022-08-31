// Copyright © 2021 Stormbird PTE. LTD.

import UIKit
import AlphaWalletFoundation

class TransactionConfirmationRowDescriptionView: UIView {
    private let titleLabel: UILabel = {
        let titleLabel = UILabel(frame: .zero)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = Fonts.regular(size: ScreenChecker().isNarrowScreen ? 16 : 18)
        titleLabel.textAlignment = .center
        titleLabel.textColor = R.color.mine()

        return titleLabel
    }()

    init(viewModel: TransactionRowDescriptionTableViewCellViewModel) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        let separatorLine = UIView()
        separatorLine.backgroundColor = R.color.mercury()

        let row0 = separatorLine
        let row1 = [.spacerWidth(Screen.TransactionConfirmation.transactionRowInfoInsets.left), titleLabel, .spacerWidth(Screen.TransactionConfirmation.transactionRowInfoInsets.right)].asStackView(axis: .horizontal)

        let stackView = [
            row0,
            .spacer(height: 20),
            row1,
            .spacer(height: 40),
        ].asStackView(axis: .vertical)

        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.isLayoutMarginsRelativeArrangement = true

        addSubview(stackView)

        NSLayoutConstraint.activate([
            separatorLine.heightAnchor.constraint(equalToConstant: 1),

            stackView.anchorsConstraint(to: self),
        ])

        configure(viewModel: viewModel)
    }

    required init?(coder aDecoder: NSCoder) {
        return nil
    }

    private func configure(viewModel: TransactionRowDescriptionTableViewCellViewModel) {
        titleLabel.numberOfLines = 0
        titleLabel.text = viewModel.title
    }
}

struct TransactionRowDescriptionTableViewCellViewModel {
    let title: String
}

