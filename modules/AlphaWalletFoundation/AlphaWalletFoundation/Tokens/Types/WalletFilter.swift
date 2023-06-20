// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import Combine

public enum WalletFilter: Equatable {
	case all
    case attestations
    case filter(TokenFilterProtocol)
    case defi
    case governance
    case assets
	case collectiblesOnly
	case keyword(String)
}

public protocol TokenFilterProtocol {
    var objectWillChange: AnyPublisher<Void, Never> { get }

    func filter(token: TokenFilterable) -> Bool
}

public func == (lhs: WalletFilter, rhs: WalletFilter) -> Bool {
    switch (lhs, rhs) {
    case (.all, .all):
        return true
    case (.attestations, .attestations):
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

