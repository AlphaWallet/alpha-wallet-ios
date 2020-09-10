// Copyright SIX DAY LLC. All rights reserved.

import Foundation

enum TokenType: String {
    case nativeCryptocurrency = "ether"
    case erc20 = "ERC20"
    case erc875 = "ERC875"
    case erc721 = "ERC721"
    case erc721ForTickets = "ERC721ForTickets"

    init(tokenInterfaceType: TokenInterfaceType) {
        switch tokenInterfaceType {
        case .erc20:
            self = .erc20
        case .erc721:
            self = .erc721
        case .erc875:
            self = .erc875
        }
    }
}