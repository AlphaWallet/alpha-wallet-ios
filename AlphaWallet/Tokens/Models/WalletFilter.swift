// Copyright © 2018 Stormbird PTE. LTD.

import Foundation

enum WalletFilter {
	case all
    case type(Set<TokenType>)
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
	case (.keyword, .all), (.keyword, .currencyOnly), (.keyword, .assetsOnly), (.keyword, .collectiblesOnly), (.collectiblesOnly, .all), (.collectiblesOnly, .currencyOnly), (.collectiblesOnly, .assetsOnly), (.collectiblesOnly, .keyword), (.assetsOnly, .all), (.assetsOnly, .currencyOnly), (.assetsOnly, .collectiblesOnly), (.assetsOnly, .keyword), (.currencyOnly, .all), (.currencyOnly, .assetsOnly), (.currencyOnly, .collectiblesOnly), (.currencyOnly, .keyword), (.all, .currencyOnly), (.all, .assetsOnly), (.all, .collectiblesOnly), (.all, .keyword):
        return false
	case (.type, _), (_, .type):
        return true
	}
}

