// Copyright © 2020 Stormbird PTE. LTD.

import UIKit

struct SegmentedControlViewModel {
	var selection: SegmentedControl.Selection

	init(selection: SegmentedControl.Selection) {
		self.selection = selection
	}

	var backgroundColor: UIColor {
		return Colors.headerThemeColor
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
		return Fonts.bold(size: 15)
	}

	private var selectedTitleFont: UIFont {
		return Fonts.bold(size: 15)
	}

	private var unselectedTitleColor: UIColor {
		return Colors.appWhite
	}

	private var selectedTitleColor: UIColor {
		return selectedBarColor
	}

	var unselectedBarColor: UIColor {
        return Colors.appWhite
	}

	var selectedBarColor: UIColor {
		return Colors.segmentIndicatorColor
	}
}
