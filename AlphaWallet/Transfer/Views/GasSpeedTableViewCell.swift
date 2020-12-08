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

    private let gasPriceLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 0

        return label
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        let col0 = [
            speedLabel,
            detailsLabel,
            gasPriceLabel,
        ].asStackView(axis: .vertical, alignment: .leading)
        let col1 = [estimatedTimeLabel].asStackView(axis: .vertical)

        let row = [.spacerWidth(ScreenChecker().isNarrowScreen ? 8 : 16), col0, col1, .spacerWidth(ScreenChecker().isNarrowScreen ? 8 : 16)].asStackView(axis: .horizontal)

        let separator = UIView()
        separator.translatesAutoresizingMaskIntoConstraints = false
        separator.backgroundColor = R.color.mercury()

        let stackView = [
            .spacer(height: ScreenChecker().isNarrowScreen ? 10 : 20),
            row,
            .spacer(height: ScreenChecker().isNarrowScreen ? 10 : 20)
        ].asStackView(axis: .vertical)

        stackView.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(stackView)
        addSubview(separator)

        NSLayoutConstraint.activate([
            col1.widthAnchor.constraint(equalToConstant: 100),
            separator.heightAnchor.constraint(equalToConstant: 1),
            separator.leadingAnchor.constraint(equalTo: leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: trailingAnchor),
            separator.bottomAnchor.constraint(equalTo: bottomAnchor),

            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 0),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -30),
            stackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 0),
            stackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: 1)
        ])
    }

    required init?(coder: NSCoder) {
        return nil
    }

    func configure(viewModel: GasSpeedTableViewCellViewModel) {
        backgroundColor = viewModel.backgroundColor

        speedLabel.attributedText = viewModel.titleAttributedString

        estimatedTimeLabel.textAlignment = .right
        estimatedTimeLabel.attributedText = viewModel.estimatedTimeAttributedString
        estimatedTimeLabel.isHidden = estimatedTimeLabel.attributedText == nil

        detailsLabel.attributedText = viewModel.detailsAttributedString
        detailsLabel.isHidden = detailsLabel.attributedText == nil

        gasPriceLabel.attributedText = viewModel.gasPriceAttributedString
        gasPriceLabel.isHidden = gasPriceLabel.attributedText == nil

        accessoryType = viewModel.accessoryType
    }
}

