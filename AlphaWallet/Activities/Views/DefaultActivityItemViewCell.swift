// Copyright © 2020 Stormbird PTE. LTD.

import UIKit

class DefaultActivityItemViewCell: UITableViewCell {
    private let background = UIView()
    private let tokenImageView = TokenImageView()
    private let stateView: ActivityStateView = {
        let view = ActivityStateView()
        view.translatesAutoresizingMaskIntoConstraints = false
        
        return view
    }()

    private let titleLabel = UILabel()
    private let amountLabel = UILabel()
    private let subTitleLabel = UILabel()
    private let timestampLabel = UILabel()
    private var leftEdgeConstraint: NSLayoutConstraint = .init()
    private var viewModel: DefaultActivityCellViewModel?

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

        let stackView = [tokenImageView, leftStackView, rightStackView].asStackView(axis: .horizontal, spacing: 15, alignment: .center)
        stackView.translatesAutoresizingMaskIntoConstraints = false

        tokenImageView.setContentHuggingPriority(UILayoutPriority.defaultLow, for: .horizontal)
        subTitleLabel.setContentHuggingPriority(UILayoutPriority.defaultLow, for: .horizontal)
        titleLabel.setContentHuggingPriority(UILayoutPriority.defaultLow, for: .horizontal)

        amountLabel.setContentHuggingPriority(UILayoutPriority.required, for: .horizontal)
        stackView.setContentHuggingPriority(UILayoutPriority.required, for: .horizontal)

        background.addSubview(stackView)
        background.addSubview(stateView)

        leftEdgeConstraint = stackView.leadingAnchor.constraint(equalTo: background.leadingAnchor, constant: StyleLayout.sideMargin)
        // NOTE: Cells height is specifying by table view and currently it equals 80
        NSLayoutConstraint.activate([
            timestampLabel.heightAnchor.constraint(equalToConstant: 20),

            tokenImageView.heightAnchor.constraint(equalToConstant: 40),
            tokenImageView.widthAnchor.constraint(equalToConstant: 40),

            leftEdgeConstraint,
            stackView.trailingAnchor.constraint(equalTo: background.trailingAnchor, constant: -StyleLayout.sideMargin),
            stackView.topAnchor.constraint(equalTo: background.topAnchor, constant: 20),
            stackView.bottomAnchor.constraint(equalTo: background.bottomAnchor, constant: -20),
            background.anchorsConstraint(to: contentView),
            ] + stateView.anchorConstraints(to: tokenImageView))
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

        stateView.configure(viewModel: viewModel.activityStateViewViewModel)
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        tokenImageView.cancel()
    }
}
