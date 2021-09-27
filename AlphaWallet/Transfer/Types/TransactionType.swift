import Foundation
import BigInt

enum TransactionType {
    init(token: TokenObject, recipient: AddressOrEnsName? = nil, amount: String? = nil) {
        self = {
            switch token.type {
            case .nativeCryptocurrency:
                return .nativeCryptocurrency(token, destination: recipient, amount: amount.flatMap { EtherNumberFormatter().number(from: $0, units: .ether) })
            case .erc20:
                //TODO why is this inconsistent with `.nativeCryptocurrency` which uses an integer value (i.e. taking into account decimals) instead
                return .erc20Token(token, destination: recipient, amount: amount)
            case .erc875:
                return .erc875Token(token)
            case .erc721:
                return .erc721Token(token)
            case .erc721ForTickets:
                return .erc721ForTicketToken(token)
            case .erc1155:
                return .erc1155Token(token)
            }
        }()
    }

    case nativeCryptocurrency(TokenObject, destination: AddressOrEnsName?, amount: BigInt?)
    case erc20Token(TokenObject, destination: AddressOrEnsName?, amount: String?)
    case erc875Token(TokenObject)
    case erc875TokenOrder(TokenObject)
    case erc721Token(TokenObject)
    case erc721ForTicketToken(TokenObject)
    case erc1155Token(TokenObject)
    case dapp(TokenObject, DAppRequester)
    case claimPaidErc875MagicLink(TokenObject)
    case tokenScript(TokenObject)

    var contractForFungibleSend: AlphaWallet.Address? {
        switch self {
        case .nativeCryptocurrency:
            return nil
        case .erc20Token(let token, _, _):
            return token.contractAddress
        case .dapp, .tokenScript, .erc875Token, .erc875TokenOrder, .erc721Token, .erc721ForTicketToken, .erc1155Token, .claimPaidErc875MagicLink:
            return nil
        }
    }

    var addressAndRPCServer: AddressAndRPCServer {
        AddressAndRPCServer(address: tokenObject.contractAddress, server: server)
    }
}

extension TransactionType {

    var symbol: String {
        switch self {
        case .nativeCryptocurrency(let server, _, _):
            return server.symbol
        case .dapp(let token, _), .tokenScript(let token):
            return token.symbol
        case .erc20Token(let token, _, _):
            return token.symbol
        case .erc875Token(let token):
            return token.symbol
        case .erc875TokenOrder(let token):
            return token.symbol
        case .erc721Token(let token):
            return token.symbol
        case .erc721ForTicketToken(let token):
            return token.symbol
        case .erc1155Token(let token):
            return token.symbol
        case .claimPaidErc875MagicLink(let token):
            return token.symbol
        }
    }

    var tokenObject: TokenObject {
        switch self {
        case .nativeCryptocurrency(let token, _, _):
            return token
        case .dapp(let token, _), .tokenScript(let token):
            return token
        case .erc20Token(let token, _, _):
            return token
        case .erc875Token(let token):
            return token
        case .erc875TokenOrder(let token):
            return token
        case .erc721Token(let token):
            return token
        case .erc721ForTicketToken(let token):
            return token
        case .erc1155Token(let token):
            return token
        case .claimPaidErc875MagicLink(let token):
            return token
        }
    }

    var server: RPCServer {
        switch self {
        case .nativeCryptocurrency(let token, _, _):
            return token.server
        case .dapp(let token, _), .tokenScript(let token):
            return token.server
        case .erc20Token(let token, _, _):
            return token.server
        case .erc875Token(let token):
            return token.server
        case .erc875TokenOrder(let token):
            return token.server
        case .erc721Token(let token):
            return token.server
        case .erc721ForTicketToken(let token):
            return token.server
        case .erc1155Token(let token):
            return token.server
        case .claimPaidErc875MagicLink(let token):
            return token.server
        }
    }

    var contract: AlphaWallet.Address {
        switch self {
        case .nativeCryptocurrency:
            return Constants.nativeCryptoAddressInDatabase
        case .erc20Token(let token, _, _):
            return token.contractAddress
        case .erc875Token(let token):
            return token.contractAddress
        case .erc875TokenOrder(let token):
            return token.contractAddress
        case .erc721Token(let token):
            return token.contractAddress
        case .erc721ForTicketToken(let token):
            return token.contractAddress
        case .erc1155Token(let token):
            return token.contractAddress
        case .dapp(let token, _), .tokenScript(let token), .claimPaidErc875MagicLink(let token):
            return token.contractAddress
        }
    }
}