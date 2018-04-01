// Copyright © 2018 Stormbird PTE. LTD.

import UIKit

class MarketplaceViewController: UIViewController {
	init() {
		super.init(nibName: nil, bundle: nil)

		title = R.string.localizable.aMarketplaceTabbarItemTitle()
		view.backgroundColor = Colors.appBackground
	}

	required init?(coder aDecoder: NSCoder) {
	    fatalError("init(coder:) has not been implemented")
	}
}
