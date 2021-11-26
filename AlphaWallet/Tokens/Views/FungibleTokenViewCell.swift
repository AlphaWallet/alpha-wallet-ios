// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit
import Kingfisher

class FungibleTokenViewCell: UITableViewCell {
    private let background = UIView()
    private let titleLabel = UILabel()
    private let apprecation24hoursView = ApprecationView()
    private let priceChangeLabel = UILabel()
    private let fiatValueLabel = UILabel()
    private let cryptoValueLabel = UILabel()
    private var viewsWithContent: [UIView] {
        [titleLabel, apprecation24hoursView, priceChangeLabel]
    }

    private lazy var changeValueContainer: UIView = [priceChangeLabel, apprecation24hoursView].asStackView(spacing: 5)

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
        priceChangeLabel.textAlignment = .center
        fiatValueLabel.textAlignment = .center
        fiatValueLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        fiatValueLabel.setContentHuggingPriority(.required, for: .horizontal)

        let col0 = tokenIconImageView
        let row1 = [cryptoValueLabel, UIView.spacerWidth(flexible: true), changeValueContainer, blockChainTagLabel].asStackView(spacing: 5, alignment: .center)
        let col1 = [
            [titleLabel, UIView.spacerWidth(flexible: true), fiatValueLabel].asStackView(spacing: 5),
            row1
        ].asStackView(axis: .vertical)
        let stackView = [col0, col1].asStackView(spacing: 12, alignment: .center)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        background.addSubview(stackView)

        NSLayoutConstraint.activate([
            tokenIconImageView.heightAnchor.constraint(equalToConstant: 40),
            tokenIconImageView.widthAnchor.constraint(equalToConstant: 40),
            row1.heightAnchor.constraint(greaterThanOrEqualToConstant: 20),
            stackView.anchorsConstraint(to: background, edgeInsets: .init(top: 12, left: 20, bottom: 16, right: 12)),
            background.topAnchor.constraint(equalTo: contentView.topAnchor),
            background.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            background.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            background.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10)
        ])
    }

    required init?(coder aDecoder: NSCoder) {
        return nil
    }

    func configure(viewModel: FungibleTokenViewCellViewModel) {
        selectionStyle = .none
        backgroundColor = viewModel.backgroundColor
        background.backgroundColor = viewModel.contentsBackgroundColor
        background.cornerRadius = 8
        background.layer.shadowColor = Colors.lightGray.cgColor
        background.layer.shadowRadius = 2
        background.layer.shadowOffset = .zero
        background.layer.shadowOpacity = 0.6
        
        titleLabel.attributedText = viewModel.titleAttributedString
        titleLabel.baselineAdjustment = .alignCenters

        cryptoValueLabel.attributedText = viewModel.cryptoValueAttributedString
        cryptoValueLabel.baselineAdjustment = .alignCenters

        apprecation24hoursView.configure(viewModel: viewModel.apprecationViewModel)

        priceChangeLabel.attributedText = viewModel.priceChangeUSDValueAttributedString

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

        priceChangeLabel.layer.cornerRadius = 2.0
    }
} 
