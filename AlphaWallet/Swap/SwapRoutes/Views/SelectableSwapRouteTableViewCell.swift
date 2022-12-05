//
//  SelectableSwapRouteTableViewCell.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 22.09.2022.
//

import UIKit

final class SelectableSwapRouteTableViewCell: UITableViewCell {

    private let exchangeTextLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.setContentHuggingPriority(.defaultHigh, for: .vertical)

        return label
    }()

    private let amountTextLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.setContentHuggingPriority(.defaultHigh, for: .vertical)

        return label
    }()

    private let tagTextLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.setContentHuggingPriority(.defaultHigh, for: .vertical)

        return label
    }()

    private lazy var serverImageView: RoundedImageView = {
        let iconView = RoundedImageView(size: DataEntry.Metric.ImageView.serverIconSize)
        return iconView
    }()

    private let accessoryImageView: UIImageView = {
        let view = UIImageView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private lazy var bottomStackView = [UIView]().asStackView(axis: .vertical, spacing: 5)

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        let stackView = [
            exchangeTextLabel,
            amountTextLabel,
            bottomStackView
        ].asStackView(axis: .vertical, alignment: .leading)
        stackView.translatesAutoresizingMaskIntoConstraints = false

        addSubview(serverImageView)
        addSubview(stackView)
        addSubview(tagTextLabel)
        addSubview(accessoryImageView)

        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 15),
            stackView.trailingAnchor.constraint(equalTo: accessoryImageView.trailingAnchor, constant: 0),
            stackView.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10),

            exchangeTextLabel.heightAnchor.constraint(equalToConstant: 27),
            amountTextLabel.heightAnchor.constraint(equalToConstant: 40),
            serverImageView.centerYAnchor.constraint(equalTo: amountTextLabel.centerYAnchor, constant: 0),
            serverImageView.leadingAnchor.constraint(equalTo: amountTextLabel.trailingAnchor, constant: 5),
            tagTextLabel.leadingAnchor.constraint(equalTo: exchangeTextLabel.trailingAnchor, constant: 5),
            tagTextLabel.centerYAnchor.constraint(equalTo: exchangeTextLabel.centerYAnchor, constant: -5),

            accessoryImageView.widthAnchor.constraint(equalToConstant: 30.0),
            accessoryImageView.heightAnchor.constraint(equalToConstant: 30.0),
            accessoryImageView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -15.0),
            accessoryImageView.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    func configure(viewModel: SelectableSwapRouteTableViewCellViewModel) {
        selectionStyle = viewModel.selectionStyle
        backgroundColor = Configuration.Color.Semantic.tableViewCellBackground
        accessoryImageView.image = viewModel.accessoryImage
        serverImageView.image = viewModel.tokenRpcServerImage
        exchangeTextLabel.attributedText = viewModel.swapViaExchangeAttributedString
        amountTextLabel.attributedText = viewModel.amountAttributedString
        tagTextLabel.attributedText = viewModel.tagAttributedString

        bottomStackView.removeAllArrangedSubviews()
        let subViews: [UIView] = viewModel.feesAttributedStrings.map { fee in
            let label = UILabel()
            label.attributedText = fee

            return label
        }

        bottomStackView.addArrangedSubviews(subViews)
    }
}
