//
//  TokensFilter.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 30.03.2020.
//

import Foundation

class TokensFilter {
    private enum FilterKeys {
        case all
        case swap
        case erc20
        case erc721
        case erc875
        case erc1155
        case development(Development)
        case tokenscript
        case custom(string: String)

        init(keyword: String) {
            let lowercasedKeyword = keyword.trimmed.lowercased()

            if lowercasedKeyword.isEmpty {
                self = .all
            } else if lowercasedKeyword == "erc20" || lowercasedKeyword == "erc 20" {
                self = .erc20
            } else if lowercasedKeyword == "erc721" || lowercasedKeyword == "erc 721" {
                self = .erc721
            } else if lowercasedKeyword == "erc875" || lowercasedKeyword == "erc 875" {
                self = .erc875
            } else if lowercasedKeyword == "erc1155" || lowercasedKeyword == "erc 1155" {
                self = .erc1155
            } else if let value = FilterKeys.Development(rawValue: lowercasedKeyword) {
                self = .development(value)
            } else if lowercasedKeyword == "tokenscript" {
                self = .tokenscript
            } else if lowercasedKeyword == "swap" {
                self = .swap
            } else {
                self = .custom(string: lowercasedKeyword)
            }
        }

        enum Development: String {
            //Mainly for development/debugging
            case fiat
            case balance = "bal"
            case fiatAndBalance = "fiat bal"
            case balanceAndFiat = "bal fiat"
        }
    }

    private let assetDefinitionStore: AssetDefinitionStore
    private let tokenActionsService: TokenActionsService
    private let coinTickersFetcher: CoinTickersFetcherType
    private let tokenGroupIdentifier: TokenGroupIdentifierProtocol

    init(assetDefinitionStore: AssetDefinitionStore, tokenActionsService: TokenActionsService, coinTickersFetcher: CoinTickersFetcherType, tokenGroupIdentifier: TokenGroupIdentifierProtocol) {
        self.assetDefinitionStore = assetDefinitionStore
        self.tokenActionsService = tokenActionsService
        self.coinTickersFetcher = coinTickersFetcher
        self.tokenGroupIdentifier = tokenGroupIdentifier
    }

    func filterTokens(tokens: [Token], filter: WalletFilter) -> [Token] {
        let filteredTokens: [Token]

        func hasMatchingInNftBalance(token: Token, string: String) -> Bool {
            return token.balance.contains(where: {
                guard let balance = $0.nonFungibleBalance else { return false }
                return balance.name.trimmed.lowercased().contains(string) || balance.description.trimmed.lowercased().contains(string)
            })
        }

        func hasMatchingInTitle(token: Token, string: String) -> Bool {
            return token.name.trimmed.lowercased().contains(string) ||
                token.symbol.trimmed.lowercased().contains(string) ||
                token.contractAddress.eip55String.lowercased().contains(string) ||
                token.title(withAssetDefinitionStore: assetDefinitionStore).trimmed.lowercased().contains(string) ||
                token.titleInPluralForm(withAssetDefinitionStore: assetDefinitionStore).trimmed.lowercased().contains(string)
        }

        switch filter {
        case .all:
            filteredTokens = tokens
        case .filter(let filter):
            filteredTokens = tokens.filter { filter.filter(token: $0) }
        case .defi:
            filteredTokens = tokens.filter { tokenGroupIdentifier.identify(tokenObject: $0) == .defi }
        case .governance:
            filteredTokens = tokens.filter { tokenGroupIdentifier.identify(tokenObject: $0) == .governance }
        case .assets:
            filteredTokens = tokens.filter { tokenGroupIdentifier.identify(tokenObject: $0) == .assets }
        case .collectiblesOnly:
            filteredTokens = tokens.filter { ($0.type == .erc721 || $0.type == .erc1155) && !$0.balance.isEmpty }
        case .keyword(let keyword):
            switch FilterKeys(keyword: keyword) {
            case .all:
                filteredTokens = tokens
            case .swap:
                filteredTokens = tokens.filter { tokenActionsService.isSupport(token: TokenActionsServiceKey(token: $0)) }
            case .erc20:
                filteredTokens = tokens.filter { $0.type == .erc20 }
            case .erc721:
                filteredTokens = tokens.filter { $0.type == .erc721 }
            case .erc875:
                filteredTokens = tokens.filter { $0.type == .erc875 }
            case .erc1155:
                filteredTokens = tokens.filter { $0.type == .erc1155 }
            case .development(let value):
                switch value {
                case .fiat:
                    filteredTokens = tokens.filter { $0.hasTicker(coinTickersFetcher: coinTickersFetcher) }
                case .fiatAndBalance, .balanceAndFiat:
                    filteredTokens = tokens.filter { $0.hasNonZeroBalance && $0.hasTicker(coinTickersFetcher: coinTickersFetcher) }
                case .balance:
                    filteredTokens = tokens.filter { $0.hasNonZeroBalance }
                }
            case .tokenscript:
                filteredTokens = tokens.filter {
                    let xmlHandler = XMLHandler(token: $0, assetDefinitionStore: assetDefinitionStore)
                    return xmlHandler.hasNoBaseAssetDefinition && (xmlHandler.server?.matches(server: $0.server) ?? false)
                }
            case .custom(string: let string):
                filteredTokens = tokens.filter {
                    hasMatchingInTitle(token: $0, string: string) || hasMatchingInNftBalance(token: $0, string: string)
                }
            }
        }

        return filteredTokens
    }

