//
//  TransactionBuilder.swift
//  AlphaWalletFoundation
//
//  Created by Vladyslav Shepitko on 21.01.2023.
//

import Foundation
import BigInt
import Combine

public final class TransactionBuilder {
    private typealias ContractData = (name: String, symbol: String, decimals: Int, tokenType: TokenType)

    private let tokensDataStore: TokensDataStore
    private let ercTokenProvider: TokenProviderType

    let server: RPCServer

    public init(tokensDataStore: TokensDataStore,
                server: RPCServer,
                ercTokenProvider: TokenProviderType) {

        self.ercTokenProvider = ercTokenProvider
        self.tokensDataStore = tokensDataStore
        self.server = server
    }

    func buildTransaction(from transaction: NormalTransaction) -> AnyPublisher<Transaction?, Never> {
        guard let from = AlphaWallet.Address(string: transaction.from) else {
            return .just(nil)
        }

        let state: TransactionState = {
            if transaction.error?.isEmpty == false || transaction.isError == "1" {
                return .error
            }
            return .completed
        }()

        let to = AlphaWallet.Address(string: transaction.to)?.eip55String ?? transaction.to

        return buildOperationForTokenTransfer(for: transaction)
            .map { [server] operations -> Transaction? in
                return Transaction(
                        id: transaction.hash,
                        server: server,
                        blockNumber: Int(transaction.blockNumber)!,
                        transactionIndex: Int(transaction.transactionIndex)!,
                        from: from.description,
                        to: to,
                        value: transaction.value,
                        gas: transaction.gas,
                        gasPrice: BigUInt(transaction.gasPrice.drop0x).flatMap { GasPrice.legacy(gasPrice: $0) },
                        gasUsed: transaction.gasUsed,
                        nonce: transaction.nonce,
                        date: NSDate(timeIntervalSince1970: TimeInterval(transaction.timeStamp) ?? 0) as Date,
                        localizedOperations: operations,
                        state: state,
                        isErc20Interaction: false)
            }.eraseToAnyPublisher()
    }

    private func fetchLocalizedOperation(value: BigUInt,
                                         from: String,
                                         contract: AlphaWallet.Address,
                                         to recipient: AlphaWallet.Address,
                                         functionCall: DecodedFunctionCall) -> AnyPublisher<[LocalizedOperation], Never> {

        fetchLocalizedOperation(contract: contract)
            .map { token -> [LocalizedOperation] in
                let operationType = self.mapTokenTypeToTransferOperationType(token.tokenType, functionCall: functionCall)
                let result = LocalizedOperation(
                    from: from,
                    to: recipient.eip55String,
                    contract: contract,
                    type: operationType.rawValue,
                    value: String(value),
                    tokenId: "",
                    symbol: token.symbol,
                    name: token.name,
                    decimals: token.decimals)

                return [result]
            }.replaceError(with: [])
            .eraseToAnyPublisher()
    }

    private func fetchLocalizedOperation(contract: AlphaWallet.Address) -> AnyPublisher<TransactionBuilder.ContractData, SessionTaskError> {
        return Just(contract)
            .setFailureType(to: SessionTaskError.self)
            .flatMap { [tokensDataStore, ercTokenProvider, server] contract -> AnyPublisher<TransactionBuilder.ContractData, SessionTaskError> in
                if let token = tokensDataStore.token(for: contract, server: server) {
                    return .just((name: token.name, symbol: token.symbol, decimals: token.decimals, tokenType: token.type))
                } else {
                    let getContractName = ercTokenProvider.getContractName(for: contract)
                    let getContractSymbol = ercTokenProvider.getContractSymbol(for: contract)
                    let getDecimals = ercTokenProvider.getDecimals(for: contract)
                    let getTokenType = ercTokenProvider.getTokenType(for: contract)

                    return Publishers.CombineLatest4(getContractName, getContractSymbol, getDecimals, getTokenType)
                        .map { (name: $0, symbol: $1, decimals: $2, tokenType: $3) }
                        .eraseToAnyPublisher()
                }
            }.eraseToAnyPublisher()
    }

    private func buildOperationForTokenTransfer(for transaction: NormalTransaction) -> AnyPublisher<[LocalizedOperation], Never> {
        guard let contract = transaction.toAddress else {
            return .just([])
        }

        if let functionCall = DecodedFunctionCall(data: Data(hex: transaction.input)) {
            switch functionCall.type {
            case .erc20Transfer(let recipient, let value):
                return fetchLocalizedOperation(value: value, from: transaction.from, contract: contract, to: recipient, functionCall: functionCall)
            case .erc20Approve(let spender, let value):
                return fetchLocalizedOperation(value: value, from: transaction.from, contract: contract, to: spender, functionCall: functionCall)
            case .erc721ApproveAll(let spender, let value):
                //TODO support ERC721 setApprovalForAll(). Can't support at the moment because different types for `value`
                break
            case .nativeCryptoTransfer, .others:
                break
            case .erc1155SafeTransfer, .erc1155SafeBatchTransfer:
                break
            }
        }

        return .just([])
    }

    private func mapTokenTypeToTransferOperationType(_ tokenType: TokenType, functionCall: DecodedFunctionCall) -> OperationType {
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
