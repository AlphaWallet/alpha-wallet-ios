// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import Combine
import AlphaWalletCore
import AlphaWalletFoundation
import AlphaWalletTokenScript

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

    func buildingPublisher() -> AnyPublisher<String, Never> {
        return (viewModel.tokenHolder?.values.buildingSubscribableValue?.publisher ?? .empty())
            .compactMap { $0?.stringValue }
            .eraseToAnyPublisher()
    }

    func streetLocalityStateCountryPublisher() -> AnyPublisher<String, Never> {
        let street = (viewModel.tokenHolder?.values.streetSubscribableValue?.publisher ?? .empty())
            .map { $0?.stringValue }
            .replaceEmpty(with: nil)

        let state = (viewModel.tokenHolder?.values.stateSubscribableValue?.publisher ?? .empty())
            .map { $0?.stringValue }
            .replaceEmpty(with: nil)

        let locality = (viewModel.tokenHolder?.values.localitySubscribableValue?.publisher ?? .empty())
            .map { $0?.stringValue }
            .replaceEmpty(with: nil)

        let country = Just(viewModel.tokenHolder?.values.countryStringValue)

        return Publishers.CombineLatest4(street, locality, state, country)
            .map { [$0, $1, $2, $3].compactMap { $0 }.joined(separator: ", ") }
            .eraseToAnyPublisher()
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
