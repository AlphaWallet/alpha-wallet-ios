// Copyright © 2018 Stormbird PTE. LTD.

import UIKit

struct ImportWalletHelpBubbleViewViewModel {
	var textColor: UIColor {
		return UIColor(red: 250, green: 209, blue: 0)
	}
	var textFont: UIFont {
		return Fonts.semibold(size: 18)!
	}
	var descriptionColor: UIColor {
		return Colors.appText
	}
	var descriptionFont: UIFont {
		return Fonts.regular(size: 15)!
	}
}
