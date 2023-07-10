// Copyright SIX DAY LLC. All rights reserved.

import Foundation

public enum TokenType: String {
    case nativeCryptocurrency = "ether"
    case erc20 = "ERC20"
    case erc875 = "ERC875"
    case erc721 = "ERC721"
    case erc721ForTickets = "ERC721ForTickets"
    case erc1155 = "ERC1155"

    public init(tokenInterfaceType: TokenInterfaceType) {
        switch tokenInterfaceType {
        case .erc20:
            self = .erc20
        case .erc721:
            self = .erc721
        case .erc875:
            self = .erc875
        case .erc1155:
            self = .erc1155
        }
    }

    //Leaky abstraction. We shouldn't update the balance if it is ERC1155, because we are just setting a dummy value to signal completion of token data detection
    public var shouldUpdateBalanceWhenDetected: Bool {
        switch self {
        case .nativeCryptocurrency, .erc20, .erc875, .erc721, .erc721ForTickets:
            return true
        case .erc1155:
            return false
        }
    }
}
