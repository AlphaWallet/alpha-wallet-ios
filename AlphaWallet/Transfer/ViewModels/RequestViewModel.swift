// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit

struct RequestViewModel {
	private let account: Wallet
    private let server: RPCServer

	init(account: Wallet, server: RPCServer) {
		self.account = account
		self.server = server
	}

	var myAddressText: String {
		return account.address.eip55String
	}

	var myAddress: AlphaWallet.Address {
		return account.address
	}

	var shareMyAddressText: String {
		return R.string.localizable.requestMyAddressIsLabelTitle(server.name, myAddressText)
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

	var buttonTitleColor: UIColor {
		return Colors.appWhite
	}

	var buttonFont: UIFont {
		return Fonts.regular(size: 20)!
	}

	var labelColor: UIColor {
		return Colors.appText
	}

	var addressFont: UIFont {
		return Fonts.semibold(size: 16)!
	}

	var addressBackgroundColor: UIColor {
		return UIColor(red: 237, green: 237, blue: 237)
	}

	var instructionFont: UIFont {
		return Fonts.regular(size: 17)!
	}

	var instructionText: String {
		return R.string.localizable.aWalletAddressScanInstructions()
	}
}
