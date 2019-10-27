// Copyright © 2018 Stormbird PTE. LTD.

import UIKit

struct WalletFilterViewModel {
	var currentFilter: WalletFilter

	init(filter: WalletFilter) {
		currentFilter = filter
	}

	var backgroundColor: UIColor {
		return Colors.appBackground
	}

	func colorForFilter(filter: WalletFilter) -> UIColor {
		if currentFilter == filter {
			return barHighlightedColor
		} else {
			return UIColor(red: 162, green: 162, blue: 162)
		}
	}

	var font: UIFont {
		return SegmentBar.Font.text
	}

	var barUnhighlightedColor: UIColor {
		return UIColor(red: 233, green: 233, blue: 233)
	}

	var barHighlightedColor: UIColor {
		return SegmentBar.Color.highlighted
	}
}
