// Copyright © 2020 Stormbird PTE. LTD.

import UIKit

class DefaultActivityItemViewCell: UITableViewCell {
    private let background = UIView()
    private let tokenImageView = TokenImageView()
    private let stateImageView = UIImageView()
    private let titleLabel = UILabel()
    private let amountLabel = UILabel()
    private let subTitleLabel = UILabel()
    private let timestampLabel = UILabel()
    private var viewModel: DefaultActivityCellViewModel?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        contentView.addSubview(background)
        background.translatesAutoresizingMaskIntoConstraints = false

        tokenImageView.contentMode = .scaleAspectFit

        stateImageView.translatesAutoresizingMaskIntoConstraints = false
        stateImageView.contentMode = .scaleAspectFit

        subTitleLabel.lineBreakMode = .byTruncatingMiddle

        amountLabel.textAlignment = .right

        let leftStackView = [
            titleLabel,
            subTitleLabel,
        ].asStackView(axis: .vertical, distribution: .fillProportionally, spacing: 0)

        timestampLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        timestampLabel.setContentHuggingPriority(.required, for: .vertical)
        let rightStackView = [
            amountLabel,
            timestampLabel,
        ].asStackView(axis: .vertical, alignment: .trailing)

        let stackView = [tokenImageView, leftStackView, rightStackView].asStackView(spacing: 15)
        stackView.translatesAutoresizingMaskIntoConstraints = false

        tokenImageView.setContentHuggingPriority(UILayoutPriority.defaultLow, for: .horizontal)
        subTitleLabel.setContentHuggingPriority(UILayoutPriority.defaultLow, for: .horizontal)
        titleLabel.setContentHuggingPriority(UILayoutPriority.defaultLow, for: .horizontal)

        amountLabel.setContentHuggingPriority(UILayoutPriority.required, for: .horizontal)
        stackView.setContentHuggingPriority(UILayoutPriority.required, for: .horizontal)

        background.addSubview(stackView)
        background.addSubview(stateImageView)

        NSLayoutConstraint.activate([
            timestampLabel.heightAnchor.constraint(equalToConstant: 20),

            tokenImageView.heightAnchor.constraint(equalToConstant: 40),
            tokenImageView.widthAnchor.constraint(equalToConstant: 40),

            stateImageView.heightAnchor.constraint(equalToConstant: 16),
            stateImageView.widthAnchor.constraint(equalToConstant: 16),
            stateImageView.trailingAnchor.constraint(equalTo: tokenImageView.trailingAnchor, constant: -2),
            stateImageView.bottomAnchor.constraint(equalTo: tokenImageView.bottomAnchor, constant: -2),

            stackView.anchorsConstraint(to: background, edgeInsets: .init(top: 14, left: StyleLayout.sideMargin, bottom: 14, right: StyleLayout.sideMargin)),

            background.anchorsConstraint(to: contentView),

            contentView.heightAnchor.constraint(equalToConstant: 80)
        ])
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(viewModel: DefaultActivityCellViewModel) {
        self.viewModel = viewModel

        selectionStyle = .none
        background.backgroundColor = viewModel.contentsBackgroundColor

        backgroundColor = viewModel.backgroundColor

        titleLabel.textColor = viewModel.titleTextColor
        titleLabel.attributedText = viewModel.title

        subTitleLabel.text = viewModel.subTitle
        subTitleLabel.textColor = viewModel.subTitleTextColor
        subTitleLabel.font = viewModel.subTitleFont

        timestampLabel.textAlignment = viewModel.timestampTextAlignment
        timestampLabel.textColor = viewModel.timestampColor
        timestampLabel.font = viewModel.timestampFont
        timestampLabel.text = viewModel.timestamp

        amountLabel.text = viewModel.amount
        amountLabel.font = viewModel.amountFont
        amountLabel.textColor = viewModel.amountColor

        tokenImageView.subscribable = viewModel.iconImage
        stateImageView.image = viewModel.stateImage
    }
}
