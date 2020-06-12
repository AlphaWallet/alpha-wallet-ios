// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit
import Kingfisher

class FungibleTokenViewCell: UITableViewCell {
    static let identifier = "FungibleTokenViewCell"

    private let background = UIView()
    private let titleLabel = UILabel()
    private let symbolLabel = UILabel()
    private let blockchainLabel = UILabel()
    private var viewsWithContent: [UIView] {
        [self.titleLabel, blockchainLabel]
    }
    private var tokenIconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        contentView.addSubview(background)
        background.translatesAutoresizingMaskIntoConstraints = false

        let col0 = tokenIconImageView
        let col1 = [
            titleLabel,
            [blockchainLabel, UIView.spacerWidth(flexible: true)].asStackView(spacing: 15)
        ].asStackView(axis: .vertical)
        let stackView = [col0, col1].asStackView(spacing: 12)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        background.addSubview(stackView)

        symbolLabel.translatesAutoresizingMaskIntoConstraints = false
        background.addSubview(symbolLabel)

        NSLayoutConstraint.activate([
            symbolLabel.anchorsConstraint(to: tokenIconImageView),

            tokenIconImageView.heightAnchor.constraint(equalToConstant: 40),
            tokenIconImageView.widthAnchor.constraint(equalToConstant: 40),
            stackView.anchorsConstraint(to: background, edgeInsets: .init(top: 16, left: 20, bottom: 16, right: 16)),
            background.anchorsConstraint(to: contentView)
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

        symbolLabel.textColor = viewModel.symbolColor
        symbolLabel.font = viewModel.symbolFont
        symbolLabel.textAlignment = .center
        symbolLabel.adjustsFontSizeToFitWidth = true
        symbolLabel.text = viewModel.symbolInIcon

        blockchainLabel.textColor = viewModel.subtitleColor
        blockchainLabel.font = viewModel.subtitleFont
        blockchainLabel.text = viewModel.blockChainName

        viewsWithContent.forEach {
            $0.alpha = viewModel.alpha
        }

        tokenIconImageView.image = viewModel.iconImage
    }
}
