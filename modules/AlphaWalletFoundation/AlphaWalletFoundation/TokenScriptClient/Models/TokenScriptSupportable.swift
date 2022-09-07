//
//  TokenScriptSupportable.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 18.05.2022.
//

import Foundation
import BigInt 

public protocol TokenScriptSupportable {
    var name: String { get }
    var symbol: String { get }
    var contractAddress: AlphaWallet.Address { get }
    var type: TokenType { get }
    var decimals: Int { get }
    var server: RPCServer { get }
    var valueBI: BigInt { get }
    var balanceNft: [TokenBalanceValue] { get }
}

public extension TokenScriptSupportable {

    func title(withAssetDefinitionStore assetDefinitionStore: AssetDefinitionStore) -> String {
        let localizedNameFromAssetDefinition = XMLHandler(token: self, assetDefinitionStore: assetDefinitionStore).getLabel(fallback: name)
        return title(withAssetDefinitionStore: assetDefinitionStore, localizedNameFromAssetDefinition: localizedNameFromAssetDefinition, symbol: symbol)
    }

    func titleInPluralForm(withAssetDefinitionStore assetDefinitionStore: AssetDefinitionStore, eventsDataStore: NonActivityEventsDataStore, forWallet wallet: Wallet) -> String? {
        if let tokenHolders = getTokenHolders(assetDefinitionStore: assetDefinitionStore, eventsDataStore: eventsDataStore, forWallet: wallet).first {
            guard let name = tokenHolders.tokens.first?.values.collectionValue?.name, name.nonEmpty else { return nil }
            return name
        } else {
            return nil
        }
    }

    func titleInPluralForm(withAssetDefinitionStore assetDefinitionStore: AssetDefinitionStore) -> String {
        let localizedNameFromAssetDefinition = XMLHandler(token: self, assetDefinitionStore: assetDefinitionStore).getNameInPluralForm(fallback: name)
        return title(withAssetDefinitionStore: assetDefinitionStore, localizedNameFromAssetDefinition: localizedNameFromAssetDefinition, symbol: symbol)
    }

    private func title(withAssetDefinitionStore assetDefinitionStore: AssetDefinitionStore, localizedNameFromAssetDefinition: String, symbol: String) -> String {
        let compositeName = compositeTokenName(forContract: contractAddress, fromContractName: name, localizedNameFromAssetDefinition: localizedNameFromAssetDefinition)
        if compositeName.isEmpty {
            return symbol
        } else {
            let daiSymbol = "DAI\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}"
            //We could have just trimmed away all trailing \0, but this is faster and safer since only DAI seems to have this problem
            if daiSymbol == symbol {
                return "\(compositeName) (DAI)"
            } else {
                if symbol.isEmpty {
                    return compositeName
                } else {
                    return "\(compositeName) (\(symbol))"
                }
            }
        }
    }

//    When picking *1 (long name):
//
//    Use TokenScript name if available.
//    Use Token name if longer than Token symbol.
//    Use Token symbol.
//    When picking *2 (short name):
//
//    Use shortest of name and symbol, but abbreviate to 5 characters or less and capitalise.

    func shortTitleInPluralForm(withAssetDefinitionStore assetDefinitionStore: AssetDefinitionStore, eventsDataStore: NonActivityEventsDataStore, forWallet wallet: Wallet) -> String {
        func compositeTokenNameAndSymbol(symbol: String, name: String) -> String {
            let daiSymbol = "DAI\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}"
            //We could have just trimmed away all trailing \0, but this is faster and safer since only DAI seems to have this problem
            if daiSymbol == symbol {
                return "\(valueBI) (DAI)".uppercased()
            } else {
                return "\(valueBI) (\(symbol))".uppercased()
            }
        }
        let xmlHandler = XMLHandler(token: self, assetDefinitionStore: assetDefinitionStore)

        func _compositeTokenName(fallback: String = "") -> String {
            let localizedNameFromAssetDefinition = xmlHandler.getNameInPluralForm(fallback: fallback)
            return compositeTokenName(forContract: contractAddress, fromContractName: name, localizedNameFromAssetDefinition: localizedNameFromAssetDefinition)
        }

        let localizedNameFromAssetDefinition = _compositeTokenName()
        let symbol = self.symbol(withAssetDefinitionStore: assetDefinitionStore, localizedNameFromAssetDefinition: localizedNameFromAssetDefinition)

        if localizedNameFromAssetDefinition.isEmpty {
            if let name = titleInPluralForm(withAssetDefinitionStore: assetDefinitionStore, eventsDataStore: eventsDataStore, forWallet: wallet) {
                return name
            } else {
                let tokenName = _compositeTokenName(fallback: name)

                if tokenName.isEmpty {
                    return symbol
                } else if tokenName.count > symbol.count {
                    if symbol.isEmpty {
                        return tokenName
                    } else {
                        return symbol
                    }
                } else {
                    //some-imas asd -> someimas asd
                    let acronym = tokenName.components(separatedBy: CharacterSet.alphanumerics.inverted).joined(separator: "").getAcronyms()
                    if acronym.isEmpty || acronym.count == 1 {
                        return symbol.isEmpty ? tokenName : symbol
                    } else {
                        return compositeTokenNameAndSymbol(symbol: symbol, name: acronym.joined(separator: ""))
                    }
                }
            }
        } else {
            return localizedNameFromAssetDefinition
        }
    }

