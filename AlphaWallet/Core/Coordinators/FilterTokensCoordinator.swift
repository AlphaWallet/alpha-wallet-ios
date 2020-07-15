//
//  FilterTokensCoordinator.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 30.03.2020.
//

import UIKit

class FilterTokensCoordinator {
    private let assetDefinitionStore: AssetDefinitionStore

    init(assetDefinitionStore: AssetDefinitionStore) {
        self.assetDefinitionStore = assetDefinitionStore
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
            filteredTokens = tokens.filter { $0.type == .erc721 && !$0.balance.isEmpty }
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
                    } else if lowercasedKeyword == "tokenscript" {
                        let xmlHandler = XMLHandler(contract: $0.contractAddress, assetDefinitionStore: assetDefinitionStore)
                        return xmlHandler.hasAssetDefinition && xmlHandler.server == $0.server
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

    func sortDisplayedTokens(tokens: [TokenObject]) -> [TokenObject] {
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
                    return false
                }
            }
        })

        return result
    }
}
