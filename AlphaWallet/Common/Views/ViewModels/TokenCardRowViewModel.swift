// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import AlphaWalletFoundation

struct TokenCardRowViewModel: TokenCardRowViewModelProtocol {
    let tokenHolder: TokenHolder
    let tokenView: TokenView
    let assetDefinitionStore: AssetDefinitionStore

    var tokenCount: String {
        return "x\(tokenHolder.tokens.count)"
    }

    var city: String {
        let value = tokenHolder.values.localityStringValue ?? "N/A"
        return ", \(value)"
    }

    var category: String {
        if tokenHolder.hasAssetDefinition {
            return tokenHolder.values.categoryStringValue ?? "N/A"
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
            let countryA = tokenHolder.values.countryAStringValue ?? ""
            let countryB = tokenHolder.values.countryBStringValue ?? ""
            return R.string.localizable.aWalletTokenMatchVs(countryA, countryB)
        }
    }

    var match: String {
        if tokenHolder.values["section"] != nil {
            if let section = tokenHolder.values.sectionStringValue {
                return "S\(section)"
            } else {
                return "S0"
            }
        } else {
            let value = tokenHolder.values.matchIntValue ?? 0
            return "M\(value)"
        }
    }

    var venue: String {
        return tokenHolder.values.venueStringValue ?? "N/A"
    }

    var date: String {
        let value = tokenHolder.values.timeGeneralisedTimeValue ?? GeneralisedTime()
        return value.formatAsShortDateString()
    }

    var numero: String {
        if let num = tokenHolder.values.numeroIntValue {
            return String(num)
        } else {
            return "N/A"
        }
    }

    func subscribeBuilding(withBlock block: @escaping (String) -> Void) {
        if let subscribable = tokenHolder.values.buildingSubscribableValue {
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
        if let subscribable = tokenHolder.values.streetSubscribableValue {
            subscribable.subscribe { value in
                if let value = value?.stringValue {
                    updateStreetLocalityStateCountry(
                            street: value,
                            locality: tokenHolder.values.localitySubscribableStringValue,
                            state: tokenHolder.values.stateSubscribableStringValue,
                            country: tokenHolder.values.countryStringValue
                    )
                }
            }
        }
        if let subscribable = tokenHolder.values.stateSubscribableValue {
            subscribable.subscribe { value in
                if let value = value?.stringValue {
                    updateStreetLocalityStateCountry(
                            street: tokenHolder.values.streetSubscribableStringValue,
                            locality: tokenHolder.values.localitySubscribableStringValue,
                            state: value,
                            country: tokenHolder.values.countryStringValue
                    )
                }
            }
        }

        if let subscribable = tokenHolder.values.localitySubscribableValue {
            subscribable.subscribe { value in
                if let value = value?.stringValue {
                    updateStreetLocalityStateCountry(
                            street: tokenHolder.values.streetSubscribableStringValue,
                            locality: value,
                            state: tokenHolder.values.stateSubscribableStringValue,
                            country: tokenHolder.values.countryStringValue
                    )
                }
            }
        }

        if let country = tokenHolder.values.countryStringValue {
            updateStreetLocalityStateCountry(
                    street: tokenHolder.values.streetSubscribableStringValue,
                    locality: tokenHolder.values.localitySubscribableStringValue,
                    state: tokenHolder.values.stateSubscribableStringValue,
                    country: country
            )
        }
    }

    var time: String {
        let value = tokenHolder.values.timeGeneralisedTimeValue ?? GeneralisedTime()
        return value.format("h:mm a")
    }

    var onlyShowTitle: Bool {
        return !tokenHolder.hasAssetDefinition
    }

    var tokenScriptHtml: (html: String, hash: Int) {
        let xmlHandler = XMLHandler(contract: tokenHolder.contractAddress, tokenType: tokenHolder.tokenType, assetDefinitionStore: assetDefinitionStore)
        let html: String
        let style: String
        switch tokenView {
        case .view:
            (html, style) = xmlHandler.tokenViewHtml
        case .viewIconified:
            (html, style) = xmlHandler.tokenViewIconifiedHtml
        }
        let hash = html.hashForCachingHeight
        return (html: wrapWithHtmlViewport(html: html, style: style, forTokenHolder: tokenHolder), hash: hash)
    }

    var hasTokenScriptHtml: Bool {
        //TODO improve performance? Because it is generated again when used
        return !tokenScriptHtml.html.isEmpty
    }
}
