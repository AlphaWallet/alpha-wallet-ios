//
//  SettingTableViewCell.swift
//  AlphaWallet
//
//  Created by Nimit Parekh on 06/04/20.
//

import UIKit

class SettingTableViewCell: UITableViewCell {
    private let iconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.clipsToBounds = true
        return imageView
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.setContentHuggingPriority(.required, for: .vertical)
        label.setContentCompressionResistancePriority(.required, for: .vertical)
        label.setContentHuggingPriority(.required, for: .horizontal)
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        label.clipsToBounds = false

        return label
    }()

    private let subTitleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.setContentHuggingPriority(.required, for: .vertical)
        label.setContentCompressionResistancePriority(.required, for: .vertical)
        label.setContentHuggingPriority(.required, for: .horizontal)
        label.setContentCompressionResistancePriority(.required, for: .horizontal)

        label.clipsToBounds = false

        return label
    }()

    private var iconAndTextTopBottomConstraints: [NSLayoutConstraint] = []

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        accessoryType = .disclosureIndicator

        let stackView = [
            titleLabel,
            subTitleLabel
        ].asStackView(axis: .vertical, spacing: 0)

        stackView.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(iconImageView)
        contentView.addSubview(stackView)
        iconAndTextTopBottomConstraints = [
            iconImageView.topAnchor.constraint(greaterThanOrEqualTo: contentView.topAnchor, constant: 10),
            iconImageView.bottomAnchor.constraint(greaterThanOrEqualTo: contentView.bottomAnchor, constant: -10),
            stackView.topAnchor.constraint(greaterThanOrEqualTo: contentView.topAnchor, constant: 10),
            stackView.bottomAnchor.constraint(greaterThanOrEqualTo: contentView.bottomAnchor, constant: 10),
        ]

        NSLayoutConstraint.activate([
            iconImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            iconImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            iconImageView.widthAnchor.constraint(equalToConstant: 40),
            iconImageView.heightAnchor.constraint(equalToConstant: 40),

            stackView.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            stackView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
        ] + iconAndTextTopBottomConstraints)
    }

    override func prepareForReuse() {
        accessoryView = nil
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(viewModel: SettingTableViewCellViewModel) {
        titleLabel.text = viewModel.titleText
        titleLabel.font = viewModel.titleFont
        titleLabel.textColor = viewModel.titleTextColor
        iconImageView.image = viewModel.icon
        subTitleLabel.text = viewModel.subTitleText
        subTitleLabel.isHidden = viewModel.subTitleHidden
        subTitleLabel.font = viewModel.subTitleFont
        subTitleLabel.textColor = viewModel.subTitleTextColor

        for constraint in iconAndTextTopBottomConstraints {
            constraint.constant = viewModel.subTitleHidden ? 10 : 20
        }
    }
}
