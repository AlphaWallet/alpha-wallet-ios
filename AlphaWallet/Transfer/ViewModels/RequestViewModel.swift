// Copyright © 2018 Stormbird PTE. LTD.
// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import TrustKeystore
import UIKit

struct RequestViewModel {
	private let account: Wallet
    private let server: RPCServer

	init(account: Wallet, server: RPCServer) {
		self.account = account
		self.server = server
	}

	var myAddressText: String {
		return account.address.description
	}

	var shareMyAddressText: String {
		return R.string.localizable.requestMyAddressIsLabelTitle(server.name, myAddressText)
	}

	var headlineText: String {
		return R.string.localizable.aWalletAddressTitle(server.name)
	}

	var copyWalletText: String {
		return R.string.localizable.requestCopyWalletButtonTitle()
	}

	var addressCopiedText: String {
		return R.string.localizable.requestAddressCopiedTitle()
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
