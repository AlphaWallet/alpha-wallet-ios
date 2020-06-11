// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit
import Kingfisher

class NonFungibleTokenViewCell: UITableViewCell {
    static let identifier = "NonFugibleTokenViewCell"

    private let background = UIView()
    private let titleLabel = UILabel()
    private let blockchainLabel = UILabel()
    private var viewsWithContent: [UIView] {
        [self.titleLabel, self.blockchainLabel]
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        contentView.addSubview(background)
        background.translatesAutoresizingMaskIntoConstraints = false
        let stackView = [
            titleLabel,
            [blockchainLabel, UIView.spacerWidth(flexible: true)].asStackView(spacing: 15),
        ].asStackView(axis: .vertical)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        background.addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.anchorsConstraint(to: background, edgeInsets: .init(top: 16, left: 20, bottom: 16, right: 16)),
            background.anchorsConstraint(to: contentView)
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

        blockchainLabel.textColor = viewModel.subtitleColor
        blockchainLabel.font = viewModel.subtitleFont
        blockchainLabel.text = viewModel.blockChainName

        viewsWithContent.forEach {
            $0.alpha = viewModel.alpha
        }
    }
}
