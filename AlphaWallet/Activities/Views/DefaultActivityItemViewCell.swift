// Copyright © 2020 Stormbird PTE. LTD.

import UIKit

class DefaultActivityItemViewCell: UITableViewCell {
    private let background = UIView()
    private let tokenImageView = TokenImageView()
    private let stateImageView: UIImageView = {
        let view = UIImageView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.contentMode = .scaleAspectFit

        return view
    }()
    private let pendingLoadingIndicatorView: ActivityLoadingIndicatorView = {
        let control = ActivityLoadingIndicatorView()
        control.lineColor = R.color.azure()!
        control.backgroundLineColor = R.color.loadingBackground()!
        control.translatesAutoresizingMaskIntoConstraints = false
        control.duration = 1.1
        control.lineWidth = 3
        control.backgroundFillColor = .white
        control.translatesAutoresizingMaskIntoConstraints = false
        control.startAnimating()

        return control
    }()

    private let titleLabel = UILabel()
    private let amountLabel = UILabel()
    private let subTitleLabel = UILabel()
    private let timestampLabel = UILabel()
    private var leftEdgeConstraint: NSLayoutConstraint = .init()
    private var viewModel: DefaultActivityCellViewModel?

    private let stateContainerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false

        return view
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        contentView.addSubview(background)
        background.translatesAutoresizingMaskIntoConstraints = false

        tokenImageView.contentMode = .scaleAspectFit

        subTitleLabel.lineBreakMode = .byTruncatingMiddle

        amountLabel.textAlignment = .right

        let leftStackView = [
            titleLabel,
            subTitleLabel,
        ].asStackView(axis: .vertical, distribution: .fillProportionally, spacing: 0)

        timestampLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        timestampLabel.setContentHuggingPriority(.required, for: .vertical)
        let rightStackView = [
            amountLabel,
            timestampLabel,
        ].asStackView(axis: .vertical, alignment: .trailing)

        let stackView = [tokenImageView, leftStackView, rightStackView].asStackView(spacing: 15)
        stackView.translatesAutoresizingMaskIntoConstraints = false

        tokenImageView.setContentHuggingPriority(UILayoutPriority.defaultLow, for: .horizontal)
        subTitleLabel.setContentHuggingPriority(UILayoutPriority.defaultLow, for: .horizontal)
        titleLabel.setContentHuggingPriority(UILayoutPriority.defaultLow, for: .horizontal)

        amountLabel.setContentHuggingPriority(UILayoutPriority.required, for: .horizontal)
        stackView.setContentHuggingPriority(UILayoutPriority.required, for: .horizontal)

        background.addSubview(stackView)
        background.addSubview(stateContainerView)

        stateContainerView.addSubview(stateImageView)
        stateContainerView.addSubview(pendingLoadingIndicatorView)

        leftEdgeConstraint = stackView.leadingAnchor.constraint(equalTo: background.leadingAnchor, constant: StyleLayout.sideMargin)

        NSLayoutConstraint.activate([
            timestampLabel.heightAnchor.constraint(equalToConstant: 20),

            tokenImageView.heightAnchor.constraint(equalToConstant: 40),
            tokenImageView.widthAnchor.constraint(equalToConstant: 40),

            stateContainerView.heightAnchor.constraint(equalToConstant: 16),
            stateContainerView.widthAnchor.constraint(equalToConstant: 16),
            stateContainerView.trailingAnchor.constraint(equalTo: tokenImageView.trailingAnchor, constant: -2),
            stateContainerView.bottomAnchor.constraint(equalTo: tokenImageView.bottomAnchor, constant: -2),

            leftEdgeConstraint,
            stackView.trailingAnchor.constraint(equalTo: background.trailingAnchor, constant: -StyleLayout.sideMargin),
            stackView.topAnchor.constraint(equalTo: background.topAnchor, constant: 14),
            stackView.bottomAnchor.constraint(equalTo: background.bottomAnchor, constant: -14),

            background.anchorsConstraint(to: contentView),

            contentView.heightAnchor.constraint(equalToConstant: 80)
        ] + stateImageView.anchorsConstraint(to: stateContainerView)
          + pendingLoadingIndicatorView.anchorsConstraint(to: stateContainerView))
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(viewModel: DefaultActivityCellViewModel) {
        self.viewModel = viewModel

        leftEdgeConstraint.constant = viewModel.leftMargin
        separatorInset = .init(top: 0, left: viewModel.leftMargin, bottom: 0, right: 0)

        selectionStyle = .none
        background.backgroundColor = viewModel.contentsBackgroundColor

        backgroundColor = viewModel.backgroundColor

        titleLabel.textColor = viewModel.titleTextColor
        titleLabel.attributedText = viewModel.title

        subTitleLabel.text = viewModel.subTitle
        subTitleLabel.textColor = viewModel.subTitleTextColor
        subTitleLabel.font = viewModel.subTitleFont

        timestampLabel.textAlignment = viewModel.timestampTextAlignment
        timestampLabel.textColor = viewModel.timestampColor
        timestampLabel.font = viewModel.timestampFont
        timestampLabel.text = viewModel.timestamp

        amountLabel.attributedText = viewModel.amount

        tokenImageView.subscribable = viewModel.iconImage

        if viewModel.isInPendingState {
            stateImageView.isHidden = true
            pendingLoadingIndicatorView.isHidden = false
        } else {
            stateImageView.isHidden = false
            pendingLoadingIndicatorView.isHidden = true
        }

        stateImageView.image = viewModel.stateImage
    }
}
