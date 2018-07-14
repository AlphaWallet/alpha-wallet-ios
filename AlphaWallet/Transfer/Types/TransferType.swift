// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import TrustKeystore

enum TransferType {
    case ether(config: Config, destination: Address?)
    case ERC20Token(TokenObject)
    case ERC875Token(TokenObject)
    case ERC875TokenOrder(TokenObject)
    case ERC721Token(TokenObject)
}

extension TransferType {
    func symbol(server: RPCServer) -> String {
        switch self {
        case .ether:
            return server.symbol
        case .ERC20Token(let token):
            return token.symbol
        case .ERC875Token(let token):
            return token.symbol
        case .ERC875TokenOrder(let token):
            return token.symbol
        case .ERC721Token(let token):
            return token.symbol
        }
    }

    func contract() -> Address {
        switch self {
        case .ether(let config, _):
            return Address(string: TokensDataStore.etherToken(for: config).contract)!
        case .ERC20Token(let token):
            return Address(string: token.contract)!
        case .ERC875Token(let token):
            return Address(string: token.contract)!
        case .ERC875TokenOrder(let token):
            return Address(string: token.contract)!
        case .ERC721Token(let token):
            return Address(string: token.contract)!
        }
    }
}
