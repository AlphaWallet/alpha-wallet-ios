// Copyright © 2018 Stormbird PTE. LTD.
// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import TrustKeystore
import UIKit

struct RequestViewModel {

	let account: Wallet
	let config: Config

	init(
			account: Wallet,
			config: Config
	) {
		self.account = account
		self.config = config
	}

	var myAddressText: String {
		return account.address.description
	}

	var shareMyAddressText: String {
		return String(
				format: NSLocalizedString("request.myAddressIs.label.title", value: "My %@ address is: %@", comment: ""),
				config.server.name, myAddressText
		)
	}

	var headlineText: String {
		return R.string.localizable.aWalletAddressTitle(config.server.name)
	}

	var copyWalletText: String {
		return NSLocalizedString("request.copyWallet.button.title", value: "Copy wallet address", comment: "")
	}

	var addressCopiedText: String {
		return NSLocalizedString("request.addressCopied.title", value: "Address copied", comment: "")
	}

	var backgroundColor: UIColor {
		return Colors.appBackground
	}

	var buttonBackgroundColor: UIColor {
		return Colors.appBackground
	}

	var buttonTitleColor: UIColor {
		return Colors.appWhite
	}

	var buttonFont: UIFont {
		return Fonts.regular(size: 20)!
	}

	var labelColor: UIColor {
		return Colors.appText
	}

	var addressHintFont: UIFont {
		return Fonts.light(size: 25)!
	}

	var addressFont: UIFont {
		return Fonts.semibold(size: 16)!
	}

	var addressBackgroundColor: UIColor {
		return UIColor(red: 237, green: 237, blue: 237)
	}

	var instructionFont: UIFont {
		return Fonts.light(size: 16)!
	}

	var instructionText: String {
		return R.string.localizable.aWalletAddressScanInstructions()
	}
}
