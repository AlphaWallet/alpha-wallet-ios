// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import Eureka

public final class AlphaWalletSettingsTextRow: _TextRow, RowType {
	required public init(tag: String?) {
		super.init(tag: tag)
	}
}

open class _TextRow: FieldRow<AlphaWalletSettingsTextCell> {
	public required init(tag: String?) {
		super.init(tag: tag)
	}
}

open class AlphaWalletSettingsTextCell: _FieldCell<String>, CellType {
	let background = UIView()
	let mainLabel = UILabel()
	let subLabel = UILabel()

	required public init(style: UITableViewCellStyle, reuseIdentifier: String?) {
		super.init(style: style, reuseIdentifier: reuseIdentifier)

		background.translatesAutoresizingMaskIntoConstraints = false
		contentView.addSubview(background)

		mainLabel.translatesAutoresizingMaskIntoConstraints = false
		background.addSubview(mainLabel)

		subLabel.translatesAutoresizingMaskIntoConstraints = false
		background.addSubview(subLabel)

		mainLabel.text = "xxx"
		subLabel.text = "yyy"

		let xMargin  = CGFloat(7)
		let yMargin  = CGFloat(4)
		NSLayoutConstraint.activate([
			mainLabel.leadingAnchor.constraint(equalTo: background.leadingAnchor, constant: 21),
			mainLabel.trailingAnchor.constraint(equalTo: subLabel.leadingAnchor, constant: -10),
			mainLabel.centerYAnchor.constraint(equalTo: background.centerYAnchor),
			mainLabel.topAnchor.constraint(equalTo: background.topAnchor, constant: 18),
			mainLabel.bottomAnchor.constraint(lessThanOrEqualTo: background.bottomAnchor, constant: -18),

			subLabel.trailingAnchor.constraint(equalTo: background.trailingAnchor, constant: -18),
			subLabel.centerYAnchor.constraint(equalTo: background.centerYAnchor),
			subLabel.topAnchor.constraint(equalTo: background.topAnchor, constant: 18),
			subLabel.bottomAnchor.constraint(lessThanOrEqualTo: background.bottomAnchor, constant: -18),

			background.leadingAnchor.constraint(equalTo: leadingAnchor, constant: xMargin),
			background.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -xMargin),
			background.topAnchor.constraint(equalTo: topAnchor, constant: yMargin),
			background.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -yMargin),
		])
	}

	required public init?(coder aDecoder: NSCoder) {
		super.init(coder: aDecoder)
	}

	open override func setup() {
		super.setup()
		
		height = { 70 }

		backgroundColor = Colors.appBackground
		
		contentView.backgroundColor = Colors.appBackground

		background.backgroundColor = Colors.appWhite
		background.layer.cornerRadius = 20

		mainLabel.textColor = Colors.appText
		mainLabel.font = Fonts.light(size: 18)!

		subLabel.textColor = Colors.appText
		subLabel.font = Fonts.light(size: 18)!
	}
}
