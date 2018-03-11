// Copyright © 2018 Stormbird PTE. LTD.

import UIKit

class AlphaWalletHelpViewCell: UITableViewCell {
	static let identifier = "AlphaWalletHelpViewCell"

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
		background.addSubview(iconImageView)

		let xMargin  = CGFloat(7)
		let yMargin  = CGFloat(4)
		NSLayoutConstraint.activate([
			titleLabel.leadingAnchor.constraint(equalTo: background.leadingAnchor, constant: 21),
			titleLabel.trailingAnchor.constraint(equalTo: iconImageView.leadingAnchor),
			titleLabel.centerYAnchor.constraint(equalTo: background.centerYAnchor),
			titleLabel.topAnchor.constraint(equalTo: background.topAnchor, constant: 18),
			titleLabel.bottomAnchor.constraint(lessThanOrEqualTo: background.bottomAnchor, constant: -18),

			iconImageView.trailingAnchor.constraint(equalTo: background.trailingAnchor, constant: -21),
			iconImageView.centerYAnchor.constraint(equalTo: background.centerYAnchor),

			background.leadingAnchor.constraint(equalTo: leadingAnchor, constant: xMargin),
			background.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -xMargin),
			background.topAnchor.constraint(equalTo: topAnchor, constant: yMargin),
			background.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -yMargin),
		])
	}

	required init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	func configure(text: String) {
		selectionStyle = .none
		backgroundColor = Colors.appBackground

		contentView.backgroundColor = Colors.appBackground

		background.backgroundColor = Colors.appWhite
		background.layer.cornerRadius = 20

		iconImageView.image = R.image.info_accessory()

		titleLabel.textColor = Colors.appText
		titleLabel.font = Fonts.light(size: 18)!
		titleLabel.text = text
	}
}
