// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit
import Kingfisher

class NonFungibleTokenViewCell: UITableViewCell {
    static let identifier = "NonFugibleTokenViewCell"

    private let background = UIView()
    private let titleLabel = UILabel()
    private let blockchainLabel = UILabel()
    private let separator = UILabel()
    private let issuerLabel = UILabel()
    private let blockChainTagLabel = UILabel()
    private lazy var cellSeparators = UITableViewCell.createTokenCellSeparators(height: GroupedTable.Metric.cellSpacing, separatorHeight: GroupedTable.Metric.cellSeparatorHeight)
    private var viewsWithContent: [UIView] {
        [self.titleLabel, self.blockchainLabel, self.issuerLabel, blockChainTagLabel]
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        contentView.addSubview(background)
        background.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(cellSeparators.topBar)
        contentView.addSubview(cellSeparators.bottomLine)

        //TODO write snapshot test to ensure separator + issueLabel is positioned correctly, in particular. Doesn't display at the right edge of the screen. Do it for every cell class used in TokensViewController
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

            cellSeparators.topBar.leadingAnchor.constraint(equalTo: leadingAnchor),
            cellSeparators.topBar.trailingAnchor.constraint(equalTo: trailingAnchor),
            cellSeparators.topBar.topAnchor.constraint(equalTo: contentView.topAnchor),
            cellSeparators.bottomLine.leadingAnchor.constraint(equalTo: leadingAnchor),
            cellSeparators.bottomLine.trailingAnchor.constraint(equalTo: trailingAnchor),
            cellSeparators.bottomLine.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            cellSeparators.bottomLine.heightAnchor.constraint(equalToConstant: GroupedTable.Metric.cellSeparatorHeight),

            background.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            background.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            background.topAnchor.constraint(equalTo: cellSeparators.topBar.bottomAnchor),
            background.bottomAnchor.constraint(equalTo: cellSeparators.bottomLine.topAnchor),
        ])
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(viewModel: NonFungibleTokenViewCellViewModel) {
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
        separator.text = viewModel.issuerSeparator

        cellSeparators.topBar.backgroundColor = GroupedTable.Color.background
        cellSeparators.topLine.backgroundColor = GroupedTable.Color.cellSeparator
        cellSeparators.bottomLine.backgroundColor = GroupedTable.Color.cellSeparator

        viewsWithContent.forEach {
            $0.alpha = viewModel.alpha
        }
    }
}
