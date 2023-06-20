// Copyright © 2023 Stormbird PTE. LTD.

import UIKit
import AlphaWalletAttestation

class AttestationViewCell: UITableViewCell {
    private let background = UIView()
    private let titleLabel = UILabel()
    private let detailsLabel = UILabel()
    private var tokenImageView: TokenImageView = {
        let imageView = TokenImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.loading = .disabled
        imageView.contentMode = .scaleAspectFit
        imageView.rounding = .circle
        imageView.placeholderRounding = .circle
        return imageView
    }()
    private var blockChainTagLabel = BlockchainTagLabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        contentView.addSubview(background)
        background.translatesAutoresizingMaskIntoConstraints = false

        let col0 = tokenImageView
        let row1 = [detailsLabel, UIView.spacerWidth(flexible: true), blockChainTagLabel].asStackView(spacing: 5, alignment: .center)
        let col1 = [
            [titleLabel, UIView.spacerWidth(flexible: true) ].asStackView(spacing: 5),
            row1
        ].asStackView(axis: .vertical)
        let stackView = [col0, col1].asStackView(spacing: 12, alignment: .center)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        background.addSubview(stackView)

        NSLayoutConstraint.activate([
            tokenImageView.heightAnchor.constraint(equalToConstant: 40),
            tokenImageView.widthAnchor.constraint(equalToConstant: 40),
            row1.heightAnchor.constraint(greaterThanOrEqualToConstant: 20),
            stackView.anchorsConstraint(to: background, edgeInsets: .init(top: 12, left: 16, bottom: 15, right: 16)),
            background.anchorsConstraint(to: contentView)
        ])
    }

    required init?(coder aDecoder: NSCoder) {
        return nil
    }

    func configure(viewModel: AttestationViewCellViewModel) {
        selectionStyle = .none
        backgroundColor = Configuration.Color.Semantic.tableViewCellBackground
        background.backgroundColor = Configuration.Color.Semantic.tableViewCellBackground
        contentView.backgroundColor = Configuration.Color.Semantic.tableViewCellBackground

        titleLabel.attributedText = viewModel.titleAttributedString
        titleLabel.baselineAdjustment = .alignCenters

        detailsLabel.attributedText = viewModel.detailsAttributedString
        detailsLabel.baselineAdjustment = .alignCenters

        tokenImageView.set(imageSource: viewModel.iconImage)

        blockChainTagLabel.configure(viewModel: viewModel.blockChainTagViewModel)
        accessoryType = viewModel.accessoryType
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        tokenImageView.cancel()
    }
}
