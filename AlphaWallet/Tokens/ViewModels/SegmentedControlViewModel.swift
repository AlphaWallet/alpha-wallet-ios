// Copyright © 2020 Stormbird PTE. LTD.

import UIKit

struct SegmentedControlViewModel {
	var selection: SegmentedControl.Selection

	init(selection: SegmentedControl.Selection) {
		self.selection = selection
	}

	var backgroundColor: UIColor {
		return Colors.appBackground
	}

	func titleFont(forSelection selection: SegmentedControl.Selection) -> UIFont {
		if selection == self.selection {
			return selectedTitleFont
		} else {
			return unselectedTitleFont
		}
	}

	func titleColor(forSelection selection: SegmentedControl.Selection) -> UIColor {
		if selection == self.selection {
			return selectedTitleColor
		} else {
            return unselectedTitleColor
		}
	}

	private var unselectedTitleFont: UIFont {
		return Fonts.regular(size: 15)
	}

	private var selectedTitleFont: UIFont {
		return Fonts.semibold(size: 15)
	}

	private var unselectedTitleColor: UIColor {
		return R.color.dove()!
	}

	private var selectedTitleColor: UIColor {
		return selectedBarColor
	}

	var unselectedBarColor: UIColor {
        return Style.SegmentedControl.Separator.color
		// return R.color.alto()!
	}

	var selectedBarColor: UIColor {
		return Colors.appTint
	}
}
