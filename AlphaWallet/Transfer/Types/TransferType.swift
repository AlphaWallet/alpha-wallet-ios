// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import BigInt

struct Transfer {
    let server: RPCServer
    let type: TransferType
}

enum TransferType {
    init(token: TokenObject) {
        self = {
            switch token.type {
            case .nativeCryptocurrency:
                return .nativeCryptocurrency(server: token.server, destination: nil, amount: nil)
            case .erc20:
                return .ERC20Token(token, destination: nil, amount: nil)
            case .erc875:
                return .ERC875Token(token)
            case .erc721:
                return .ERC721Token(token)
            }
        }()
    }

    case nativeCryptocurrency(server: RPCServer, destination: AlphaWallet.Address?, amount: BigInt?)
    case ERC20Token(TokenObject, destination: AlphaWallet.Address?, amount: String?)
    case ERC875Token(TokenObject)
    case ERC875TokenOrder(TokenObject)
    case ERC721Token(TokenObject)
    case dapp(TokenObject, DAppRequester)
}

extension TransferType {
    var symbol: String {
        switch self {
        case .nativeCryptocurrency(let server, _, _):
            return server.symbol
        case .dapp(let token, _):
            return token.symbol
        case .ERC20Token(let token, _, _):
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
        case .nativeCryptocurrency(let server, _, _):
            return server
        case .dapp(let token, _):
            return token.server
        case .ERC20Token(let token, _, _):
            return token.server
        case .ERC875Token(let token):
            return token.server
        case .ERC875TokenOrder(let token):
            return token.server
        case .ERC721Token(let token):
            return token.server
        }
    }

    var contract: AlphaWallet.Address {
        switch self {
        case .nativeCryptocurrency:
            return Constants.nativeCryptoAddressInDatabase
        case .ERC20Token(let token, _, _):
            return token.contractAddress
        case .ERC875Token(let token):
            return token.contractAddress
        case .ERC875TokenOrder(let token):
            return token.contractAddress
        case .ERC721Token(let token):
            return token.contractAddress
        case .dapp(let token, _):
            return token.contractAddress
        }
    }
}
