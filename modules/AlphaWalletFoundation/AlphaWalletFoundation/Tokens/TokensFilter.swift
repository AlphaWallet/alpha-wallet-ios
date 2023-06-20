//
//  TokensFilter.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 30.03.2020.
//

import Foundation
import BigInt

public protocol TokenScriptOverridesSupportable {
    var tokenScriptOverrides: TokenScriptOverrides? { get }
}

public protocol TokenBalanceSupportable {
    var balance: BalanceViewModel { get }
}

public protocol TokenFilterable: TokenScriptSupportable, TokenGroupIdentifiable, TokenActionsIdentifiable { }

public protocol TokenSortable {
    var name: String { get }
    var value: BigUInt { get }
    var contractAddress: AlphaWallet.Address { get }
    var server: RPCServer { get }
    var shouldDisplay: Bool { get }
    var decimals: Int { get }
}

public extension TokenSortable {
    var valueDecimal: Decimal {
        return Decimal(bigUInt: value, decimals: decimals) ?? .zero
    }
}

public class TokensFilter {
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

    private let tokenActionsService: TokenActionsService
    private let tokenGroupIdentifier: TokenGroupIdentifierProtocol

    public init(tokenActionsService: TokenActionsService, tokenGroupIdentifier: TokenGroupIdentifierProtocol) {
        self.tokenActionsService = tokenActionsService
        self.tokenGroupIdentifier = tokenGroupIdentifier
    }

    public func filterTokens<T>(tokens: [T], filter: WalletFilter) -> [T] where T: TokenFilterable & TokenScriptOverridesSupportable & TokenBalanceSupportable {
        let filteredTokens: [T]

        func hasMatchingInNftBalance(token: T, string: String) -> Bool {
            return token.balanceNft.contains(where: {
                guard let balance = $0.nonFungibleBalance else { return false }
                return balance.name.trimmed.lowercased().contains(string) || balance.description.trimmed.lowercased().contains(string)
            })
        }

        func hasMatchingInTitle(token: T, string: String) -> Bool {
            return token.name.trimmed.lowercased().contains(string) ||
                token.symbol.trimmed.lowercased().contains(string) ||
                token.contractAddress.eip55String.lowercased().contains(string) ||
                (token.tokenScriptOverrides?.titleInPluralForm.trimmed.lowercased().contains(string) ?? false) ||
                (token.tokenScriptOverrides?.title.trimmed.lowercased().contains(string) ?? false)
        }

        switch filter {
        case .all:
            filteredTokens = tokens
        case .attestations:
            filteredTokens = []
        case .filter(let filter):
            filteredTokens = tokens.filter { filter.filter(token: $0) }
        case .defi:
            filteredTokens = tokens.filter { tokenGroupIdentifier.identify(token: $0) == .defi }
        case .governance:
            filteredTokens = tokens.filter { tokenGroupIdentifier.identify(token: $0) == .governance }
        case .assets:
            filteredTokens = tokens.filter { tokenGroupIdentifier.identify(token: $0) == .assets }
        case .collectiblesOnly:
            filteredTokens = tokens.filter { ($0.type == .erc721 || $0.type == .erc1155) && !$0.balanceNft.isEmpty }
        case .keyword(let keyword):
            switch FilterKeys(keyword: keyword) {
            case .all:
                filteredTokens = tokens
            case .swap:
                filteredTokens = tokens.filter { tokenActionsService.isSupport(token: $0) }
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
                    filteredTokens = tokens.filter { $0.balance.ticker != nil }
                case .fiatAndBalance, .balanceAndFiat:
                    filteredTokens = tokens.filter { $0.hasNonZeroBalance && $0.balance.ticker != nil }
                case .balance:
                    filteredTokens = tokens.filter { $0.hasNonZeroBalance }
                }
            case .tokenscript:
                filteredTokens = tokens.filter {
                    guard let overrides = $0.tokenScriptOverrides else { return false }
                    return overrides.hasNoBaseAssetDefinition && (overrides.server?.matches(server: $0.server) ?? false)
                }
            case .custom(string: let string):
                filteredTokens = tokens.filter {
                    hasMatchingInTitle(token: $0, string: string) || hasMatchingInNftBalance(token: $0, string: string)
                }
            }
        }

        return filteredTokens
    }

    public func filterTokens(tokens: [PopularToken], walletTokens: [TokenViewModel], filter: WalletFilter) -> [PopularToken] {
        var filteredTokens: [PopularToken] = tokens.filter { token in
            !walletTokens.contains(where: { $0.contractAddress == token.contractAddress }) && !token.name.isEmpty
        }

        switch filter {
        case .all:
            break //no-op
        case .filter, .defi, .governance, .assets, .collectiblesOnly, .attestations:
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

    public func sortDisplayedTokens<T>(tokens: [T]) -> [T] where T: TokenSortable & TokenBalanceSupportable {

        func sortTokensByFiatValues(_ token1: T, _ token2: T) -> Bool {
            let value1 = token1.balance.ticker.flatMap { ticker in
                TickerHelper(ticker: ticker).fiatValue(value: token1.valueDecimal)
            } ?? -1

            let value2 = token1.balance.ticker.flatMap { ticker in
                TickerHelper(ticker: ticker).fiatValue(value: token2.valueDecimal)
            } ?? -1

            return value1 > value2
        }

        let nativeCryptoAddressInDatabase = Constants.nativeCryptoAddressInDatabase.eip55String

        let result = tokens.filter {
            $0.shouldDisplay
        }.sorted(by: {
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
        })

        return result
    }

    public func sortDisplayedTokens<T>(tokens: [T], sortTokensParam: SortTokensParam) -> [T] where T: TokenSortable {
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

fileprivate extension TokenFilterable {

    var nonZeroBalance: [TokenBalanceValue] {
        return Array(balanceNft.filter { isNonZeroBalance($0.balance, tokenType: self.type) })
    }

    var hasNonZeroBalance: Bool {
        switch type {
        case .nativeCryptocurrency, .erc20:
            return valueBI.signum() != .zero
        case .erc875, .erc721, .erc721ForTickets, .erc1155:
            return !nonZeroBalance.isEmpty
        }
    }
}
