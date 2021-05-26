// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit
import Kingfisher

class EthTokenViewCell: UITableViewCell {
    private let background = UIView()
    private let titleLabel = UILabel()
    private let apprecation24hoursLabel = UILabel()
    private let marketPriceLabel = UILabel()
    private let fiatValueLabel = UILabel()
    private let cryptoValueLabel = UILabel()
    private var viewsWithContent: [UIView] {
        [titleLabel, apprecation24hoursLabel, marketPriceLabel]
    }

    private lazy var changeValueContainer: UIView = [marketPriceLabel, apprecation24hoursLabel].asStackView(spacing: 5)

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
        apprecation24hoursLabel.textAlignment = .center
        marketPriceLabel.textAlignment = .center
        fiatValueLabel.textAlignment = .center

        let col0 = tokenIconImageView
        let col1 = [
            [titleLabel, UIView.spacerWidth(flexible: true), fiatValueLabel].asStackView(spacing: 5),
            [cryptoValueLabel, UIView.spacerWidth(flexible: true), changeValueContainer, blockChainTagLabel].asStackView(spacing: 5)
        ].asStackView(axis: .vertical, spacing: 2)
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
        return nil
    }

    func configure(viewModel: EthTokenViewCellViewModel) {
        selectionStyle = .none

        backgroundColor = viewModel.backgroundColor
        background.backgroundColor = viewModel.contentsBackgroundColor
        contentView.backgroundColor = GroupedTable.Color.background

        titleLabel.attributedText = viewModel.titleAttributedString
        titleLabel.baselineAdjustment = .alignCenters

        cryptoValueLabel.attributedText = viewModel.cryptoValueAttributedString
        cryptoValueLabel.baselineAdjustment = .alignCenters

        apprecation24hoursLabel.attributedText = viewModel.apprecation24hoursAttributedString
        apprecation24hoursLabel.backgroundColor = viewModel.apprecation24hoursBackgroundColor

        marketPriceLabel.attributedText = viewModel.marketPriceAttributedString

        fiatValueLabel.attributedText = viewModel.fiatValueAttributedString

        viewsWithContent.forEach {
            $0.alpha = viewModel.alpha
        }
        tokenIconImageView.subscribable = viewModel.iconImage

        blockChainTagLabel.configure(viewModel: viewModel.blockChainTagViewModel)
        changeValueContainer.isHidden = !viewModel.blockChainTagViewModel.blockChainNameLabelHidden
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        marketPriceLabel.layer.cornerRadius = 2.0
    }
}
