// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import AlphaWalletFoundation

struct ImportMagicTokenCardRowViewModel: TokenCardRowViewModelProtocol {
    private let viewModel: ImportMagicTokenViewModel
    private let assetDefinitionStore: AssetDefinitionStore

    init(viewModel: ImportMagicTokenViewModel, assetDefinitionStore: AssetDefinitionStore) {
        self.viewModel = viewModel
        self.assetDefinitionStore = assetDefinitionStore
    }

    var tokenHolder: TokenHolder? {
        return viewModel.tokenHolder
    }

    var tokenCount: String {
        return viewModel.tokenCount
    }

    var city: String {
        return viewModel.city
    }

    var category: String {
        return viewModel.category
    }

    var teams: String {
        return viewModel.teams
    }

    var match: String {
        return viewModel.match
    }

    var venue: String {
        return viewModel.venue
    }

    var date: String {
        return viewModel.date
    }

    var numero: String {
        return viewModel.numero
    }

    var time: String {
        return viewModel.time
    }

    var onlyShowTitle: Bool {
        return viewModel.onlyShowTitle
    }

    var isMeetupContract: Bool {
        return viewModel.tokenHolder?.isSpawnableMeetupContract ?? false
    }

    func subscribeBuilding(withBlock block: @escaping (String) -> Void) {
        if let subscribable = viewModel.tokenHolder?.values.buildingSubscribableValue {
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

        if let subscribable = viewModel.tokenHolder?.values.streetSubscribableValue {
            subscribable.subscribe { value in
                guard let tokenHolder = self.viewModel.tokenHolder else { return }
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
        if let subscribable = viewModel.tokenHolder?.values.stateSubscribableValue {
            subscribable.subscribe { value in
                guard let tokenHolder = self.viewModel.tokenHolder else { return }
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
        if let subscribable = viewModel.tokenHolder?.values.localitySubscribableValue {
            subscribable.subscribe { value in
                guard let tokenHolder = self.viewModel.tokenHolder else { return }
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
        if let country = viewModel.tokenHolder?.values.countryStringValue {
            guard let tokenHolder = self.viewModel.tokenHolder else { return }
            updateStreetLocalityStateCountry(
                    street: tokenHolder.values.streetSubscribableStringValue,
                    locality: tokenHolder.values.localitySubscribableStringValue,
                    state: tokenHolder.values.stateSubscribableStringValue,
                    country: country
            )
        }
    }

    var tokenScriptHtml: String {
        guard let tokenHolder = viewModel.tokenHolder else { return "" }
        let xmlHandler = XMLHandler(contract: tokenHolder.contractAddress, tokenType: tokenHolder.tokenType, assetDefinitionStore: assetDefinitionStore)
        let (html: html, style: style) = xmlHandler.tokenViewIconifiedHtml

        return wrapWithHtmlViewport(html: html, style: style, forTokenId: tokenHolder.tokenIds[0])
    }

    var hasTokenScriptHtml: Bool {
        //TODO improve performance? Because it is generated again when used
        return !tokenScriptHtml.isEmpty
    }
}
