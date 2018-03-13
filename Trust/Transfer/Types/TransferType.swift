// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import TrustKeystore

enum TransferType {
    case ether(destination: Address?)
    case token(TokenObject)
    case stormBird(TokenObject)
    case stormBirdOrder(TokenObject)
}

extension TransferType {
    func symbol(server: RPCServer) -> String {
        switch self {
        case .ether:
            return server.symbol
        case .token(let token):
            return token.symbol
        case .stormBird(let token):
            return token.symbol
        case .stormBirdOrder(let token):
            return token.symbol
        }
    }

    func contract() -> Address {
        switch self {
        case .ether:
            return Address(string: TokensDataStore.etherToken(for: Config()).contract)!
        case .token(let token):
            return Address(string: token.contract)!
        case .stormBird(let token):
            return Address(string: token.contract)!
        case .stormBirdOrder(let token):
            return Address(string: token.contract)!
        }
    }
}
