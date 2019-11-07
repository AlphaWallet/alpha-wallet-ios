// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit
import Kingfisher

class FungibleTokenViewCell: UITableViewCell {
    static let identifier = "FungibleTokenViewCell"

    private let background = UIView()
    private let titleLabel = UILabel()
    private let blockchainLabel = UILabel()
    private let separator = UILabel()
    private let issuerLabel = UILabel()
    private let blockChainTagLabel = UILabel()
    private let cellSeparators = (top: UIView(), bottom: UIView())

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        contentView.addSubview(background)
        background.translatesAutoresizingMaskIntoConstraints = false

        cellSeparators.top.translatesAutoresizingMaskIntoConstraints = false
        cellSeparators.bottom.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(cellSeparators.top)
        contentView.addSubview(cellSeparators.bottom)

        let bottomRowStack = [blockchainLabel, separator, issuerLabel, UIView.spacerWidth(flexible: true)].asStackView(spacing: 15)

        blockChainTagLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        blockChainTagLabel.setContentHuggingPriority(.required, for: .horizontal)
        let titleRowStack = [titleLabel, blockChainTagLabel].asStackView(axis: .horizontal, spacing: 7, alignment: .center)
        let stackView = [
            titleRowStack,
            bottomRowStack,
        ].asStackView(axis: .vertical)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        background.addSubview(stackView)

        NSLayoutConstraint.activate([
            blockChainTagLabel.heightAnchor.constraint(equalToConstant: Screen.TokenCard.Metric.blockChainTagHeight),

            stackView.leadingAnchor.constraint(equalTo: background.leadingAnchor, constant: 21),
            stackView.trailingAnchor.constraint(equalTo: background.trailingAnchor, constant: -21),
            stackView.topAnchor.constraint(equalTo: background.topAnchor, constant: 16),
            stackView.bottomAnchor.constraint(lessThanOrEqualTo: background.bottomAnchor, constant: -16),

            cellSeparators.top.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            cellSeparators.top.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            cellSeparators.top.topAnchor.constraint(equalTo: contentView.topAnchor, constant: GroupedTable.Metric.cellSpacing),
            cellSeparators.top.heightAnchor.constraint(equalToConstant: GroupedTable.Metric.cellSeparatorHeight),

            cellSeparators.bottom.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            cellSeparators.bottom.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            cellSeparators.bottom.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            cellSeparators.bottom.heightAnchor.constraint(equalToConstant: GroupedTable.Metric.cellSeparatorHeight),

            background.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            background.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            background.topAnchor.constraint(equalTo: contentView.topAnchor, constant: GroupedTable.Metric.cellSpacing + GroupedTable.Metric.cellSeparatorHeight),
            background.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -GroupedTable.Metric.cellSeparatorHeight),
        ])
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(viewModel: FungibleTokenViewCellViewModel) {
        selectionStyle = .none
        backgroundColor = viewModel.backgroundColor

        background.backgroundColor = viewModel.contentsBackgroundColor

        contentView.backgroundColor = GroupedTable.Color.background

        titleLabel.textColor = viewModel.titleColor
        titleLabel.font = viewModel.titleFont
        titleLabel.text = "\(viewModel.amount) \(viewModel.title)"
        titleLabel.baselineAdjustment = .alignCenters

        blockChainTagLabel.textAlignment = viewModel.blockChainNameTextAlignment
        blockChainTagLabel.cornerRadius = viewModel.blockChainNameCornerRadius
        blockChainTagLabel.backgroundColor = viewModel.blockChainNameBackgroundColor
        blockChainTagLabel.textColor = viewModel.blockChainNameColor
        blockChainTagLabel.font = viewModel.blockChainNameFont
        blockChainTagLabel.text = viewModel.blockChainTag

        blockchainLabel.textColor = viewModel.subtitleColor
        blockchainLabel.font = viewModel.subtitleFont
        blockchainLabel.text = viewModel.blockChainName

        issuerLabel.textColor = viewModel.subtitleColor
        issuerLabel.font = viewModel.subtitleFont
        issuerLabel.text = viewModel.issuer

        separator.textColor = viewModel.subtitleColor
        separator.font = viewModel.subtitleFont
        separator.text = ""

        cellSeparators.top.backgroundColor = GroupedTable.Color.cellSeparator
        cellSeparators.bottom.backgroundColor = GroupedTable.Color.cellSeparator
    }
}
