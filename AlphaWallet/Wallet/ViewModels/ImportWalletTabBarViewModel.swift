// Copyright © 2018 Stormbird PTE. LTD.

import UIKit

struct ImportWalletTabBarViewModel {
	var currentTab: ImportWalletTab

	init(tab: ImportWalletTab) {
		currentTab = tab
	}

	var backgroundColor: UIColor {
		return Colors.appBackground
	}

	func titleColor(for tab: ImportWalletTab) -> UIColor {
        if currentTab == tab {
            return barHighlightedColor
		} else {
			return barUnhighlightedColor
		}
	}

	var font: UIFont {
		return Fonts.semibold(size: ScreenChecker().isNarrowScreen ? 10: 11)!
	}

	var barUnhighlightedColor: UIColor {
		return .init(red: 162, green: 162, blue: 162)
	}

	var barHighlightedColor: UIColor {
		return SegmentBar.Color.highlighted
	}
}

