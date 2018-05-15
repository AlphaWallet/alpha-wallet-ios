// Copyright © 2018 Stormbird PTE. LTD.

import UIKit

class MarketplaceViewController: UIViewController {
	let comingSoonLabel = UILabel()

	init() {
		super.init(nibName: nil, bundle: nil)

		title = R.string.localizable.aMarketplaceTabbarItemTitle()
		view.backgroundColor = Colors.appBackground

		comingSoonLabel.translatesAutoresizingMaskIntoConstraints = false
		view.addSubview(comingSoonLabel)

		NSLayoutConstraint.activate([
			comingSoonLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor),
			comingSoonLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor),
			comingSoonLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -40),
		])

		configure()
	}

	required init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	func configure() {
		comingSoonLabel.textAlignment = .center
		comingSoonLabel.textColor = Colors.appWhite
		comingSoonLabel.font = Fonts.regular(size: 20)
		comingSoonLabel.text = R.string.localizable.comingSoon()
	}
}
