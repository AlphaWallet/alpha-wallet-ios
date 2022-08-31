// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import BigInt
import PromiseKit

struct RawTransaction: Decodable {
    let hash: String
    let blockNumber: String
    let transactionIndex: String
    let timeStamp: String
    let nonce: String
    let from: String
    let to: String
    let value: String
    let gas: String
    let gasPrice: String
    let input: String
    let gasUsed: String
    let error: String?
    let isError: String?

    ///
    ///It is possible for the etherscan.io API to return an empty `to` even if the transaction actually has a `to`. It doesn't seem to be linked to `"isError" = "1"`, because other transactions that fail (with isError="1") has a non-empty `to`.
    ///
    ///Eg. transaction with an empty `to` in API despite `to` is shown as non-empty in the etherscan.io web page:https: //ropsten.etherscan.io/tx/0x0c87d2acb0ecaf1221e599ad4f65edf77c97956d6534feb0afa68ee5c41c4e28
    ///
    ///So it must be a optional
    var toAddress: AlphaWallet.Address? {
        //TODO We use the unchecked version because it was easier to provide an Address instance this way. Good to remove it
        return AlphaWallet.Address(uncheckedAgainstNullAddress: to)
    }

    enum CodingKeys: String, CodingKey {
        case hash = "hash"
        case blockNumber
        case transactionIndex
        case timeStamp
        case nonce
        case from
        case to
        case value
        case gas
        case gasPrice
        case input
        case gasUsed
        case operationsLocalized = "operations"
        case error = "error"
        case isError = "isError"
    }

    let operationsLocalized: [LocalizedOperation]?
}

extension TransactionInstance {
    static func from(transaction: RawTransaction, tokensService: TokenProvidable, session: WalletSession) -> Promise<TransactionInstance?> {
        guard let from = AlphaWallet.Address(string: transaction.from) else {
            return Promise.value(nil)
        }

        let state: TransactionState = {
            if transaction.error?.isEmpty == false || transaction.isError == "1" {
                return .error
            }
            return .completed
        }()

        let to = AlphaWallet.Address(string: transaction.to)?.eip55String ?? transaction.to

        return firstly {
            createOperationForTokenTransfer(forTransaction: transaction, tokensService: tokensService, session: session)
        }.then(on: session.queue, { operations -> Promise<TransactionInstance?> in
            let result = TransactionInstance(
                    id: transaction.hash,
                    server: session.server,
                    blockNumber: Int(transaction.blockNumber)!,
                    transactionIndex: Int(transaction.transactionIndex)!,
                    from: from.description,
                    to: to,
                    value: transaction.value,
                    gas: transaction.gas,
                    gasPrice: transaction.gasPrice,
                    gasUsed: transaction.gasUsed,
                    nonce: transaction.nonce,
                    date: NSDate(timeIntervalSince1970: TimeInterval(transaction.timeStamp) ?? 0) as Date,
                    localizedOperations: operations,
                    state: state,
                    isErc20Interaction: false
            )

            return .value(result)
        })
    }

    static private func createOperationForTokenTransfer(forTransaction transaction: RawTransaction, tokensService: TokenProvidable, session: WalletSession) -> Promise<[LocalizedOperationObjectInstance]> {
        guard let contract = transaction.toAddress else {
            return Promise.value([])
        }

        func generateLocalizedOperation(value: BigUInt, contract: AlphaWallet.Address, to recipient: AlphaWallet.Address, functionCall: DecodedFunctionCall, server: RPCServer) -> Promise<[LocalizedOperationObjectInstance]> {
            if let token = tokensService.token(for: contract, server: server) {
                let operationType = mapTokenTypeToTransferOperationType(token.type, functionCall: functionCall)
                let result = LocalizedOperationObjectInstance(from: transaction.from, to: recipient.eip55String, contract: contract, type: operationType.rawValue, value: String(value), tokenId: "", symbol: token.symbol, name: token.name, decimals: token.decimals)
                return .value([result])
            } else {
                let getContractName = session.tokenProvider.getContractName(for: contract)
                let getContractSymbol = session.tokenProvider.getContractSymbol(for: contract)
                let getDecimals = session.tokenProvider.getDecimals(for: contract)
                let getTokenType = session.tokenProvider.getTokenType(for: contract)

                return firstly {
                    when(fulfilled: getContractName, getContractSymbol, getDecimals, getTokenType)
                }.then(on: session.queue, { name, symbol, decimals, tokenType -> Promise<[LocalizedOperationObjectInstance]> in
                    let operationType = mapTokenTypeToTransferOperationType(tokenType, functionCall: functionCall)
                    let result = LocalizedOperationObjectInstance(from: transaction.from, to: recipient.eip55String, contract: contract, type: operationType.rawValue, value: String(value), tokenId: "", symbol: symbol, name: name, decimals: Int(decimals))
                    return .value([result])
                }).recover(on: session.queue, { _ -> Promise<[LocalizedOperationObjectInstance]> in
                    //NOTE: Return an empty array when failure to fetch contracts data, instead of failing whole TransactionInstance creating
                    return Promise.value([])
                })
            }
        }

        let data = Data(hex: transaction.input)
        if let functionCall = DecodedFunctionCall(data: data) {
            switch functionCall.type {
            case .erc20Transfer(let recipient, let value):
                return generateLocalizedOperation(value: value, contract: contract, to: recipient, functionCall: functionCall, server: session.server)
            case .erc20Approve(let spender, let value):
                return generateLocalizedOperation(value: value, contract: contract, to: spender, functionCall: functionCall, server: session.server)
            case .erc721ApproveAll(let spender, let value):
                //TODO support ERC721 setApprovalForAll(). Can't support at the moment because different types for `value`
                break
            case .nativeCryptoTransfer, .others:
                break
            case .erc1155SafeTransfer, .erc1155SafeBatchTransfer:
                break
            }
        }

        return Promise.value([])
    }

    static private func mapTokenTypeToTransferOperationType(_ tokenType: TokenType, functionCall: DecodedFunctionCall) -> OperationType {
        switch (tokenType, functionCall.type) {
        case (.nativeCryptocurrency, _):
            return .nativeCurrencyTokenTransfer
        case (.erc20, .erc20Approve):
            return .erc20TokenApprove
        case (.erc20, .erc20Transfer):
            return .erc20TokenTransfer
        case (.erc721, .erc721ApproveAll):
            return .erc721TokenApproveAll
        case (.erc721, _):
            return .erc721TokenTransfer
        case (.erc721ForTickets, _):
            return .erc721TokenTransfer
        case (.erc875, _):
            return .erc875TokenTransfer
        case (.erc1155, _):
            return .erc1155TokenTransfer
        case (.erc20, .nativeCryptoTransfer), (.erc20, .others):
            return .unknown
        case (_, _):
            return .unknown
        }
    }
}
