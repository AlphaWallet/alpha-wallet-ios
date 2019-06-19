// Copyright © 2018 Stormbird PTE. LTD.

import UIKit

class AssetDefinitionsOverridesViewCell: UITableViewCell {
    static let identifier = "AssetDefinitionsOverridesViewCell"

    private let background = UIView()
    private let titleLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        background.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(background)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        background.addSubview(titleLabel)

        let xMargin  = CGFloat(7)
        let yMargin  = CGFloat(4)
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: background.leadingAnchor, constant: 21),
            titleLabel.trailingAnchor.constraint(equalTo: background.trailingAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: background.centerYAnchor),
            titleLabel.topAnchor.constraint(equalTo: background.topAnchor, constant: 18),
            titleLabel.bottomAnchor.constraint(lessThanOrEqualTo: background.bottomAnchor, constant: -18),

            background.leadingAnchor.constraint(equalTo: leadingAnchor, constant: xMargin),
            background.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -xMargin),
            background.topAnchor.constraint(equalTo: topAnchor, constant: yMargin),
            background.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -yMargin),
        ])
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(viewModel: AssetDefinitionsOverridesViewCellViewModel) {
        selectionStyle = .none
        backgroundColor = viewModel.backgroundColor

        contentView.backgroundColor = viewModel.backgroundColor

        background.backgroundColor = viewModel.bubbleBackgroundColor
        background.layer.cornerRadius = viewModel.bubbleRadius

        titleLabel.textColor = viewModel.textColor
        titleLabel.font = viewModel.textFont
        titleLabel.lineBreakMode = viewModel.textLineBreakMode
        titleLabel.text = viewModel.text
    }
}
