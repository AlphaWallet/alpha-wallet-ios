//
//  ErcTokenDetector.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 01.04.2022.
//

import Foundation
import Combine

public final class ErcTokenDetector {
    private let tokensService: TokensService
    private let ercProvider: TokenProviderType
    private let server: RPCServer
    private let assetDefinitionStore: AssetDefinitionStore

    public init(tokensService: TokensService,
                server: RPCServer,
                ercProvider: TokenProviderType,
                assetDefinitionStore: AssetDefinitionStore) {

        self.assetDefinitionStore = assetDefinitionStore
        self.tokensService = tokensService
        self.ercProvider = ercProvider
        self.server = server
    }

    func detect(from transactions: [Transaction]) {
        guard !transactions.isEmpty else { return }

        filterTransactionsToPullContracts(from: transactions)
            .sinkAsync(receiveCompletion: { _ in

            }, receiveValue: { [weak self] transactionsToPullContractsFrom, contractsAndTokenTypes in
                guard !transactionsToPullContractsFrom.isEmpty else { return }
                self?.addTokensFromUpdates(transactionsToPullContractsFrom: transactionsToPullContractsFrom, contractsAndTokenTypes: contractsAndTokenTypes)
            })
    }

    private func addTokensFromUpdates(transactionsToPullContractsFrom transactions: [Transaction], contractsAndTokenTypes: [AlphaWallet.Address: TokenType]) {
        let ercTokens = ErcTokenDetector.functional.buildErcTokens(from: transactions, contractsAndTokenTypes: contractsAndTokenTypes)
        let contractsAndServers = Array(Set(ercTokens.map { AddressAndRPCServer(address: $0.contract, server: $0.server) }))

        let actions = ercTokens.map { AddOrUpdateTokenAction.add(ercToken: $0, shouldUpdateBalance: true) }
        tokensService.addOrUpdate(with: actions)

        for each in contractsAndServers {
            assetDefinitionStore.fetchXML(forContract: each.address, server: each.server)
        }
    }

    private var contractsToAvoid: [AlphaWallet.Address] {
        let deletedContracts = tokensService.deletedContracts(for: server)
        let hiddenContracts = tokensService.hiddenContracts(for: server)
        let delegateContracts = tokensService.delegateContracts(for: server)
        let alreadyAddedContracts = tokensService.alreadyAddedContracts(for: server)

        return alreadyAddedContracts + deletedContracts + hiddenContracts + delegateContracts
    }

    private func filterTransactionsToPullContracts(from transactions: [Transaction]) -> AnyPublisher<(transactions: [Transaction], contractTypes: [AlphaWallet.Address: TokenType]), Never> {
        let filteredTransactions = ErcTokenDetector.functional.filter(transactions: transactions, contractsToAvoid: contractsToAvoid)

        //The fetch ERC20 transactions endpoint from Etherscan returns only ERC20 token transactions but the Blockscout version also includes ERC721 transactions too (so it's likely other types that it can detect will be returned too); thus we check the token type rather than assume that they are all ERC20
        let contracts = Array(Set(filteredTransactions.compactMap { $0.localizedOperations.first?.contractAddress }))
        let tokenTypePromises = contracts.map { contract in
            ercProvider.getTokenType(for: contract)
                .map { Optional($0) }
                .replaceError(with: nil)
                .map { (contract: contract, tokenType: $0) }
                .eraseToAnyPublisher()
        }

        return Publishers.MergeMany(tokenTypePromises).collect()
            .map { tokenTypes in
                var contractsToTokenTypes: [AlphaWallet.Address: TokenType] = [:]
                for each in tokenTypes {
                    guard let tokenType = each.tokenType else { continue }
                    contractsToTokenTypes[each.contract] = tokenType
                }
                return (transactions: filteredTransactions, contractTypes: contractsToTokenTypes)
            }.eraseToAnyPublisher()
    }
}

extension ErcTokenDetector {
    enum functional {}
}

extension ErcTokenDetector.functional {

    static func filter(transactions: [Transaction], contractsToAvoid: [AlphaWallet.Address]) -> [Transaction] {
        return transactions.filter {
            if let toAddressToCheck = AlphaWallet.Address(string: $0.to), contractsToAvoid.contains(toAddressToCheck) {
                return false
            }
            if let contractAddressToCheck = $0.operation?.contractAddress, contractsToAvoid.contains(contractAddressToCheck) {
                return false
            }
            return true
        }
    }

    static func buildErcTokens(from transactions: [Transaction], contractsAndTokenTypes: [AlphaWallet.Address: TokenType]) -> [ErcToken] {
        let tokens: [ErcToken] = transactions.flatMap { transaction -> [ErcToken] in
            let tokenUpdates: [ErcToken] = transaction.localizedOperations.compactMap { operation in
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

                return .init(contract: contract, server: transaction.server, name: name, symbol: symbol, decimals: operation.decimals, type: tokenType, value: .zero, balance: .balance([]))
            }
            return tokenUpdates
        }
        return tokens
    }
}
