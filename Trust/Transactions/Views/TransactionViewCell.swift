// Copyright SIX DAY LLC. All rights reserved.

import UIKit

class TransactionViewCell: UITableViewCell {

    static let identifier = "TransactionTableViewCell"

    let background = UIView()
    let statusImageView = UIImageView()
    let titleLabel = UILabel()
    let amountLabel = UILabel()
    let subTitleLabel = UILabel()

    override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
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

        let leftStackView = UIStackView(arrangedSubviews: [titleLabel, subTitleLabel])
        leftStackView.translatesAutoresizingMaskIntoConstraints = false
        leftStackView.axis = .vertical
        leftStackView.distribution = .fillProportionally
        leftStackView.spacing = 6

        let rightStackView = UIStackView(arrangedSubviews: [amountLabel])
        rightStackView.translatesAutoresizingMaskIntoConstraints = false
        rightStackView.axis = .vertical

        let stackView = UIStackView(arrangedSubviews: [statusImageView, leftStackView, rightStackView])
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .horizontal
        stackView.spacing = 15
        stackView.distribution = .fill

        statusImageView.setContentHuggingPriority(UILayoutPriority.defaultLow, for: .horizontal)
        subTitleLabel.setContentHuggingPriority(UILayoutPriority.defaultLow, for: .horizontal)
        titleLabel.setContentHuggingPriority(UILayoutPriority.defaultLow, for: .horizontal)

        amountLabel.setContentHuggingPriority(UILayoutPriority.required, for: .horizontal)
        stackView.setContentHuggingPriority(UILayoutPriority.required, for: .horizontal)

        background.addSubview(stackView)

        // TODO extract constant. Maybe StyleLayout.sideMargin
        let xMargin  = CGFloat(7)
        let yMargin  = CGFloat(7)
        NSLayoutConstraint.activate([
            statusImageView.widthAnchor.constraint(lessThanOrEqualToConstant: 44),
            stackView.topAnchor.constraint(equalTo: background.topAnchor, constant: StyleLayout.sideMargin),
            stackView.trailingAnchor.constraint(equalTo: background.trailingAnchor, constant: -StyleLayout.sideMargin),
            stackView.bottomAnchor.constraint(equalTo: background.bottomAnchor, constant: -StyleLayout.sideMargin),
            stackView.leadingAnchor.constraint(equalTo: background.leadingAnchor, constant: StyleLayout.sideMargin),

            background.leadingAnchor.constraint(equalTo: leadingAnchor, constant: xMargin),
            background.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -xMargin),
            background.topAnchor.constraint(equalTo: topAnchor, constant: yMargin),
            background.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -yMargin),
        ])
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(viewModel: TransactionCellViewModel) {
        selectionStyle = .none
        background.backgroundColor = viewModel.contentsBackgroundColor
        background.layer.cornerRadius = 20

        statusImageView.image = viewModel.statusImage

        titleLabel.text = viewModel.title
        titleLabel.font = viewModel.titleFont

        subTitleLabel.text = viewModel.subTitle
        subTitleLabel.textColor = viewModel.subTitleTextColor
        subTitleLabel.font = viewModel.subTitleFont

        amountLabel.attributedText = viewModel.amountAttributedString
        amountLabel.font = viewModel.amountFont

        backgroundColor = viewModel.backgroundColor
    }
}
