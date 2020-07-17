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
        case .finances:
            filteredTokens = tokens.filter { FinancesToken(rawValue: $0.contract) != nil }
        case .all:
            filteredTokens = tokens
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

enum FinancesToken: String, CaseIterable {
    case aDAI = "0xfC1E690f61EFd961294b3e1Ce3313fBD8aa4f85d"
    case cREP = "0x158079Ee67Fce2f58472A96584A73C7Ab9AC95c1"
    case cDAI = "0x5d3a536E4D6DbD6114cc1Ead35777bAB948E3643"
    case cETH = "0x4Ddc2D193948926D02f9B1fE9e1daa0718270ED5"
    case cWBTC = "0xC11b1268C1A384e55C48c2391d8d480264A3A7F4"
    case cUSDC = "0x39AA39c021dfbaE8faC545936693aC917d5E7563"
    case cBAT = "0x6C8c6b02E7b2BE14d4fA6022Dfd6d75921D90E4E"
    case mUSDC = "0x3564ad35b9E95340E5Ace2D6251dbfC76098669B"
    case mDAI = "0x06301057D77D54B6e14c7FafFB11Ffc7Cab4eaa7"
    case USDC = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48"
    case cSAI = "0xF5DCe57282A584D2746FaF1593d3121Fcac444dC"
    case COMP = "0xc00e94Cb662C3520282E6f5717214004A7f26888"
    case WETH = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2"
    case DAI = "0x6B175474E89094C44Da98b954EedeAC495271d0F"
    case NEST = "0x04abEdA201850aC0124161F037Efd70c74ddC74C"
    case daiPool = "0x2a1530C4C41db0B0b2bB646CB5Eb1A67b7158667"
    case saiPool = "0x09cabEC1eAd1c0Ba254B09efb3EE13841712bE14"
    case sethPool = "0x4740C758859D4651061CC9CDEFdBa92BDc3a845d"
    case usdcPool = "0x97deC872013f6B5fB443861090ad931542878126"
    case wbtcPool = "0x4d2f5cFbA55AE412221182D8475bC85799A5644b"
    case wethPool = "0xA2881A90Bf33F03E7a3f803765Cd2ED5c8928dFb"
    case USDCx = "0xeb269732ab75A6fD61Ea60b06fE994cD32a83549"
    case mETH = "0xdF9307DFf0a1B57660F60f9457D32027a55ca0B2"
    case cZRX = "0xB3319f5D18Bc0D84dD1b4825Dcde5d5f7266d407"
}
