// Copyright © 2018 Stormbird PTE. LTD.

import Foundation

struct ImportMagicTokenCardRowViewModel: TokenCardRowViewModelProtocol {
    private var importMagicTokenViewControllerViewModel: ImportMagicTokenViewControllerViewModel
    private let assetDefinitionStore: AssetDefinitionStore

    init(importMagicTokenViewControllerViewModel: ImportMagicTokenViewControllerViewModel, assetDefinitionStore: AssetDefinitionStore) {
        self.importMagicTokenViewControllerViewModel = importMagicTokenViewControllerViewModel
        self.assetDefinitionStore = assetDefinitionStore
    }

    var tokenHolder: TokenHolder? {
        return importMagicTokenViewControllerViewModel.tokenHolder
    }

    var tokenCount: String {
        return importMagicTokenViewControllerViewModel.tokenCount
    }

    var city: String {
        return importMagicTokenViewControllerViewModel.city
    }

    var category: String {
        return importMagicTokenViewControllerViewModel.category
    }

    var teams: String {
        return importMagicTokenViewControllerViewModel.teams
    }

    var match: String {
        return importMagicTokenViewControllerViewModel.match
    }

    var venue: String {
        return importMagicTokenViewControllerViewModel.venue
    }

    var date: String {
        return importMagicTokenViewControllerViewModel.date
    }

    var numero: String {
        return importMagicTokenViewControllerViewModel.numero
    }

    var time: String {
        return importMagicTokenViewControllerViewModel.time
    }

    var onlyShowTitle: Bool {
        return importMagicTokenViewControllerViewModel.onlyShowTitle
    }

    var isMeetupContract: Bool {
        return importMagicTokenViewControllerViewModel.tokenHolder?.isSpawnableMeetupContract ?? false
    }

    func subscribeBuilding(withBlock block: @escaping (String) -> Void) {
        if case .some(.subscribable(let subscribable)) = importMagicTokenViewControllerViewModel.tokenHolder?.values["building"]?.value {
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
        if case .some(.subscribable(let subscribable)) = importMagicTokenViewControllerViewModel.tokenHolder?.values["street"]?.value {
            subscribable.subscribe { value in
                guard let tokenHolder = self.importMagicTokenViewControllerViewModel.tokenHolder else { return }
                if let value = value?.stringValue {
                    updateStreetLocalityStateCountry(
                            street: value,
                            locality: tokenHolder.values["locality"]?.subscribableStringValue,
                            state: tokenHolder.values["state"]?.subscribableStringValue,
                            country: tokenHolder.values["country"]?.stringValue
                    )
                }
            }
        }
        if case .some(.subscribable(let subscribable)) = importMagicTokenViewControllerViewModel.tokenHolder?.values["state"]?.value {
            subscribable.subscribe { value in
                guard let tokenHolder = self.importMagicTokenViewControllerViewModel.tokenHolder else { return }
                if let value = value?.stringValue {
                    updateStreetLocalityStateCountry(
                            street: tokenHolder.values["street"]?.subscribableStringValue,
                            locality: tokenHolder.values["locality"]?.subscribableStringValue,
                            state: value,
                            country: tokenHolder.values["country"]?.stringValue
                    )
                }
            }
        }
        if case .some(.subscribable(let subscribable)) = importMagicTokenViewControllerViewModel.tokenHolder?.values["locality"]?.value {
            subscribable.subscribe { value in
                guard let tokenHolder = self.importMagicTokenViewControllerViewModel.tokenHolder else { return }
                if let value = value?.stringValue {
                    updateStreetLocalityStateCountry(
                            street: tokenHolder.values["street"]?.subscribableStringValue,
                            locality: value,
                            state: tokenHolder.values["state"]?.subscribableStringValue,
                            country: tokenHolder.values["country"]?.stringValue
                    )
                }
            }
        }
        if let country = importMagicTokenViewControllerViewModel.tokenHolder?.values["country"]?.stringValue {
            guard let tokenHolder = self.importMagicTokenViewControllerViewModel.tokenHolder else { return }
            updateStreetLocalityStateCountry(
                    street: tokenHolder.values["street"]?.subscribableStringValue,
                    locality: tokenHolder.values["locality"]?.subscribableStringValue,
                    state: tokenHolder.values["state"]?.subscribableStringValue,
                    country: country
            )
        }
    }

    var tokenScriptHtml: (html: String, hash: Int) {
        guard let tokenHolder = importMagicTokenViewControllerViewModel.tokenHolder else { return (html: "", hash: 0) }
        let xmlHandler = XMLHandler(contract: tokenHolder.contractAddress, assetDefinitionStore: assetDefinitionStore)
        let (html: html, style: style) = xmlHandler.tokenViewIconifiedHtml
        //Just an easy way to generate a hash for style + HTML
        let hash = "\(style)\(html)".hashForCachingHeight
        return (html: wrapWithHtmlViewport(html: html, style: style, forTokenHolder: tokenHolder), hash: hash)
    }

    var hasTokenScriptHtml: Bool {
        //TODO improve performance? Because it is generated again when used
        return !tokenScriptHtml.html.isEmpty
    }
}
