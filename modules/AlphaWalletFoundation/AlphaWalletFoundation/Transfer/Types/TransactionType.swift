import Foundation
import BigInt

public enum Erc1155TokenTransactionType {
    case batchTransfer
    case singleTransfer
}

public enum TransactionType {
    public init(nonFungibleToken token: Token, tokenHolders: [TokenHolder]) {
        switch token.type {
        case .nativeCryptocurrency, .erc20:
            fatalError()
        case .erc875:
            self = .erc875Token(token, tokenHolders: tokenHolders)
        case .erc721:
            //NOTE: here we got only one token, using array to avoid optional
            self = .erc721Token(token, tokenHolders: tokenHolders)
        case .erc721ForTickets:
            self = .erc721ForTicketToken(token, tokenHolders: tokenHolders)
        case .erc1155:
            self = .erc1155Token(token, tokenHolders: tokenHolders)
        }
    }

    public init(fungibleToken token: Token, recipient: AddressOrEnsName? = nil, amount: String? = nil) {
        switch token.type {
        case .nativeCryptocurrency:
            let amount = amount.flatMap { EtherNumberFormatter().number(from: $0, units: .ether) }
            self = .nativeCryptocurrency(token, destination: recipient, amount: amount)
        case .erc20:
            //TODO why is this inconsistent with `.nativeCryptocurrency` which uses an integer value (i.e. taking into account decimals) instead
            self = .erc20Token(token, destination: recipient, amount: amount)
        case .erc875, .erc721, .erc721ForTickets, .erc1155:
            //NOTE: better to throw error than use incorrect state
            fatalError()
        }
    }

    case nativeCryptocurrency(Token, destination: AddressOrEnsName?, amount: BigInt?)
    //TODO: replace string with BigInt
    case erc20Token(Token, destination: AddressOrEnsName?, amount: String?)
    case erc875Token(Token, tokenHolders: [TokenHolder])
    case erc721Token(Token, tokenHolders: [TokenHolder])
    case erc721ForTicketToken(Token, tokenHolders: [TokenHolder])
    case erc1155Token(Token, tokenHolders: [TokenHolder])
    case dapp(Token, DAppRequester)
    case claimPaidErc875MagicLink(Token)
    case tokenScript(Token)
    //TODO replace some of those above with this?
    case prebuilt(RPCServer)
}

extension TransactionType {

    public var symbol: String {
        switch self {
        case .nativeCryptocurrency(let server, _, _):
            return server.symbol
        case .dapp(let token, _), .tokenScript(let token):
            return token.symbol
        case .erc20Token(let token, _, _):
            return token.symbol
        case .erc875Token(let token, _):
            return token.symbol
        case .erc721Token(let token, _):
            return token.symbol
        case .erc721ForTicketToken(let token, _):
            return token.symbol
        case .erc1155Token(let token, _):
            return token.symbol
        case .claimPaidErc875MagicLink(let token):
            return token.symbol
        case .prebuilt:
            //Not applicable
            return ""
        }
    }

    public var tokenObject: Token {
        switch self {
        case .nativeCryptocurrency(let token, _, _):
            return token
        case .dapp(let token, _), .tokenScript(let token):
            return token
        case .erc20Token(let token, _, _):
            return token
        case .erc875Token(let token, _):
            return token
        case .erc721Token(let token, _):
            return token
        case .erc721ForTicketToken(let token, _):
            return token
        case .erc1155Token(let token, _):
            return token
        case .claimPaidErc875MagicLink(let token):
            return token
        case .prebuilt(let server):
            //Not applicable
            return MultipleChainsTokensDataStore.functional.etherToken(forServer: server)
        }
    }

    public var server: RPCServer {
        switch self {
        case .nativeCryptocurrency(let token, _, _):
            return token.server
        case .dapp(let token, _), .tokenScript(let token):
            return token.server
        case .erc20Token(let token, _, _):
            return token.server
        case .erc875Token(let token, _):
            return token.server
        case .erc721Token(let token, _):
            return token.server
        case .erc721ForTicketToken(let token, _):
            return token.server
        case .erc1155Token(let token, _):
            return token.server
        case .claimPaidErc875MagicLink(let token):
            return token.server
        case .prebuilt(let server):
             return server
        }
    }

    public var contract: AlphaWallet.Address {
        switch self {
        case .nativeCryptocurrency:
            return Constants.nativeCryptoAddressInDatabase
        case .erc20Token(let token, _, _):
            return token.contractAddress
        case .erc875Token(let token, _):
            return token.contractAddress
        case .erc721Token(let token, _):
            return token.contractAddress
        case .erc721ForTicketToken(let token, _):
            return token.contractAddress
        case .erc1155Token(let token, _):
            return token.contractAddress
        case .dapp(let token, _), .tokenScript(let token), .claimPaidErc875MagicLink(let token):
            return token.contractAddress
        case .prebuilt:
            //We don't care about the contract for prebuilt transactions
            return Constants.nativeCryptoAddressInDatabase
        }
    }
}

extension TransactionType {
    public enum Configuration {
        case tokenScriptTransaction(confirmType: ConfirmType, contract: AlphaWallet.Address, functionCallMetaData: DecodedFunctionCall)
        case dappTransaction(confirmType: ConfirmType)
        case walletConnect(confirmType: ConfirmType, requester: RequesterViewModel)
        case sendFungiblesTransaction(confirmType: ConfirmType, amount: FungiblesTransactionAmount)
        case sendNftTransaction(confirmType: ConfirmType)
        case claimPaidErc875MagicLink(confirmType: ConfirmType, price: BigUInt, numberOfTokens: UInt)
        case speedupTransaction
        case cancelTransaction
        case swapTransaction(fromToken: TokenToSwap, fromAmount: BigUInt, toToken: TokenToSwap, toAmount: BigUInt)
        //TODO: generalize type name so it can be used for more types (some of the enum-cases above), if possible
        case approve

        public var confirmType: ConfirmType {
            switch self {
            case .dappTransaction(let confirmType), .walletConnect(let confirmType, _), .sendFungiblesTransaction(let confirmType, _), .sendNftTransaction(let confirmType), .tokenScriptTransaction(let confirmType, _, _), .claimPaidErc875MagicLink(let confirmType, _, _):
                return confirmType
            case .speedupTransaction, .cancelTransaction, .swapTransaction, .approve:
                return .signThenSend
            }
        }
    }
}
