import Foundation
import BigInt

enum Erc1155TokenTransactionType {
    case batchTransfer
    case singleTransfer
}

enum TransactionType {
    init(token: TokenObject, tokenHolders: [TokenHolder]) {
        self = {
            switch token.type {
            case .nativeCryptocurrency:
                return .nativeCryptocurrency(token, destination: nil, amount: nil)
            case .erc20:
                //TODO why is this inconsistent with `.nativeCryptocurrency` which uses an integer value (i.e. taking into account decimals) instead
                return .erc20Token(token, destination: nil, amount: nil)
            case .erc875:
                return .erc875Token(token, tokenHolders: tokenHolders)
            case .erc721:
                //NOTE: here we got only one token, using array to avoid optional
                return .erc721Token(token, tokenHolders: tokenHolders)
            case .erc721ForTickets:
                return .erc721ForTicketToken(token, tokenHolders: tokenHolders)
            case .erc1155:
                return .erc1155Token(token, transferType: .singleTransfer, tokenHolders: tokenHolders)
            }
        }()
    }

    init(token: TokenObject, recipient: AddressOrEnsName? = nil, amount: String? = nil) {
        self = {
            switch token.type {
            case .nativeCryptocurrency:
                return .nativeCryptocurrency(token, destination: recipient, amount: amount.flatMap {
                    EtherNumberFormatter().number(from: $0, units: .ether)
                })
            case .erc20:
                //TODO why is this inconsistent with `.nativeCryptocurrency` which uses an integer value (i.e. taking into account decimals) instead
                return .erc20Token(token, destination: recipient, amount: amount)
            case .erc875:
                return .erc875Token(token, tokenHolders: [])
            case .erc721:
                //NOTE: here we got only one token, using array to avoid optional
                return .erc721Token(token, tokenHolders: [])
            case .erc721ForTickets:
                return .erc721ForTicketToken(token, tokenHolders: [])
            case .erc1155:
                return .erc1155Token(token, transferType: .singleTransfer, tokenHolders: [])
            }
        }()
    }

    case nativeCryptocurrency(TokenObject, destination: AddressOrEnsName?, amount: BigInt?)
    case erc20Token(TokenObject, destination: AddressOrEnsName?, amount: String?)
    case erc875Token(TokenObject, tokenHolders: [TokenHolder])
    case erc875TokenOrder(TokenObject, tokenHolders: [TokenHolder])
    case erc721Token(TokenObject, tokenHolders: [TokenHolder])
    case erc721ForTicketToken(TokenObject, tokenHolders: [TokenHolder])
    case erc1155Token(TokenObject, transferType: Erc1155TokenTransactionType, tokenHolders: [TokenHolder])
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
        case .erc875Token(let token, _):
            return token.symbol
        case .erc875TokenOrder(let token, _):
            return token.symbol
        case .erc721Token(let token, _):
            return token.symbol
        case .erc721ForTicketToken(let token, _):
            return token.symbol
        case .erc1155Token(let token, _, _):
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
        case .erc875Token(let token, _):
            return token
        case .erc875TokenOrder(let token, _):
            return token
        case .erc721Token(let token, _):
            return token
        case .erc721ForTicketToken(let token, _):
            return token
        case .erc1155Token(let token, _, _):
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
        case .erc875Token(let token, _):
            return token.server
        case .erc875TokenOrder(let token, _):
            return token.server
        case .erc721Token(let token, _):
            return token.server
        case .erc721ForTicketToken(let token, _):
            return token.server
        case .erc1155Token(let token, _, _):
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
        case .erc875Token(let token, _):
            return token.contractAddress
        case .erc875TokenOrder(let token, _):
            return token.contractAddress
        case .erc721Token(let token, _):
            return token.contractAddress
        case .erc721ForTicketToken(let token, _):
            return token.contractAddress
        case .erc1155Token(let token, _, _):
            return token.contractAddress
        case .dapp(let token, _), .tokenScript(let token), .claimPaidErc875MagicLink(let token):
            return token.contractAddress
        }
    }
}
