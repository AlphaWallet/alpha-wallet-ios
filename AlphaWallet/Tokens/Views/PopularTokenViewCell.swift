//
//  PopularTokenViewCell.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 07.06.2021.
//

import UIKit

class PopularTokenViewCell: UITableViewCell {
    private let background = UIView()
    private let titleLabel = UILabel()

    private var viewsWithContent: [UIView] {
        [titleLabel]
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

        let stackView = [
            tokenImageView, titleLabel, UIView.spacerWidth(flexible: true)
        ].asStackView(axis: .horizontal, spacing: 12, alignment: .center)
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

    func configure(viewModel: PopularTokenViewCellViewModel) {
        selectionStyle = .none

        backgroundColor = viewModel.backgroundColor
        background.backgroundColor = viewModel.contentsBackgroundColor
        contentView.backgroundColor = GroupedTable.Color.background

        titleLabel.attributedText = viewModel.titleAttributedString
        titleLabel.baselineAdjustment = .alignCenters

        viewsWithContent.forEach { $0.alpha = viewModel.alpha }
        tokenImageView.subscribable = viewModel.iconImage

        blockChainTagLabel.configure(viewModel: viewModel.blockChainTagViewModel)
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        tokenImageView.cancel()
    }
}
