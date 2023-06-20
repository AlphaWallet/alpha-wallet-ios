// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit
import Kingfisher

struct ApprecationViewModel {
    let valueAttributedString: NSAttributedString
    let icon: UIImage?
    let backgroundColor: UIColor

    init(icon: UIImage?, valueAttributedString: NSAttributedString, backgroundColor: UIColor) {
        self.valueAttributedString = valueAttributedString
        self.icon = icon
        self.backgroundColor = backgroundColor
    }
}

class ApprecationView: UIView {

    private let valueLabel: UILabel = {
        let view = UILabel()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.textAlignment = .center
        view.setContentCompressionResistancePriority(.required, for: .vertical)
        view.setContentHuggingPriority(.required, for: .vertical)

        return view
    }()

    private let iconView: UIImageView = {
        let view = UIImageView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.contentMode = .scaleAspectFit
        return view
    }()

    init(edgeInsets: UIEdgeInsets = .init(top: 0, left: 2, bottom: 0, right: 2), spacing: CGFloat = 4) {
        super.init(frame: .zero)
        self.translatesAutoresizingMaskIntoConstraints = false

        let stackView = [iconView, valueLabel].asStackView(spacing: spacing, alignment: .center)
        stackView.translatesAutoresizingMaskIntoConstraints = false

        addSubview(stackView)
        setContentCompressionResistancePriority(.required, for: .vertical)
        setContentHuggingPriority(.required, for: .vertical)

        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 9),
            iconView.heightAnchor.constraint(equalToConstant: 9),

            stackView.anchorsConstraint(to: self, edgeInsets: edgeInsets)
        ])
    }

    required init?(coder: NSCoder) {
        return nil
    }

    func configure(viewModel: ApprecationViewModel) {
        valueLabel.attributedText = viewModel.valueAttributedString
        iconView.image = viewModel.icon
        iconView.isHidden = viewModel.icon == nil
        backgroundColor = viewModel.backgroundColor
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        layer.cornerRadius = 2.0
    }
}

class EthTokenViewCell: UITableViewCell {
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
        priceChangeLabel.textAlignment = .center
        fiatValueLabel.textAlignment = .center
        fiatValueLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        fiatValueLabel.setContentHuggingPriority(.required, for: .horizontal)

        let col0 = tokenImageView
        let row1 = [cryptoValueLabel, UIView.spacerWidth(flexible: true), changeValueContainer, blockChainTagLabel].asStackView(spacing: 5, alignment: .center)
        let col1 = [
            [titleLabel, UIView.spacerWidth(flexible: true), fiatValueLabel].asStackView(spacing: 5),
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

    func configure(viewModel: EthTokenViewCellViewModel) {
        selectionStyle = .none

        backgroundColor = Configuration.Color.Semantic.tableViewCellBackground
        background.backgroundColor = Configuration.Color.Semantic.tableViewCellBackground
        contentView.backgroundColor = Configuration.Color.Semantic.tableViewCellBackground

        titleLabel.attributedText = viewModel.titleAttributedString
        titleLabel.baselineAdjustment = .alignCenters

        cryptoValueLabel.attributedText = viewModel.cryptoValueAttributedString
        cryptoValueLabel.baselineAdjustment = .alignCenters

        apprecation24hoursView.configure(viewModel: viewModel.apprecationViewModel)

        priceChangeLabel.attributedText = viewModel.priceChangeAttributedString

        fiatValueLabel.attributedText = viewModel.fiatValueAttributedString

        viewsWithContent.forEach { $0.alpha = viewModel.alpha }
        tokenImageView.set(imageSource: viewModel.iconImage)

        blockChainTagLabel.configure(viewModel: viewModel.blockChainTagViewModel)
        changeValueContainer.isHidden = !viewModel.blockChainTagViewModel.isHidden
        accessoryType = viewModel.accessoryType
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        tokenImageView.cancel()
    }
}
