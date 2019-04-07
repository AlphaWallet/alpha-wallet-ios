// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import TrustKeystore

struct Transfer {
    let server: RPCServer
    let type: TransferType
}

enum TransferType {
    init(token: TokenObject) {
        self = {
            switch token.type {
			case .nativeCryptocurrency:
                return .nativeCryptocurrency(server: token.server, destination: nil)
            case .erc20:
                return .ERC20Token(token)
            case .erc875:
                return .ERC875Token(token)
            case .erc721:
                return .ERC721Token(token)
            }
        }()
    }

    case nativeCryptocurrency(server: RPCServer, destination: Address?)
    case ERC20Token(TokenObject)
    case ERC875Token(TokenObject)
    case ERC875TokenOrder(TokenObject)
    case ERC721Token(TokenObject)
    case dapp(TokenObject, DAppRequester)
}

extension TransferType {
    var symbol: String {
        switch self {
        case .nativeCryptocurrency(let server, _):
            return server.symbol
        case .dapp(let token, _):
            return token.symbol
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

    var server: RPCServer {
        switch self {
        case .nativeCryptocurrency(let server, _):
            return server
        case .dapp(let token, _):
            return token.server
        case .ERC20Token(let token):
            return token.server
        case .ERC875Token(let token):
            return token.server
        case .ERC875TokenOrder(let token):
            return token.server
        case .ERC721Token(let token):
            return token.server
        }
    }

    func contract() -> Address {
        switch self {
        case .nativeCryptocurrency:
            return Address(uncheckedAgainstNullAddress: Constants.nativeCryptoAddressInDatabase)!
        case .ERC20Token(let token):
            return Address(string: token.contract)!
        case .ERC875Token(let token):
            return Address(string: token.contract)!
        case .ERC875TokenOrder(let token):
            return Address(string: token.contract)!
        case .ERC721Token(let token):
            return Address(string: token.contract)!
        case .dapp(let token, _):
            return Address(string: token.contract)!
        }
    }
}
