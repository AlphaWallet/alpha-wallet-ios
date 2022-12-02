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

    public func buildAnyDappTransaction(bridgeTransaction: RawTransactionBridge) throws -> UnconfirmedTransaction {
        guard case .dapp = self else { throw TransactionConfiguratorError.impossibleToBuildConfiguration }

        return UnconfirmedTransaction(transactionType: self, bridgeTransaction: bridgeTransaction)
    }

    public func buildSendNativeCryptocurrency(recipient: AlphaWallet.Address, amount: BigUInt) throws -> UnconfirmedTransaction {
        switch self {
        case .nativeCryptocurrency, .dapp, .claimPaidErc875MagicLink, .tokenScript, .prebuilt:
            break //TODO: review codebase and remove `.dapp, .claimPaidErc875MagicLink, .tokenScript, .prebuilt` from send screen
        case .erc20Token, .erc875Token, .erc721Token, .erc721ForTicketToken, .erc1155Token:
            throw TransactionConfiguratorError.impossibleToBuildConfiguration
        }

        return UnconfirmedTransaction(transactionType: self, value: amount, recipient: recipient, contract: nil, data: Data())
    }

    public func buildSendErc20Token(recipient: AlphaWallet.Address, amount: BigUInt) throws -> UnconfirmedTransaction {
        //TODO: remove amount from param and use from transaction type
        guard case .erc20Token(let token, _, _) = self else { throw TransactionConfiguratorError.impossibleToBuildConfiguration }

        let data = (try? Erc20Transfer(recipient: recipient, value: amount).encodedABI()) ?? Data()
        return UnconfirmedTransaction(transactionType: self, value: amount, recipient: recipient, contract: token.contractAddress, data: data)
    }

    public func buildSendErc1155Token(recipient: AlphaWallet.Address, account: AlphaWallet.Address) throws -> UnconfirmedTransaction {
        guard case .erc1155Token(_, let tokenHolders) = self else { throw TransactionConfiguratorError.impossibleToBuildConfiguration }

        //NOTE: we have to make sure that token holders have the same contract address!
        guard let tokenHolder = tokenHolders.first else { throw TransactionConfiguratorError.impossibleToBuildConfiguration }

        let tokenIdsAndValues: [TokenSelection] = tokenHolders.flatMap { $0.selections }

        let data: Data
        if tokenIdsAndValues.count == 1 {
            data = (try? Erc1155SafeTransferFrom(recipient: recipient, account: account, tokenIdAndValue: tokenIdsAndValues[0]).encodedABI()) ?? Data()
        } else {
            data = (try? Erc1155SafeBatchTransferFrom(recipient: recipient, account: account, tokenIdsAndValues: tokenIdsAndValues).encodedABI())  ?? Data()
        }

        return UnconfirmedTransaction(transactionType: self, value: BigUInt(0), recipient: recipient, contract: tokenHolder.contractAddress, data: data)
    }

    public func buildSendErc721Token(recipient: AlphaWallet.Address, account: AlphaWallet.Address) throws -> UnconfirmedTransaction {
        switch self {
        case .erc875Token(let token, let tokenHolders):
            guard let tokenHolder = tokenHolders.first else { throw TransactionConfiguratorError.impossibleToBuildConfiguration }

            let data = (try? Erc875Transfer(contractAddress: token.contractAddress, recipient: recipient, indices: tokenHolder.indices).encodedABI()) ?? Data()
            return UnconfirmedTransaction(transactionType: self, value: BigUInt(0), recipient: recipient, contract: tokenHolder.contractAddress, data: data)
        case .erc721Token(_, let tokenHolders), .erc721ForTicketToken(_, let tokenHolders):
            guard let tokenHolder = tokenHolders.first else { throw TransactionConfiguratorError.impossibleToBuildConfiguration }
            guard let token = tokenHolder.tokens.first else { throw TransactionConfiguratorError.impossibleToBuildConfiguration }

            let data: Data
            if tokenHolder.contractAddress.isLegacy721Contract {
                data = (try? Erc721TransferFrom(recipient: recipient, tokenId: token.id).encodedABI())  ?? Data()
            } else {
                data = (try? Erc721SafeTransferFrom(recipient: recipient, account: account, tokenId: token.id).encodedABI()) ?? Data()
            }

            return UnconfirmedTransaction(transactionType: self, value: BigUInt(0), recipient: recipient, contract: tokenHolder.contractAddress, data: data)
        case .nativeCryptocurrency, .erc20Token, .erc1155Token, .dapp, .claimPaidErc875MagicLink, .tokenScript, .prebuilt:
            throw TransactionConfiguratorError.impossibleToBuildConfiguration
        }
    }

    public func buildClaimPaidErc875MagicLink(recipient: AlphaWallet.Address, signedOrder: SignedOrder) throws -> UnconfirmedTransaction {
        guard case .claimPaidErc875MagicLink = self else { throw TransactionConfiguratorError.impossibleToBuildConfiguration }

        func encodeOrder(signedOrder: SignedOrder, recipient: AlphaWallet.Address) throws -> Data {
            let signature = signedOrder.signature.substring(from: 2)
            let v = UInt8(signature.substring(from: 128), radix: 16)!
            let r = "0x" + signature.substring(with: Range(uncheckedBounds: (0, 64)))
            let s = "0x" + signature.substring(with: Range(uncheckedBounds: (64, 128)))
            let expiry = signedOrder.order.expiry

            let method: ContractMethod
            if let tokenIds = signedOrder.order.tokenIds, !tokenIds.isEmpty {
                method = Erc875SpawnPassTo(expiry: expiry, tokenIds: tokenIds, v: v, r: r, s: s, recipient: recipient)
            } else if signedOrder.order.nativeCurrencyDrop {
                method = Erc875DropCurrency(signedOrder: signedOrder, v: v, r: r, s: s, recipient: recipient)
            } else {
                let contractAddress = signedOrder.order.contractAddress
                let indices = signedOrder.order.indices
                method = Erc875Trade(contractAddress: contractAddress, v: v, r: r, s: s, expiry: expiry, indices: indices)
            }

            return try method.encodedABI()
        }

        let data = try encodeOrder(signedOrder: signedOrder, recipient: recipient)

        return UnconfirmedTransaction(transactionType: self, value: BigUInt(signedOrder.order.price), recipient: nil, contract: signedOrder.order.contractAddress, data: data)
    }

}
