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
            [tickersAmountLabel, UIView.spacerWidth(flexible: true), blockChainTagLabel].asStackView(spacing: 15)
        ].asStackView(axis: .vertical, spacing: 5)
        let stackView = [col0, col1].asStackView(spacing: 12, alignment: .center)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        background.addSubview(stackView)

        NSLayoutConstraint.activate([
            tokenIconImageView.heightAnchor.constraint(equalToConstant: 40),
            tokenIconImageView.widthAnchor.constraint(equalToConstant: 40),
            stackView.anchorsConstraint(to: background, edgeInsets: .init(top: 16, left: 20, bottom: 16, right: 16)),
            background.topAnchor.constraint(equalTo: contentView.topAnchor),
            background.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            background.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            background.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10)
        ])
    }

    required init?(coder aDecoder: NSCoder) {
        return nil
    }

    func configure(viewModel: NonFungibleTokenViewCellViewModel) {
        selectionStyle = .none
        backgroundColor = viewModel.backgroundColor

        background.backgroundColor = viewModel.contentsBackgroundColor
        background.cornerRadius = 8
        background.layer.shadowColor = Colors.lightGray.cgColor
        background.layer.shadowRadius = 2
        background.layer.shadowOffset = .zero
        background.layer.shadowOpacity = 0.6
        
        contentView.backgroundColor = GroupedTable.Color.background

        titleLabel.attributedText = viewModel.titleAttributedString
        titleLabel.baselineAdjustment = .alignCenters

        tickersAmountLabel.attributedText = viewModel.tickersAmountAttributedString

        viewsWithContent.forEach {
            $0.alpha = viewModel.alpha
        }
        tokenIconImageView.subscribable = viewModel.iconImage
        blockChainTagLabel.configure(viewModel: viewModel.blockChainTagViewModel)
    }
}
