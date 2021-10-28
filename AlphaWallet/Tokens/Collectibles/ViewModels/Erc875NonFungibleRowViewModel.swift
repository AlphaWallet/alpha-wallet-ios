//
//  Erc875NonFungibleRowViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 15.11.2021.
//

import UIKit

struct Erc875NonFungibleRowViewModel: TokenCardRowViewModelProtocol {
    private let tokenHolder: TokenHolder
    private let tokenView: TokenView
    private let assetDefinitionStore: AssetDefinitionStore
    private let displayHelper: OpenSeaNonFungibleTokenDisplayHelper
    private let tokenId: TokenId

    var contentsBackgroundColor: UIColor {
        return .clear
    }

    init(tokenHolder: TokenHolder, tokenId: TokenId, tokenView: TokenView, assetDefinitionStore: AssetDefinitionStore) {
        self.tokenHolder = tokenHolder
        self.tokenId = tokenId
        self.tokenView = tokenView
        self.assetDefinitionStore = assetDefinitionStore
        displayHelper = .init(contract: tokenHolder.contractAddress)
    }

    var title: String {
        let tokenId = tokenHolder.values.tokenIdStringValue ?? ""
        if let name = tokenHolder.values.nameStringValue.nilIfEmpty {
            return name
        } else {
            return displayHelper.title(fromTokenName: tokenHolder.name, tokenId: tokenId)
        }
    }

    var attributedDescriptionText: NSAttributedString {
        return .init(string: R.string.localizable.semifungiblesAssetsCount(_tokenCount), attributes: [
            .foregroundColor: Screen.TokenCard.Color.subtitle,
            .font: Screen.TokenCard.Font.subtitle
        ])
    }

    var _tokenCount: Int {

        Int(tokenHolder.values.valueIntValue ?? 0)
    }

    var tokenCount: String {
        return "x\(_tokenCount)"
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
                            locality: self.tokenHolder.values.localitySubscribableStringValue,
                            state: self.tokenHolder.values.stateSubscribableStringValue,
                            country: self.tokenHolder.values.countryStringValue
                    )
                }
            }
        }
        if let subscribable = tokenHolder.values.stateSubscribableValue {
            subscribable.subscribe { value in
                if let value = value?.stringValue {
                    updateStreetLocalityStateCountry(
                            street: self.tokenHolder.values.streetSubscribableStringValue,
                            locality: self.tokenHolder.values.localitySubscribableStringValue,
                            state: value,
                            country: self.tokenHolder.values.countryStringValue
                    )
                }
            }
        }

        if let subscribable = tokenHolder.values.localitySubscribableValue {
            subscribable.subscribe { value in
                if let value = value?.stringValue {
                    updateStreetLocalityStateCountry(
                            street: self.tokenHolder.values.streetSubscribableStringValue,
                            locality: value,
                            state: self.tokenHolder.values.stateSubscribableStringValue,
                            country: self.tokenHolder.values.countryStringValue
                    )
                }
            }
        }

        if let country = tokenHolder.values.countryStringValue {
            updateStreetLocalityStateCountry(
                    street: self.tokenHolder.values.streetSubscribableStringValue,
                    locality: self.tokenHolder.values.localitySubscribableStringValue,
                    state: self.tokenHolder.values.stateSubscribableStringValue,
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
