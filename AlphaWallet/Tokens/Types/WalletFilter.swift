// Copyright © 2018 Stormbird PTE. LTD.

import Foundation

enum WalletFilter: Equatable {
	case all
    case filter(TokenFilterProtocol)
    case defi
    case governance
    case assets
	case collectiblesOnly
	case keyword(String)
}

protocol TokenFilterProtocol {
    func filter(token: TokenFilterable) -> Bool
}

func == (lhs: WalletFilter, rhs: WalletFilter) -> Bool {
    switch (lhs, rhs) {
    case (.all, .all):
        return true
    case (.defi, .defi):
        return true
    case (.assets, .assets):
        return true
    case (.governance, .governance):
        return true
    case (.collectiblesOnly, .collectiblesOnly):
        return true
    case (.keyword(let keyword1), .keyword(let keyword2)):
        return keyword1 == keyword2
    case (.filter, _), (_, .filter):
        return true
    default:
        return false
    }
}

