// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import BigInt

struct Transfer {
    let server: RPCServer
    let type: TransferType
}

enum TransferType {
    init(token: TokenObject, recipient: AddressOrEnsName? = nil, amount: String? = nil) {
        self = {
            switch token.type {
            case .nativeCryptocurrency:
                return .nativeCryptocurrency(token, destination: recipient, amount: amount.flatMap { EtherNumberFormatter().number(from: $0, units: .ether) })
            case .erc20:
                //TODO why is this inconsistent with `.nativeCryptocurrency` which uses an integer value (i.e. taking into account decimals) instead
                return .ERC20Token(token, destination: recipient, amount: amount)
            case .erc875:
                return .ERC875Token(token)
            case .erc721:
                return .ERC721Token(token)
            case .erc721ForTickets:
                return .ERC721ForTicketToken(token)
            }
        }()
    }

    case nativeCryptocurrency(TokenObject, destination: AddressOrEnsName?, amount: BigInt?)
    case ERC20Token(TokenObject, destination: AddressOrEnsName?, amount: String?)
    case ERC875Token(TokenObject)
    case ERC875TokenOrder(TokenObject)
    case ERC721Token(TokenObject)
    case ERC721ForTicketToken(TokenObject)
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
        case .ERC721ForTicketToken(let token):
            return token.symbol
        }
    }

    var tokenObject: TokenObject {
        switch self {
        case .nativeCryptocurrency(let token, _, _):
            return token
        case .dapp(let token, _):
            return token
        case .ERC20Token(let token, _, _):
            return token
        case .ERC875Token(let token):
            return token
        case .ERC875TokenOrder(let token):
            return token
        case .ERC721Token(let token):
            return token
        case .ERC721ForTicketToken(let token):
            return token
        }
    }

    var server: RPCServer {
        switch self {
        case .nativeCryptocurrency(let token, _, _):
            return token.server
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
        case .ERC721ForTicketToken(let token):
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
        case .ERC721ForTicketToken(let token):
            return token.contractAddress
        case .dapp(let token, _):
            return token.contractAddress
        }
    }
}
