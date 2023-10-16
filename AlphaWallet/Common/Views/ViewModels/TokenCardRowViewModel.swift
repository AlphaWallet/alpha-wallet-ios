// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import AlphaWalletFoundation
import AlphaWalletTokenScript
import Combine

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

    func buildingPublisher() -> AnyPublisher<String, Never> {
        return (tokenHolder.values.buildingSubscribableValue?.publisher ?? .empty())
            .replaceEmpty(with: nil)
            .compactMap { $0?.stringValue }
            .eraseToAnyPublisher()
    }

    func streetLocalityStateCountryPublisher() -> AnyPublisher<String, Never> {
        let street = (tokenHolder.values.streetSubscribableValue?.publisher ?? .empty())
            .map { $0?.stringValue }
            .replaceEmpty(with: nil)

        let state = (tokenHolder.values.stateSubscribableValue?.publisher ?? .empty())
            .map { $0?.stringValue }
            .replaceEmpty(with: nil)

        let locality = (tokenHolder.values.localitySubscribableValue?.publisher ?? .empty())
            .map { $0?.stringValue }
            .replaceEmpty(with: nil)

        let country = Just(tokenHolder.values.countryStringValue)

        return Publishers.CombineLatest4(street, locality, state, country)
            .map { [$0, $1, $2, $3].compactMap { $0 }.joined(separator: ", ") }
            .eraseToAnyPublisher()
    }

    var time: String {
        let value = tokenHolder.values.timeGeneralisedTimeValue ?? GeneralisedTime()
        return value.format("h:mm a")
    }

    var onlyShowTitle: Bool {
        return !tokenHolder.hasAssetDefinition
    }

    var tokenScriptHtml: (html: String, urlFragment: String?) {
        let xmlHandler = assetDefinitionStore.xmlHandler(forContract: tokenHolder.contractAddress, tokenType: tokenHolder.tokenType)
        let html: String
        let urlFragment: String?
        let style: String
        switch tokenView {
        case .view:
            (html, urlFragment, style) = xmlHandler.tokenViewHtml
        case .viewIconified:
            (html, urlFragment, style) = xmlHandler.tokenViewIconifiedHtml
        }
        return (html: wrapWithHtmlViewport(html: html, style: style, forTokenId: tokenHolder.tokenId), urlFragment: urlFragment)
    }

    var hasTokenScriptHtml: Bool {
        //TODO improve performance? Because it is generated again when used
        return !tokenScriptHtml.html.isEmpty
    }
}
