//
//  FilterTokensCoordinator.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 30.03.2020.
//

import UIKit

class FilterTokensCoordinator {
    private enum FilterKeys: String {
        case swap

        enum Development: String {
            //Mainly for development/debugging
            case fiat
            case balance = "bal"
            case fiatAndBalance = "fiat bal"
            case balanceAndFiat = "bal fiat"
        }
    }

    private let assetDefinitionStore: AssetDefinitionStore
    private let tokenActionsService: TokenActionsServiceType
    private let coinTickersFetcher: CoinTickersFetcherType

    init(assetDefinitionStore: AssetDefinitionStore, tokenActionsService: TokenActionsServiceType, coinTickersFetcher: CoinTickersFetcherType) {
        self.assetDefinitionStore = assetDefinitionStore
        self.tokenActionsService = tokenActionsService
        self.coinTickersFetcher = coinTickersFetcher
    }

    func filterTokens(tokens: [TokenObject], filter: WalletFilter) -> [TokenObject] {
        let filteredTokens: [TokenObject]
        switch filter {
        case .all:
            filteredTokens = tokens
        case .type(let types):
            filteredTokens = tokens.filter { types.contains($0.type) }
        case .currencyOnly:
             filteredTokens = tokens.filter { $0.type == .nativeCryptocurrency || $0.type == .erc20 }
        case .assetsOnly:
            filteredTokens = tokens.filter { $0.type != .nativeCryptocurrency && $0.type != .erc20 }
        case .collectiblesOnly:
            filteredTokens = tokens.filter { ($0.type == .erc721 || $0.type == .erc1155) && !$0.balance.isEmpty }
        case .keyword(let keyword):
            let lowercasedKeyword = keyword.trimmed.lowercased()
            if lowercasedKeyword.isEmpty {
                filteredTokens = tokens
            } else {
                filteredTokens = tokens.filter {
                    if lowercasedKeyword == "erc20" || lowercasedKeyword == "erc 20" {
                        return $0.type == .erc20
                    } else if lowercasedKeyword == "erc721" || lowercasedKeyword == "erc 721" {
                        return $0.type == .erc721
                    } else if lowercasedKeyword == "erc875" || lowercasedKeyword == "erc 875" {
                        return $0.type == .erc875
                    } else if lowercasedKeyword == "erc1155" || lowercasedKeyword == "erc 1155" {
                        return $0.type == .erc1155
                    } else if lowercasedKeyword == FilterKeys.Development.balance.rawValue {
                        return $0.hasNonZeroBalance
                    } else if lowercasedKeyword == FilterKeys.Development.fiat.rawValue {
                        return $0.hasTicker(coinTickersFetcher: coinTickersFetcher)
                    } else if lowercasedKeyword == FilterKeys.Development.fiatAndBalance.rawValue || lowercasedKeyword == FilterKeys.Development.balanceAndFiat.rawValue {
                        return $0.hasNonZeroBalance && $0.hasTicker(coinTickersFetcher: coinTickersFetcher)
                    } else if lowercasedKeyword == "tokenscript" {
                        let xmlHandler = XMLHandler(token: $0, assetDefinitionStore: assetDefinitionStore)
                        return xmlHandler.hasNoBaseAssetDefinition && (xmlHandler.server?.matches(server: $0.server) ?? false)
                    } else if lowercasedKeyword == FilterKeys.swap.rawValue {
                        let key = TokenActionsServiceKey(tokenObject: $0)
                        return tokenActionsService.isSupport(token: key)
                    } else {
                        return $0.name.trimmed.lowercased().contains(lowercasedKeyword) ||
                                $0.symbol.trimmed.lowercased().contains(lowercasedKeyword) ||
                                $0.contract.lowercased().contains(lowercasedKeyword) ||
                                $0.title(withAssetDefinitionStore: assetDefinitionStore).trimmed.lowercased().contains(lowercasedKeyword) ||
                                $0.titleInPluralForm(withAssetDefinitionStore: assetDefinitionStore).trimmed.lowercased().contains(lowercasedKeyword)
                    }
                }
            }
        }

        return filteredTokens
    }

