// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import AlphaWalletFoundation

struct ImportMagicTokenCardRowViewModel: TokenCardRowViewModelProtocol {
    private var importMagicTokenViewModel: ImportMagicTokenViewModel
    private let assetDefinitionStore: AssetDefinitionStore

    init(importMagicTokenViewModel: ImportMagicTokenViewModel, assetDefinitionStore: AssetDefinitionStore) {
        self.importMagicTokenViewModel = importMagicTokenViewModel
        self.assetDefinitionStore = assetDefinitionStore
    }

    var tokenHolder: TokenHolder? {
        return importMagicTokenViewModel.tokenHolder
    }

    var tokenCount: String {
        return importMagicTokenViewModel.tokenCount
    }

    var city: String {
        return importMagicTokenViewModel.city
    }

    var category: String {
        return importMagicTokenViewModel.category
    }

    var teams: String {
        return importMagicTokenViewModel.teams
    }

    var match: String {
        return importMagicTokenViewModel.match
    }

    var venue: String {
        return importMagicTokenViewModel.venue
    }

    var date: String {
        return importMagicTokenViewModel.date
    }

    var numero: String {
        return importMagicTokenViewModel.numero
    }

    var time: String {
        return importMagicTokenViewModel.time
    }

    var onlyShowTitle: Bool {
        return importMagicTokenViewModel.onlyShowTitle
    }

    var isMeetupContract: Bool {
        return importMagicTokenViewModel.tokenHolder?.isSpawnableMeetupContract ?? false
    }

    func subscribeBuilding(withBlock block: @escaping (String) -> Void) {
        if let subscribable = importMagicTokenViewModel.tokenHolder?.values.buildingSubscribableValue {
            subscribable.subscribe { value in
                value?.stringValue.flatMap { block($0) }
            }
        }
    }

    func subscribeStreetLocalityStateCountry(withBlock block: @escaping (String) -> Void) {
        func updateStreetLocalityStateCountry(street: String?, locality: String?, state: String?, country: String?) {
            let values = [street, locality, state, country].compactMap { $0 }
            let string = values.joined(separator: ", ")
            block(string)
        }
        if let subscribable = importMagicTokenViewModel.tokenHolder?.values.streetSubscribableValue {
            subscribable.subscribe { value in
                guard let tokenHolder = self.importMagicTokenViewModel.tokenHolder else { return }
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
        if let subscribable = importMagicTokenViewModel.tokenHolder?.values.stateSubscribableValue {
            subscribable.subscribe { value in
                guard let tokenHolder = self.importMagicTokenViewModel.tokenHolder else { return }
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
        if let subscribable = importMagicTokenViewModel.tokenHolder?.values.localitySubscribableValue {
            subscribable.subscribe { value in
                guard let tokenHolder = self.importMagicTokenViewModel.tokenHolder else { return }
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
        if let country = importMagicTokenViewModel.tokenHolder?.values.countryStringValue {
            guard let tokenHolder = self.importMagicTokenViewModel.tokenHolder else { return }
            updateStreetLocalityStateCountry(
                    street: tokenHolder.values.streetSubscribableStringValue,
                    locality: tokenHolder.values.localitySubscribableStringValue,
                    state: tokenHolder.values.stateSubscribableStringValue,
                    country: country
            )
        }
    }

    var tokenScriptHtml: String {
        guard let tokenHolder = importMagicTokenViewModel.tokenHolder else { return "" }
        let xmlHandler = XMLHandler(contract: tokenHolder.contractAddress, tokenType: tokenHolder.tokenType, assetDefinitionStore: assetDefinitionStore)
        let (html: html, style: style) = xmlHandler.tokenViewIconifiedHtml

        return wrapWithHtmlViewport(html: html, style: style, forTokenId: tokenHolder.tokenIds[0])
    }

    var hasTokenScriptHtml: Bool {
        //TODO improve performance? Because it is generated again when used
        return !tokenScriptHtml.isEmpty
    }
}
