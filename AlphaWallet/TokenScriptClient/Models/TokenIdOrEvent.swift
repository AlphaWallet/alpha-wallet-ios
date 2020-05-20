// Copyright © 2020 Stormbird PTE. LTD.

import Foundation

enum TokenIdOrEvent {
    case tokenId(tokenId: TokenId)
    case event(tokenId: TokenId, event: EventInstance)

    var tokenId: TokenId {
        switch self {
        case .tokenId(let tokenId):
            return tokenId
        case .event(let tokenId, _):
            return tokenId
        }
    }
}