    func filterTokens(tokens: [PopularToken], walletTokens: [TokenObject], filter: WalletFilter) -> [PopularToken] {
        var filteredTokens: [PopularToken] = tokens.filter { token in
            !walletTokens.contains(where: { $0.contractAddress.sameContract(as: token.contractAddress) }) && !token.name.isEmpty
        }

        switch filter {
        case .all:
            break //no-op
        case .type, .currencyOnly, .assetsOnly, .collectiblesOnly:
            filteredTokens = []
        case .keyword(let keyword):
            let lowercasedKeyword = keyword.trimmed.lowercased()
            if lowercasedKeyword.isEmpty {
                break //no-op
            } else {
                filteredTokens = filteredTokens.filter {
                    return $0.name.trimmed.lowercased().contains(lowercasedKeyword)
                }
            }
        }

        return filteredTokens
    }

    func sortDisplayedTokens(tokens: [TokenObject]) -> [TokenObject] {

        func sortTokensByFiatValues(_ token1: TokenObject, _ token2: TokenObject) -> Bool {
            let value1 = coinTickersFetcher.ticker(for: token1.addressAndRPCServer).flatMap({ ticker in
                EthCurrencyHelper(ticker: ticker)
                    .fiatValue(value: token1.optionalDecimalValue)
            }) ?? -1

            let value2 = coinTickersFetcher.ticker(for: token2.addressAndRPCServer).flatMap({ ticker in
                EthCurrencyHelper(ticker: ticker)
                    .fiatValue(value: token2.optionalDecimalValue)
            }) ?? -1

            return value1 > value2
        }

        let nativeCryptoAddressInDatabase = Constants.nativeCryptoAddressInDatabase.eip55String

        let result = tokens.filter {
            $0.shouldDisplay
        }.sorted(by: {
            if let value1 = $0.sortIndex.value, let value2 = $1.sortIndex.value {
                return value1 < value2
            } else {
                let contract0 = $0.contract
                let contract1 = $1.contract

                if contract0 == nativeCryptoAddressInDatabase && contract1 == nativeCryptoAddressInDatabase {
                    return $0.server.displayOrderPriority < $1.server.displayOrderPriority
                } else if contract0 == nativeCryptoAddressInDatabase {
                    return true
                } else if contract1 == nativeCryptoAddressInDatabase {
                    return false
                } else if $0.server != $1.server {
                    return $0.server.displayOrderPriority < $1.server.displayOrderPriority
                } else {
                    return sortTokensByFiatValues($0, $1)
                }
            }
        })

        return result
    }

    func sortDisplayedTokens(tokens: [TokenObject], sortTokensParam: SortTokensParam) -> [TokenObject] {
        let result = tokens.filter {
            $0.shouldDisplay
        }.sorted(by: {
            switch sortTokensParam {
            case .byField(let field, let direction):
                switch (field, direction) {
                case (.name, .ascending):
                    return $0.name.lowercased() < $1.name.lowercased()
                case (.name, .descending):
                    return $0.name.lowercased() > $1.name.lowercased()
                case (.value, .ascending):
                    return $0.value.lowercased() < $1.value.lowercased()
                case (.value, .descending):
                    return $0.value.lowercased() > $1.value.lowercased()
                }
            case .mostUsed:
                // NOTE: not implemented yet
                return false
            }
        })

        return result
    }
}

fileprivate extension TokenObject {
    var hasNonZeroBalance: Bool {
        switch type {
        case .nativeCryptocurrency, .erc20:
            return !valueBigInt.isZero
        case .erc875, .erc721, .erc721ForTickets, .erc1155:
            return !nonZeroBalance.isEmpty
        }
    }

    func hasTicker(coinTickersFetcher: CoinTickersFetcherType) -> Bool {
        let ticker = coinTickersFetcher.ticker(for: addressAndRPCServer)
        return ticker != nil
    }
}
