// Copyright © 2018 Stormbird PTE. LTD.

import UIKit

class AlphaWalletSettingsViewCell: UITableViewCell {
	static let identifier = "AlphaWalletSettingsViewCell"

	let background = UIView()
	let titleLabel = UILabel()
	let iconImageView = UIImageView()

	override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
		super.init(style: style, reuseIdentifier: reuseIdentifier)

		background.translatesAutoresizingMaskIntoConstraints = false
		contentView.addSubview(background)

		titleLabel.translatesAutoresizingMaskIntoConstraints = false
		background.addSubview(titleLabel)

		iconImageView.translatesAutoresizingMaskIntoConstraints = false
		iconImageView.contentMode = .scaleAspectFit
		background.addSubview(iconImageView)

		let xMargin  = CGFloat(7)
		let yMargin  = CGFloat(4)
		NSLayoutConstraint.activate([
			iconImageView.widthAnchor.constraint(equalToConstant: 29),
			iconImageView.leadingAnchor.constraint(equalTo: background.leadingAnchor, constant: 21),
			iconImageView.centerYAnchor.constraint(equalTo: background.centerYAnchor),

			titleLabel.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 21),
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

	func configure(text: String, image: UIImage?) {
		selectionStyle = .none
		backgroundColor = Colors.appBackground

		contentView.backgroundColor = Colors.appBackground

		background.backgroundColor = Colors.appWhite
		background.layer.cornerRadius = 20

		iconImageView.image = image

		titleLabel.textColor = Colors.appText
		titleLabel.font = Fonts.light(size: 18)!
		titleLabel.text = text
	}
}