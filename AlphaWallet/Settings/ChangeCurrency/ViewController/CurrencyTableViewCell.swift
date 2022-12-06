//
//  CurrencyTableViewCell.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 30.06.2020.
//

import UIKit

class CurrencyTableViewCell: UITableViewCell {
    private let nameLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = Fonts.regular(size: ScreenChecker.size(big: 16, medium: 16, small: 12))
        label.textColor = Configuration.Color.Semantic.defaultSubtitleText

        return label
    }()

    private let codeLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = Fonts.regular(size: ScreenChecker.size(big: 20, medium: 20, small: 16))
        label.textColor = Configuration.Color.Semantic.defaultForegroundText

        return label
    }()

    private let iconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false

        return imageView
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        contentView.addSubview(iconImageView)
        contentView.addSubview(nameLabel)
        contentView.addSubview(codeLabel)

        NSLayoutConstraint.activate([
            iconImageView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: ScreenChecker.size(big: 20, medium: 20, small: 16)),
            iconImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: ScreenChecker.size(big: 20, medium: 20, small: 16)),
            iconImageView.heightAnchor.constraint(equalToConstant: ScreenChecker.size(big: 40, medium: 40, small: 35)),
            iconImageView.widthAnchor.constraint(equalToConstant: ScreenChecker.size(big: 40, medium: 40, small: 35)),
            iconImageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -ScreenChecker.size(big: 20, medium: 20, small: 16)),

            codeLabel.topAnchor.constraint(equalTo: iconImageView.topAnchor),
            codeLabel.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 12),

            nameLabel.bottomAnchor.constraint(equalTo: iconImageView.bottomAnchor),
            nameLabel.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 12)
        ])

        backgroundColor = Configuration.Color.Semantic.tableViewCellBackground
        contentView.backgroundColor = Configuration.Color.Semantic.tableViewCellBackground
    }

    required init?(coder aDecoder: NSCoder) {
        return nil
    }

    func configure(viewModel: CurrencyTableViewCellViewModel) {
        selectionStyle = .none
        accessoryType = viewModel.accessoryType
        codeLabel.text = viewModel.code
        nameLabel.text = viewModel.name
        iconImageView.image = viewModel.icon
    }

}
