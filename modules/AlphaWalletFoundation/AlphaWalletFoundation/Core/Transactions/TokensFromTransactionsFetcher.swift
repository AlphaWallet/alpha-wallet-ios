//
//  TokensFromTransactionsFetcher.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 01.04.2022.
//

import Foundation
import PromiseKit

public protocol TokensFromTransactionsFetcherDelegate: AnyObject {
    func didExtractTokens(in fetcher: TokensFromTransactionsFetcher, contractsAndServers: [AddressAndRPCServer], tokenUpdates: [TokenUpdate])
}

public final class TokensFromTransactionsFetcher {
    private let detectedTokens: DetectedContractsProvideble
    private let session: WalletSession

    public weak var delegate: TokensFromTransactionsFetcherDelegate?

    public init(detectedTokens: DetectedContractsProvideble, session: WalletSession) {
        self.detectedTokens = detectedTokens
        self.session = session
    }

    func extractNewTokens(from transactions: [TransactionInstance]) {
        guard !transactions.isEmpty else { return }
        self.filterTransactionsToPullContractsFrom(transactions)
            .done { [weak self] transactionsToPullContractsFrom, contractsAndTokenTypes in
                guard !transactionsToPullContractsFrom.isEmpty else { return }
                self?.addTokensFromUpdates(transactionsToPullContractsFrom: transactionsToPullContractsFrom, contractsAndTokenTypes: contractsAndTokenTypes)
            }.cauterize()
    }

    private func addTokensFromUpdates(transactionsToPullContractsFrom transactions: [TransactionInstance], contractsAndTokenTypes: [AlphaWallet.Address: TokenType]) {
        let tokenUpdates = TokensFromTransactionsFetcher.functional.tokens(from: transactions, contractsAndTokenTypes: contractsAndTokenTypes)
        let contractsAndServers = Array(Set(tokenUpdates.map { AddressAndRPCServer(address: $0.address, server: $0.server) }))

        delegate?.didExtractTokens(in: self, contractsAndServers: contractsAndServers, tokenUpdates: tokenUpdates)
    }

    private var contractsToAvoid: [AlphaWallet.Address] {
        let deletedContracts = detectedTokens.deletedContracts(for: session.server)
        let hiddenContracts = detectedTokens.hiddenContracts(for: session.server)
        let delegateContracts = detectedTokens.delegateContracts(for: session.server)
        let alreadyAddedContracts = detectedTokens.alreadyAddedContracts(for: session.server)

        return alreadyAddedContracts + deletedContracts + hiddenContracts + delegateContracts
    }

    private func filterTransactionsToPullContractsFrom(_ transactions: [TransactionInstance]) -> Promise<(transactions: [TransactionInstance], contractTypes: [AlphaWallet.Address: TokenType])> {
        let contractsToAvoid = contractsToAvoid
        let filteredTransactions = transactions.filter {
            if let toAddressToCheck = AlphaWallet.Address(string: $0.to), contractsToAvoid.contains(toAddressToCheck) {
                return false
            }
            if let contractAddressToCheck = $0.operation?.contractAddress, contractsToAvoid.contains(contractAddressToCheck) {
                return false
            }
            return true
        }

        //The fetch ERC20 transactions endpoint from Etherscan returns only ERC20 token transactions but the Blockscout version also includes ERC721 transactions too (so it's likely other types that it can detect will be returned too); thus we check the token type rather than assume that they are all ERC20
        let contracts = Array(Set(filteredTransactions.compactMap { $0.localizedOperations.first?.contractAddress }))
        let tokenTypePromises = contracts.map { session.tokenProvider.getTokenType(for: $0) }

        return when(fulfilled: tokenTypePromises)
            .map(on: session.queue, { tokenTypes in
                let contractsToTokenTypes = Dictionary(uniqueKeysWithValues: zip(contracts, tokenTypes))
                return (transactions: filteredTransactions, contractTypes: contractsToTokenTypes)
            })
    }
}

extension TokensFromTransactionsFetcher {
    class functional {}
}

extension TokensFromTransactionsFetcher.functional {

    static func tokens(from transactions: [TransactionInstance], contractsAndTokenTypes: [AlphaWallet.Address: TokenType]) -> [TokenUpdate] {
        let tokens: [TokenUpdate] = transactions.flatMap { transaction -> [TokenUpdate] in
            let tokenUpdates: [TokenUpdate] = transaction.localizedOperations.compactMap { operation in
                guard let contract = operation.contractAddress else { return nil }
                guard let name = operation.name else { return nil }
                guard let symbol = operation.symbol else { return nil }
                let tokenType: TokenType
                if let t = contractsAndTokenTypes[contract] {
                    tokenType = t
                } else {
                    switch operation.operationType {
                    case .nativeCurrencyTokenTransfer:
                        tokenType = .nativeCryptocurrency
                    case .erc20TokenTransfer:
                        tokenType = .erc20
                    case .erc20TokenApprove:
                        tokenType = .erc20
                    case .erc721TokenTransfer:
                        tokenType = .erc721
                    case .erc721TokenApproveAll:
                        tokenType = .erc721
                    case .erc875TokenTransfer:
                        tokenType = .erc875
                    case .erc1155TokenTransfer:
                        tokenType = .erc1155
                    case .unknown:
                        tokenType = .erc20
                    }
                }
                return TokenUpdate(
                        address: contract,
                        server: transaction.server,
                        name: name,
                        symbol: symbol,
                        decimals: operation.decimals,
                        tokenType: tokenType
                )
            }
            return tokenUpdates
        }
        return tokens
    }
}
