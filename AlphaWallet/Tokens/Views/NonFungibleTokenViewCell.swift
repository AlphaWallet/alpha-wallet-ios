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
    private var tokenIconImageView: TokenImageView = {
        let imageView = TokenImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private var blockChainTagLabel = BlockchainTagLabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        contentView.addSubview(background)
        background.translatesAutoresizingMaskIntoConstraints = false

        let col0 = tokenIconImageView
        let col1 = [
            titleLabel,
            [blockchainLabel, UIView.spacerWidth(flexible: true), blockChainTagLabel].asStackView(spacing: 15)
        ].asStackView(axis: .vertical, spacing: 5)
        let stackView = [col0, col1].asStackView(spacing: 12, alignment: .center)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        background.addSubview(stackView)

        NSLayoutConstraint.activate([
            tokenIconImageView.heightAnchor.constraint(equalToConstant: 40),
            tokenIconImageView.widthAnchor.constraint(equalToConstant: 40),
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
        tokenIconImageView.subscribable = viewModel.iconImage

        blockChainTagLabel.configure(viewModel: viewModel.blockChaintagViewModel)
    }
}