    func filterTokens(tokens: [PopularToken], walletTokens: [Token], filter: WalletFilter) -> [PopularToken] {
        var filteredTokens: [PopularToken] = tokens.filter { token in
            !walletTokens.contains(where: { $0.contractAddress.sameContract(as: token.contractAddress) }) && !token.name.isEmpty
        }

        switch filter {
        case .all:
            break //no-op
        case .filter, .defi, .governance, .assets, .collectiblesOnly:
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

    func sortDisplayedTokens(tokens: [Token]) -> [Token] {

        func sortTokensByFiatValues(_ token1: Token, _ token2: Token) -> Bool {
            let value1 = coinTickersFetcher.ticker(for: token1.addressAndRPCServer).flatMap({ ticker in
                EthCurrencyHelper(ticker: ticker)
                    .fiatValue(value: token1.valueDecimal)
            }) ?? -1

            let value2 = coinTickersFetcher.ticker(for: token2.addressAndRPCServer).flatMap({ ticker in
                EthCurrencyHelper(ticker: ticker)
                    .fiatValue(value: token2.valueDecimal)
            }) ?? -1

            return value1 > value2
        }

        let nativeCryptoAddressInDatabase = Constants.nativeCryptoAddressInDatabase.eip55String

        let result = tokens.filter {
            $0.shouldDisplay
        }.sorted(by: {
            if let value1 = $0.sortIndex, let value2 = $1.sortIndex {
                return value1 < value2
            } else {
                let contract0 = $0.contractAddress.eip55String
                let contract1 = $1.contractAddress.eip55String

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

    func sortDisplayedTokens(tokens: [Token], sortTokensParam: SortTokensParam) -> [Token] {
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
                    return $0.value.description.lowercased() < $1.value.description.lowercased()
                case (.value, .descending):
                    return $0.value.description.lowercased() > $1.value.description.lowercased()
                }
            case .mostUsed:
                // NOTE: not implemented yet
                return false
            }
        })

        return result
    }
}

fileprivate extension Token {
    var hasNonZeroBalance: Bool {
        switch type {
        case .nativeCryptocurrency, .erc20:
            return !value.isZero
        case .erc875, .erc721, .erc721ForTickets, .erc1155:
            return !nonZeroBalance.isEmpty
        }
    }

    func hasTicker(coinTickersFetcher: CoinTickersFetcherType) -> Bool {
        let ticker = coinTickersFetcher.ticker(for: addressAndRPCServer)
        return ticker != nil
    }
}
