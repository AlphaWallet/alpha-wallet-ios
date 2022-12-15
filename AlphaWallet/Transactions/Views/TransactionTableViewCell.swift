// Copyright © 2018 Stormbird PTE. LTD.

import UIKit

class TransactionTableViewCell: UITableViewCell {
    private let background = UIView()
    private let statusImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        imageView.setContentHuggingPriority(UILayoutPriority.defaultLow, for: .horizontal)

        return imageView
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = Fonts.regular(size: ScreenChecker.size(big: 17, medium: 17, small: 15))
        label.textColor = Configuration.Color.Semantic.defaultForegroundText
        label.setContentHuggingPriority(UILayoutPriority.defaultLow, for: .horizontal)

        return label
    }()

    private let amountLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .right
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        label.setContentHuggingPriority(.required, for: .horizontal)

        return label
    }()

    private let subTitleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.lineBreakMode = .byTruncatingMiddle
        label.textColor = Configuration.Color.Semantic.defaultSubtitleText
        label.font = Fonts.regular(size: ScreenChecker.size(big: 13, medium: 13, small: 12))

        return label
    }()

    private let blockchainLabel: BlockchainTagLabel = {
        let label = BlockchainTagLabel()
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        label.setContentHuggingPriority(.required, for: .horizontal)
        label.setContentHuggingPriority(.required, for: .vertical)

        return label
    }()
    private var leftEdgeConstraint: NSLayoutConstraint = .init()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        contentView.addSubview(background)
        background.translatesAutoresizingMaskIntoConstraints = false

        let leftStackView = [
            titleLabel,
            subTitleLabel,
        ].asStackView(axis: .vertical, distribution: .fillProportionally, spacing: 0)
        leftStackView.translatesAutoresizingMaskIntoConstraints = false

        let rightStackView = [
            amountLabel,
            blockchainLabel,
        ].asStackView(axis: .vertical, alignment: .trailing)
        rightStackView.translatesAutoresizingMaskIntoConstraints = false

        let stackView = [statusImageView, leftStackView, rightStackView].asStackView(spacing: ScreenChecker.size(big: 15, medium: 15, small: 10))
        stackView.translatesAutoresizingMaskIntoConstraints = false

        stackView.setContentHuggingPriority(UILayoutPriority.required, for: .horizontal)

        background.addSubview(stackView)

        leftEdgeConstraint = stackView.leadingAnchor.constraint(equalTo: background.leadingAnchor, constant: DataEntry.Metric.sideMargin)

        NSLayoutConstraint.activate([
            statusImageView.widthAnchor.constraint(lessThanOrEqualToConstant: ScreenChecker.size(big: 26, medium: 26, small: 20)),
            amountLabel.widthAnchor.constraint(lessThanOrEqualTo: background.widthAnchor, multiplier: 0.5),
            leftEdgeConstraint,
            stackView.trailingAnchor.constraint(equalTo: background.trailingAnchor, constant: -DataEntry.Metric.sideMargin),
            stackView.topAnchor.constraint(equalTo: background.topAnchor, constant: ScreenChecker.size(big: 15, medium: 15, small: 10)),
            stackView.bottomAnchor.constraint(equalTo: background.bottomAnchor, constant: -ScreenChecker.size(big: 15, medium: 15, small: 10)),

            background.anchorsConstraint(to: contentView),
        ])
        backgroundColor = Configuration.Color.Semantic.defaultViewBackground
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        background.layer.cornerRadius = DataEntry.Metric.CornerRadius.box
    }

    func configure(viewModel: TransactionRowCellViewModel) {
        selectionStyle = .none
        leftEdgeConstraint.constant = viewModel.leftMargin
        background.backgroundColor = viewModel.contentsBackgroundColor
        statusImageView.image = viewModel.statusImage
        titleLabel.text = viewModel.title
        subTitleLabel.text = viewModel.subTitle
        blockchainLabel.configure(viewModel: viewModel.blockchainTagLabelViewModel)
        amountLabel.attributedText = viewModel.amountAttributedString
    }
}
