// Copyright © 2018 Stormbird PTE. LTD.

import Foundation

enum WalletFilter {
	case all
	case currencyOnly
	case assetsOnly
	case collectiblesOnly
	case keyword(String)
}

func == (lhs: WalletFilter, rhs: WalletFilter) -> Bool {
	switch (lhs, rhs) {
	case (.all, .all):
		return true
	case (.currencyOnly, .currencyOnly):
		return true
	case (.assetsOnly, .assetsOnly):
		return true
	case (.collectiblesOnly, .collectiblesOnly):
		return true
	case (.keyword(let keyword1), .keyword(let keyword2)):
		return keyword1 == keyword2
	default:
		return false
	}
}
