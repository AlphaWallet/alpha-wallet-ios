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
    private typealias LocalizedOperation = (name: String, symbol: String, decimals: Int, tokenType: TokenType)

    private let tokenProvidable: TokenProvidable
    private let ercProvider: TokenProviderType

    let server: RPCServer

    public init(tokensService: TokenProvidable,
                server: RPCServer,
                tokenProvider: TokenProviderType) {

        self.ercProvider = tokenProvider
        self.tokenProvidable = tokensService
        self.server = server
    }

    func buildTransaction(from transaction: NormalTransaction) -> AnyPublisher<TransactionInstance?, Never> {
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
            .map { [server] operations -> TransactionInstance? in
                return TransactionInstance(
                        id: transaction.hash,
                        server: server,
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
                        isErc20Interaction: false)
            }.eraseToAnyPublisher()
    }

    private func fetchLocalizedOperation(value: BigUInt,
                                         from: String,
                                         contract: AlphaWallet.Address,
                                         to recipient: AlphaWallet.Address,
                                         functionCall: DecodedFunctionCall) -> AnyPublisher<[LocalizedOperationObjectInstance], Never> {

        Future { try await self.fetchLocalizedOperation(contract: contract) }
            .map { token -> [LocalizedOperationObjectInstance] in
                let operationType = self.mapTokenTypeToTransferOperationType(token.tokenType, functionCall: functionCall)
                let result = LocalizedOperationObjectInstance(
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

    private func fetchLocalizedOperation(contract: AlphaWallet.Address) async throws -> TransactionBuilder.LocalizedOperation {
        if let token = tokenProvidable.token(for: contract, server: server) {
            return (name: token.name, symbol: token.symbol, decimals: token.decimals, tokenType: token.type)
        } else {
            let name = try await ercProvider.getContractName(for: contract)
            let symbol = try await ercProvider.getContractSymbol(for: contract)
            let decimals = try await ercProvider.getDecimals(for: contract)
            let tokenType = try await ercProvider.getTokenType(for: contract)

            return (name: name, symbol: symbol, decimals: decimals, tokenType: tokenType)
        }
    }

    private func buildOperationForTokenTransfer(for transaction: NormalTransaction) -> AnyPublisher<[LocalizedOperationObjectInstance], Never> {
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
