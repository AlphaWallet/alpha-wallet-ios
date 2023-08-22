// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import Combine

public enum WalletFilter: Equatable, Hashable {
	case all
    case attestations
    case filter(any TokenFilterProtocol)
    case defi
    case governance
    case assets
	case collectiblesOnly
	case keyword(String)

    public func hash(into hasher: inout Hasher) {
        switch self {
        case .all:
            hasher.combine(0)
        case .attestations:
            hasher.combine(1)
        case .filter:
            //The associated value doesn't need to be checked
            hasher.combine(2)
        case .defi:
            hasher.combine(3)
        case .governance:
            hasher.combine(4)
        case .assets:
            hasher.combine(5)
        case .collectiblesOnly:
            hasher.combine(6)
        case .keyword(let keyword):
            hasher.combine(7)
            hasher.combine(keyword)
        }
    }
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

