// Copyright SIX DAY LLC. All rights reserved.

import Foundation
import TrustKeystore
import BigInt
import PromiseKit

struct RawTransaction: Decodable {
    let hash: String
    let blockNumber: String
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

    enum CodingKeys: String, CodingKey {
        case hash = "hash"
        case blockNumber
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
    }

    let operationsLocalized: [LocalizedOperation]?
}

extension Transaction {
    static func from(transaction: RawTransaction, tokensStorage: TokensDataStore) -> Promise<Transaction?> {
        guard let from = Address(string: transaction.from) else {
            return Promise.value(nil)
        }
        let state: TransactionState = {
            if transaction.error?.isEmpty == false {
                return .error
            }
            return .completed
        }()
        let to = Address(string: transaction.to)?.description ?? transaction.to
        return firstly {
            createOperationForTokenTransfer(forTransaction: transaction, tokensStorage: tokensStorage)
        }.then { operations -> Promise<Transaction?> in
            let result = Transaction(
                    id: transaction.hash,
                    server: tokensStorage.server,
                    blockNumber: Int(transaction.blockNumber)!,
                    from: from.description,
                    to: to,
                    value: transaction.value,
                    gas: transaction.gas,
                    gasPrice: transaction.gasPrice,
                    gasUsed: transaction.gasUsed,
                    nonce: transaction.nonce,
                    date: NSDate(timeIntervalSince1970: TimeInterval(transaction.timeStamp) ?? 0) as Date,
                    localizedOperations: operations,
                    state: state)
            return .value(result)
        }
    }

    static private func createOperationForTokenTransfer(forTransaction transaction: RawTransaction, tokensStorage: TokensDataStore) -> Promise<[LocalizedOperationObject]> {
        guard transaction.input != "0x" else {
            return Promise.value([])
        }
        guard transaction.input.count == 138 else {
            return Promise.value([])
        }

        let functionHash = String(transaction.input[transaction.input.index(transaction.input.startIndex, offsetBy: 0)..<transaction.input.index(transaction.input.startIndex, offsetBy: 10)])
        //transfer(address _to, uint256 _value)
        let functionHasForERC20Transfer = "0xa9059cbb"
        switch functionHash {
        case functionHasForERC20Transfer:
            let amount1 = transaction.input[transaction.input.index(transaction.input.startIndex, offsetBy: 10 + 64)..<transaction.input.index(transaction.input.startIndex, offsetBy: 10 + 64 + 64)]
            let amount = BigInt(amount1, radix: 16)
            //Extract the address and strip the first 12 (x2 = 24) characters of 0s
            let to = "0x\(transaction.input[transaction.input.index(transaction.input.startIndex, offsetBy: 10 + 24)..<transaction.input.index(transaction.input.startIndex, offsetBy: 10 + 64)])"
            if let amount = amount, let to = Address(string: to)?.eip55String {
                let contract = transaction.to
                if let token = tokensStorage.token(forContract: contract) {
                    let operationType = mapTokenTypeToTransferOperationType(token.type)
                    let result = LocalizedOperationObject(from: transaction.from, to: to, contract: contract, type: operationType.rawValue, value: String(amount), symbol: token.symbol, name: token.name, decimals: token.decimals)
                    return .value([result])
                } else {
                    let getContractName = tokensStorage.getContractName(for: contract)
                    let getContractSymbol = tokensStorage.getContractSymbol(for: contract)
                    let getDecimals = tokensStorage.getDecimals(for: contract)
                    let getTokenType = tokensStorage.getTokenType(for: contract)
                    return firstly {
                        when(fulfilled: getContractName, getContractSymbol, getDecimals, getTokenType )
                    }.then { name, symbol, decimals, tokenType -> Promise<[LocalizedOperationObject]> in
                        let operationType = mapTokenTypeToTransferOperationType(tokenType)
                        let result = LocalizedOperationObject(from: transaction.from, to: to, contract: contract, type: operationType.rawValue, value: String(amount), symbol: symbol, name: name, decimals: Int(decimals))
                        return .value([result])
                    }
                }
            } else {
                return Promise.value([])
            }
        default:
            return Promise.value([])
        }
    }

    static private func mapTokenTypeToTransferOperationType(_ tokenType: TokenType) -> OperationType {
        switch tokenType {
        case .nativeCryptocurrency:
            return .nativeCurrencyTokenTransfer
        case .erc20:
            return .erc20TokenTransfer
        case .erc721:
            return .erc721TokenTransfer
        case .erc875:
            return .erc875TokenTransfer
        }
    }
}
