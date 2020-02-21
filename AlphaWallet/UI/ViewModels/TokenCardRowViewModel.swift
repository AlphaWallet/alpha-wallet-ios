// Copyright © 2018 Stormbird PTE. LTD.

import UIKit

//TODO separate file
enum TokenView {
    case view
    case viewIconified
}

struct TokenCardRowViewModel: TokenCardRowViewModelProtocol {
    let tokenHolder: TokenHolder
    let tokenView: TokenView
    let assetDefinitionStore: AssetDefinitionStore

    var tokenCount: String {
        return "x\(tokenHolder.tokens.count)"
    }

    var city: String {
        let value = tokenHolder.values["locality"]?.stringValue ?? "N/A"
        return ", \(value)"
    }

    var category: String {
        if tokenHolder.hasAssetDefinition {
            return tokenHolder.values["category"]?.stringValue ?? "N/A"
        } else {
            //For ERC75 tokens, display the contract's name as the "title". https://github.com/alpha-wallet/alpha-wallet-ios/issues/664
            return tokenHolder.name
        }
    }

    var isMeetupContract: Bool {
        return tokenHolder.isSpawnableMeetupContract
    }

    var teams: String {
        if isMeetupContract && tokenHolder.values["expired"] != nil {
            return ""
        } else {
            let countryA = tokenHolder.values["countryA"]?.stringValue ?? ""
            let countryB = tokenHolder.values["countryB"]?.stringValue ?? ""
            return R.string.localizable.aWalletTokenMatchVs(countryA, countryB)
        }
    }

    var match: String {
        if tokenHolder.values["section"] != nil {
            if let section = tokenHolder.values["section"]?.stringValue {
                return "S\(section)"
            } else {
                return "S0"
            }
        } else {
            let value = tokenHolder.values["match"]?.intValue ?? 0
            return "M\(value)"
        }
    }

    var venue: String {
        return tokenHolder.values["venue"]?.stringValue ?? "N/A"
    }

    var date: String {
        let value = tokenHolder.values["time"]?.generalisedTimeValue ?? GeneralisedTime()
        return value.formatAsShortDateString()
    }

    var numero: String {
        if let num = tokenHolder.values["numero"]?.intValue {
            return String(num)
        } else {
            return "N/A"
        }
    }

    func subscribeBuilding(withBlock block: @escaping (String) -> Void) {
        if case .some(.subscribable(let subscribable)) = tokenHolder.values["building"]?.value {
            subscribable.subscribe { value in
                if let value = value?.stringValue {
                    block(value)
                }
            }
        }
    }

    func subscribeStreetLocalityStateCountry(withBlock block: @escaping (String) -> Void) {
        func updateStreetLocalityStateCountry(street: String?, locality: String?, state: String?, country: String?) {
            let values = [street, locality, state, country].compactMap { $0 }
            let string = values.joined(separator: ", ")
            block(string)
        }
        if case .some(.subscribable(let subscribable)) = tokenHolder.values["street"]?.value {
            subscribable.subscribe { value in
                if let value = value?.stringValue {
                    updateStreetLocalityStateCountry(
                            street: value,
                            locality: self.tokenHolder.values["locality"]?.subscribableStringValue,
                            state: self.tokenHolder.values["state"]?.subscribableStringValue,
                            country: self.tokenHolder.values["country"]?.stringValue
                    )
                }
            }
        }
        if case .some(.subscribable(let subscribable)) = tokenHolder.values["state"]?.value {
            subscribable.subscribe { value in
                if let value = value?.stringValue {
                    updateStreetLocalityStateCountry(
                            street: self.tokenHolder.values["street"]?.subscribableStringValue,
                            locality: self.tokenHolder.values["locality"]?.subscribableStringValue,
                            state: value,
                            country: self.tokenHolder.values["country"]?.stringValue
                    )
                }
            }
        }

        if case .some(.subscribable(let subscribable)) = tokenHolder.values["locality"]?.value {
            subscribable.subscribe { value in
                if let value = value?.stringValue {
                    updateStreetLocalityStateCountry(
                            street: self.tokenHolder.values["street"]?.subscribableStringValue,
                            locality: value,
                            state: self.tokenHolder.values["state"]?.subscribableStringValue,
                            country: self.tokenHolder.values["country"]?.stringValue
                    )
                }
            }
        }

        if let country = tokenHolder.values["country"]?.stringValue {
            updateStreetLocalityStateCountry(
                    street: self.tokenHolder.values["street"]?.subscribableStringValue,
                    locality: self.tokenHolder.values["locality"]?.subscribableStringValue,
                    state: self.tokenHolder.values["state"]?.subscribableStringValue,
                    country: country
            )
        }
    }

    var time: String {
        let value = tokenHolder.values["time"]?.generalisedTimeValue ?? GeneralisedTime()
        return value.format("h:mm a")
    }

    var onlyShowTitle: Bool {
        return !tokenHolder.hasAssetDefinition
    }

    var tokenScriptHtml: (html: String, hash: Int) {
        let xmlHandler = XMLHandler(contract: tokenHolder.contractAddress, assetDefinitionStore: assetDefinitionStore)
        let html: String
        switch tokenView {
        case .view:
            html = xmlHandler.tokenViewHtml
        case .viewIconified:
            html = xmlHandler.tokenViewIconifiedHtml
        }
        let hash = html.hashForCachingHeight
        return (html: wrapWithHtmlViewport(html, forTokenHolder: tokenHolder), hash: hash)
    }

    var hasTokenScriptHtml: Bool {
        //TODO improve performance? Because it is generated again when used
        return !tokenScriptHtml.html.isEmpty
    }
}
