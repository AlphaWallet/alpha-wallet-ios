// Copyright © 2018 Stormbird PTE. LTD.

import UIKit

class TransactionViewCell: UITableViewCell {
    private let background = UIView()
    private let statusImageView = UIImageView()
    private let titleLabel = UILabel()
    private let amountLabel = UILabel()
    private let subTitleLabel = UILabel()
    private let blockchainLabel = UILabel()
    private var leftEdgeConstraint: NSLayoutConstraint = .init()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        contentView.addSubview(background)
        background.translatesAutoresizingMaskIntoConstraints = false

        statusImageView.translatesAutoresizingMaskIntoConstraints = false
        statusImageView.contentMode = .scaleAspectFit

        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        subTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subTitleLabel.lineBreakMode = .byTruncatingMiddle

        amountLabel.textAlignment = .right
        amountLabel.translatesAutoresizingMaskIntoConstraints = false

        let leftStackView = [
            titleLabel,
            subTitleLabel,
        ].asStackView(axis: .vertical, distribution: .fillProportionally, spacing: 0)
        leftStackView.translatesAutoresizingMaskIntoConstraints = false

        blockchainLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        blockchainLabel.setContentHuggingPriority(.required, for: .vertical)
        let rightStackView = [
            amountLabel,
            blockchainLabel,
        ].asStackView(axis: .vertical, alignment: .trailing)
        rightStackView.translatesAutoresizingMaskIntoConstraints = false

        let stackView = [statusImageView, leftStackView, rightStackView].asStackView(spacing: 15)
        stackView.translatesAutoresizingMaskIntoConstraints = false

        statusImageView.setContentHuggingPriority(UILayoutPriority.defaultLow, for: .horizontal)
        subTitleLabel.setContentHuggingPriority(UILayoutPriority.defaultLow, for: .horizontal)
        titleLabel.setContentHuggingPriority(UILayoutPriority.defaultLow, for: .horizontal)

        amountLabel.setContentHuggingPriority(UILayoutPriority.required, for: .horizontal)
        stackView.setContentHuggingPriority(UILayoutPriority.required, for: .horizontal)

        background.addSubview(stackView)

        leftEdgeConstraint = stackView.leadingAnchor.constraint(equalTo: background.leadingAnchor, constant: StyleLayout.sideMargin)

        NSLayoutConstraint.activate([
            blockchainLabel.heightAnchor.constraint(equalToConstant: Screen.TokenCard.Metric.blockChainTagHeight),

            statusImageView.widthAnchor.constraint(lessThanOrEqualToConstant: 26),

            leftEdgeConstraint,
            stackView.trailingAnchor.constraint(equalTo: background.trailingAnchor, constant: -StyleLayout.sideMargin),
            stackView.topAnchor.constraint(equalTo: background.topAnchor, constant: 14),
            stackView.bottomAnchor.constraint(equalTo: background.bottomAnchor, constant: -14),
            background.topAnchor.constraint(equalTo: contentView.topAnchor),
            background.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            background.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            background.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10)
        ])
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(viewModel: TransactionRowCellViewModel) {
        selectionStyle = .none
        leftEdgeConstraint.constant = viewModel.leftMargin
        contentView.backgroundColor = Colors.clear
        backgroundColor = Colors.clear
        background.backgroundColor = viewModel.contentsBackgroundColor
        background.cornerRadius = 8
        background.layer.shadowColor = Colors.lightGray.cgColor
        background.layer.shadowRadius = 2
        background.layer.shadowOffset = .zero
        background.layer.shadowOpacity = 0.6
        
        statusImageView.image = viewModel.statusImage

        titleLabel.textColor = viewModel.titleTextColor
        titleLabel.text = viewModel.title
        titleLabel.font = viewModel.titleFont

        subTitleLabel.text = viewModel.subTitle
        subTitleLabel.textColor = viewModel.subTitleTextColor
        subTitleLabel.font = viewModel.subTitleFont

        blockchainLabel.textAlignment = viewModel.blockChainNameTextAlignment
        blockchainLabel.cornerRadius = viewModel.blockChainNameCornerRadius
        blockchainLabel.backgroundColor = viewModel.blockChainNameBackgroundColor
        blockchainLabel.textColor = viewModel.blockChainNameColor
        blockchainLabel.font = viewModel.blockChainNameFont
        blockchainLabel.text = viewModel.blockChainName

        amountLabel.attributedText = viewModel.amountAttributedString
        amountLabel.font = viewModel.amountFont

        backgroundColor = viewModel.backgroundColor
    }
}
