//
//  GasSpeedView.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 20.08.2020.
//

import UIKit

class GasSpeedTableViewCell: UITableViewCell {

    private let estimatedTimeLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 0
        return label
    }()

    private let speedLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 0
        return label
    }()

    private let detailsLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 0

        return label
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        let estimatedTimeStackView = [estimatedTimeLabel].asStackView(axis: .vertical)

        let row0 = [
            .spacerWidth(ScreenChecker().isNarrowScreen ? 8 : 16),
            [speedLabel, detailsLabel].asStackView(axis: .vertical, alignment: .leading),
            estimatedTimeStackView,
            .spacerWidth(ScreenChecker().isNarrowScreen ? 8 : 16)
        ].asStackView(axis: .horizontal)

        let separator = UIView()
        separator.translatesAutoresizingMaskIntoConstraints = false
        separator.backgroundColor = R.color.mercury()

        let stackView = [
            .spacer(height: ScreenChecker().isNarrowScreen ? 10 : 20),
            row0,
            .spacer(height: ScreenChecker().isNarrowScreen ? 10 : 20)
        ].asStackView(axis: .vertical)

        stackView.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(stackView)
        addSubview(separator)

        NSLayoutConstraint.activate([
            estimatedTimeStackView.widthAnchor.constraint(equalToConstant: 100),
            separator.heightAnchor.constraint(equalToConstant: 1),
            separator.leadingAnchor.constraint(equalTo: leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: trailingAnchor),
            separator.bottomAnchor.constraint(equalTo: bottomAnchor),
            stackView.anchorsConstraint(to: contentView, edgeInsets: .init(top: 0, left: 0, bottom: 1, right: 0))
        ])
    }

    required init?(coder: NSCoder) {
        return nil
    }

    func configure(viewModel: GasSpeedTableViewCellViewModel) {
        backgroundColor = viewModel.backgroundColor

        speedLabel.attributedText = viewModel.speedAttributedString
        speedLabel.isHidden = speedLabel.attributedText == nil

        estimatedTimeLabel.attributedText = viewModel.estimatedTimeAttributedString
        estimatedTimeLabel.isHidden = estimatedTimeLabel.attributedText == nil

        detailsLabel.attributedText = viewModel.detailsAttributedString
        detailsLabel.isHidden = detailsLabel.attributedText == nil

        accessoryType = viewModel.accessoryType
    }
}