    func shortTitleInPluralForm(withAssetDefinitionStore assetDefinitionStore: AssetDefinitionStore) -> String {
        func compositeTokenNameAndSymbol(symbol: String, name: String) -> String {
            let daiSymbol = "DAI\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}"
            //We could have just trimmed away all trailing \0, but this is faster and safer since only DAI seems to have this problem
            if daiSymbol == symbol {
                return "\(valueBI) (DAI)".uppercased()
            } else {
                return "\(valueBI) (\(symbol))".uppercased()
            }
        }
        let xmlHandler = XMLHandler(token: self, assetDefinitionStore: assetDefinitionStore)

        func _compositeTokenName(fallback: String = "") -> String {
            let localizedNameFromAssetDefinition = xmlHandler.getNameInPluralForm(fallback: fallback)
            return compositeTokenName(forContract: contractAddress, fromContractName: name, localizedNameFromAssetDefinition: localizedNameFromAssetDefinition)
        }

        let localizedNameFromAssetDefinition = _compositeTokenName()
        let symbol = self.symbol(withAssetDefinitionStore: assetDefinitionStore, localizedNameFromAssetDefinition: localizedNameFromAssetDefinition)

        if localizedNameFromAssetDefinition.isEmpty {
            let tokenName = _compositeTokenName(fallback: name)

            if tokenName.isEmpty {
                return symbol
            } else if tokenName.count > symbol.count {
                if symbol.isEmpty {
                    return tokenName
                } else {
                    return symbol
                }
            } else {
                //some-imas asd -> someimas asd
                let acronym = tokenName.components(separatedBy: CharacterSet.alphanumerics.inverted).joined(separator: "").getAcronyms()
                if acronym.isEmpty || acronym.count == 1 {
                    return symbol.isEmpty ? tokenName : symbol
                } else {
                    return compositeTokenNameAndSymbol(symbol: symbol, name: acronym.joined(separator: ""))
                }
            }
        } else {
            return localizedNameFromAssetDefinition
        }
    }

    func symbolInPluralForm(withAssetDefinitionStore assetDefinitionStore: AssetDefinitionStore) -> String {
        let localizedNameFromAssetDefinition = XMLHandler(token: self, assetDefinitionStore: assetDefinitionStore).getNameInPluralForm(fallback: name)
        return symbol(withAssetDefinitionStore: assetDefinitionStore, localizedNameFromAssetDefinition: localizedNameFromAssetDefinition)
    }

    private func symbol(withAssetDefinitionStore assetDefinitionStore: AssetDefinitionStore, localizedNameFromAssetDefinition: String) -> String {
        let compositeName = compositeTokenName(forContract: contractAddress, fromContractName: name, localizedNameFromAssetDefinition: localizedNameFromAssetDefinition)
        if compositeName.isEmpty {
            return symbol
        } else {
            let daiSymbol = "DAI\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}\u{0}"
            //We could have just trimmed away all trailing \0, but this is faster and safer since only DAI seems to have this problem
            if daiSymbol == symbol {
                return "DAI"
            } else {
                return symbol
            }
        }
    }
}

extension String {
    public func getAcronyms(separatedBy: String = " ") -> [String] {
        return components(separatedBy: separatedBy).compactMap({ $0.first }).map({ String($0) })
    }
}

public func isNonZeroBalance(_ balance: String, tokenType: TokenType) -> Bool {
    return !isZeroBalance(balance, tokenType: tokenType)
}

public func isZeroBalance(_ balance: String, tokenType: TokenType) -> Bool {
    //We don't care about fungibles here, but want to make sure that *only* ERC875 balances consider string of "0" as null token, because we mark tokens that are burnt as 0, whereas ERC721 can have token ID = 0, eg. https://bscscan.com/tx/0xf6f3ddbb6719d8e47a47cf8ec66853682c02f03626cc4c4f5ece9338a8f20aee
    switch tokenType {
    case .nativeCryptocurrency, .erc20, .erc875:
        if balance == Constants.nullTokenId || balance == "0" {
            return true
        }
        return false
    case .erc721, .erc721ForTickets:
        return balance.isEmpty
    case .erc1155:
        //TODO this makes an assumption about the serialization format for `BigInt`, but avoids the performance hit for deserializing the JSON string to a type. Improve this architecture-wise
        return balance.isEmpty || balance.contains("value\":[\"+\",0],\"")
    }
}

public func compositeTokenName(forContract contract: AlphaWallet.Address, fromContractName contractName: String, localizedNameFromAssetDefinition: String) -> String {
    let compositeName: String
    //TODO improve and remove the check for "N/A". Maybe a constant
    //Special case for FIFA tickets, otherwise, we just show the name from the XML
    if contract.isFifaTicketContract {
        if contractName.isEmpty {
            compositeName = localizedNameFromAssetDefinition
        } else {
            compositeName = "\(contractName) \(localizedNameFromAssetDefinition)"
        }
    } else {
        compositeName = localizedNameFromAssetDefinition
    }
    return compositeName
}
