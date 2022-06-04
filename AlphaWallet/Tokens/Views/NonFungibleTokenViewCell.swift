// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit
import Kingfisher

class NonFungibleTokenViewCell: UITableViewCell {
    private let background = UIView()
    private let titleLabel = UILabel()
    private let tickersAmountLabel = UILabel()
    private var viewsWithContent: [UIView] {
        [titleLabel, tickersAmountLabel]
    }
    private var tokenImageView: TokenImageView = {
        let imageView = TokenImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private var blockChainTagLabel = BlockchainTagLabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        contentView.addSubview(background)
        background.translatesAutoresizingMaskIntoConstraints = false

        let col0 = tokenImageView
        let col1 = [
            titleLabel,
            [tickersAmountLabel, UIView.spacerWidth(flexible: true), blockChainTagLabel].asStackView(spacing: 15)
        ].asStackView(axis: .vertical, spacing: 5)
        let stackView = [col0, col1].asStackView(spacing: 12, alignment: .center)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        background.addSubview(stackView)

        NSLayoutConstraint.activate([
            tokenImageView.heightAnchor.constraint(equalToConstant: 40),
            tokenImageView.widthAnchor.constraint(equalToConstant: 40),
            stackView.anchorsConstraint(to: background, edgeInsets: .init(top: 16, left: 20, bottom: 16, right: 16)),
            background.anchorsConstraint(to: contentView)
        ])
    }

    required init?(coder aDecoder: NSCoder) {
        return nil
    }

    func configure(viewModel: NonFungibleTokenViewCellViewModel) {
        selectionStyle = .none
        backgroundColor = viewModel.backgroundColor

        background.backgroundColor = viewModel.contentsBackgroundColor

        contentView.backgroundColor = GroupedTable.Color.background

        titleLabel.attributedText = viewModel.titleAttributedString
        titleLabel.baselineAdjustment = .alignCenters

        tickersAmountLabel.attributedText = viewModel.tickersAmountAttributedString

        viewsWithContent.forEach { $0.alpha = viewModel.alpha }
        tokenImageView.subscribable = viewModel.iconImage
        blockChainTagLabel.configure(viewModel: viewModel.blockChainTagViewModel)
        accessoryType = viewModel.accessoryType
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        tokenImageView.cancel()
    }
}
