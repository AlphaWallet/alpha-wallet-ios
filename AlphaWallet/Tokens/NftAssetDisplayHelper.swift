//
//  NftAssetDisplayHelper.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 23.12.2021.
//

import Foundation
import AlphaWalletOpenSea
import AlphaWalletFoundation
import AlphaWalletTokenScript
import Combine

final class NftAssetDisplayHelper {
    private (set) var tokenId: TokenId
    private (set) var tokenHolder: TokenHolder
    private let displayHelper: OpenSeaNonFungibleTokenDisplayHelper
    private let assetDefinitionStore: AssetDefinitionStore
    private let tokenAttributeValues: AssetAttributeValues

    private var openSeaCollection: AlphaWalletOpenSea.NftCollection? {
        values?.collectionValue
    }
    private var openSeaStats: Stats? {
        overiddenOpenSeaStats ?? openSeaCollection?.stats
    }
    var overiddenOpenSeaStats: Stats?
    var overridenFloorPrice: Double?
    var overridenItemsCount: Double?

    init(tokenId: TokenId, tokenHolder: TokenHolder, assetDefinitionStore: AssetDefinitionStore) {
        self.tokenId = tokenId
        self.tokenHolder = tokenHolder
        self.assetDefinitionStore = assetDefinitionStore
        self.tokenAttributeValues = AssetAttributeValues(attributeValues: tokenHolder.values)
        self.displayHelper = OpenSeaNonFungibleTokenDisplayHelper(contract: tokenHolder.contractAddress)
    }

    func update(tokenHolder: TokenHolder, tokenId: TokenId) {
        self.tokenId = tokenId
        self.tokenHolder = tokenHolder
    }

    private var values: [AttributeId: AssetAttributeSyntaxValue]? {
        guard let values = tokenHolder.values(tokenId: tokenId), !values.isEmpty else { return nil }
        return values
    }

    var descriptionViewModel: TokenAttributeViewModel? {
        return values?.collectionDescriptionStringValue.flatMap {
            guard $0.nonEmpty else { return nil }
            return TokenAttributeViewModel.defaultValueAttributedString($0, alignment: .left)
        }.flatMap {
            .init(title: nil, attributedValue: $0, value: $0.string, isSeparatorHidden: true)
        }
    }

    var createdDateViewModel: TokenAttributeViewModel? {
        return values?.collectionCreatedDateGeneralisedTimeValue
            .flatMap { TokenAttributeViewModel.defaultValueAttributedString($0.formatAsShortDateString()) }
            .flatMap { .init(title: R.string.localizable.semifungiblesCreatedDate(), attributedValue: $0) }
    }

    var tokenIdViewModel: TokenAttributeViewModel? {
        return values?.tokenIdStringValue
            .flatMap { TokenAttributeViewModel.defaultValueAttributedString($0) }
            .flatMap {
                var viewModel: TokenAttributeViewModel
                viewModel = .init(title: R.string.localizable.semifungiblesTokenId(), attributedValue: $0, value: values?.tokenIdStringValue)
                viewModel.valueLabelNumberOfLines = 1

                return viewModel
            }
    }

    var supplyModelViewModel: TokenAttributeViewModel? {
        return values?.supplyModel
            .flatMap { TokenAttributeViewModel.defaultValueAttributedString($0) }
            .flatMap { .init(title: R.string.localizable.semifungiblesAttributeSupplyType(), attributedValue: $0) }
    }

    var valueModelViewModel: TokenAttributeViewModel? {
        return values?.valueIntValue
            .flatMap {
                guard $0 > 1 else { return nil }
                return TokenAttributeViewModel.defaultValueAttributedString(String($0))
            }.flatMap { .init(title: R.string.localizable.semifungiblesValue(), attributedValue: $0) }
    }

    var transferableViewModel: TokenAttributeViewModel? {
        return values?.transferable
            .flatMap { TokenAttributeViewModel.defaultValueAttributedString($0) }
            .flatMap { .init(title: R.string.localizable.semifungiblesAttributeTransferable(), attributedValue: $0) }
    }

    var meltValueViewModel: TokenAttributeViewModel? {
        return values?.meltStringValue
            .flatMap { TokenAttributeViewModel.defaultValueAttributedString($0) }
            .flatMap { .init(title: R.string.localizable.semifungiblesAttributeMelt(), attributedValue: $0) }
    }

    var meltFeeRatioViewModel: TokenAttributeViewModel? {
        return values?.meltFeeRatio
            .flatMap { TokenAttributeViewModel.defaultValueAttributedString(String($0)) }
            .flatMap { .init(title: R.string.localizable.semifungiblesAttributeMeltFeeRatio(), attributedValue: $0) }
    }

    var meltFeeMaxRatioViewModel: TokenAttributeViewModel? {
        return values?.meltFeeMaxRatio
            .flatMap { TokenAttributeViewModel.defaultValueAttributedString(String($0)) }
            .flatMap { .init(title: R.string.localizable.semifungiblesAttributeMeltFeeMaxRatio(), attributedValue: $0) }
    }

    var totalSupplyViewModel: TokenAttributeViewModel? {
        return values?.totalSupplyStringValue
            .flatMap { TokenAttributeViewModel.defaultValueAttributedString($0) }
            .flatMap { .init(title: R.string.localizable.semifungiblesAttributeTotalSupply(), attributedValue: $0) }
    }

    var circulatingSupplyViewModel: TokenAttributeViewModel? {
        return values?.circulatingSupplyStringValue
            .flatMap { TokenAttributeViewModel.defaultValueAttributedString($0) }
            .flatMap { .init(title: R.string.localizable.semifungiblesAttributeCirculatingSupply(), attributedValue: $0) }
    }

    var reserveViewModel: TokenAttributeViewModel? {
        return values?.reserve
            .flatMap { TokenAttributeViewModel.defaultValueAttributedString($0) }
            .flatMap { .init(title: R.string.localizable.semifungiblesAttributeReserve(), attributedValue: $0) }
    }

    var nonFungibleViewModel: TokenAttributeViewModel? {
        return values?.nonFungible
            .flatMap { TokenAttributeViewModel.defaultValueAttributedString(String($0)) }
            .flatMap { .init(title: R.string.localizable.semifungiblesAttributeNonFungible(), attributedValue: $0) }
    }

    var availableToMintViewModel: TokenAttributeViewModel? {
        return values?.mintableSupply
            .flatMap { TokenAttributeViewModel.defaultValueAttributedString(String($0)) }
            .flatMap { .init(title: R.string.localizable.semifungiblesAttributeAvailableToMint(), attributedValue: $0) }
    }

    var issuerViewModel: TokenAttributeViewModel? {
        return values?.enjinIssuer
            .flatMap { TokenAttributeViewModel.urlValueAttributedString($0) }
            .flatMap { .init(title: R.string.localizable.semifungiblesAttributeIssuer(), attributedValue: $0) }
    }

    var transferFeeViewModel: TokenAttributeViewModel? {
        return values?.transferFee
            .flatMap { TokenAttributeViewModel.defaultValueAttributedString(String($0)) }
            .flatMap { .init(title: R.string.localizable.semifungiblesAttributeTransferFee(), attributedValue: $0) }
    }

    var itemsCountRawValue: Double? {
        return tokenHolder.values.collectionValue?.stats?.itemsCount ?? overridenItemsCount
    }

    var attributes: AnyPublisher<[NonFungibleTraitViewModel], Never> {
        let openSeaTraits: [OpenSeaNonFungibleTrait] = tokenHolder.openSeaNonFungibleTraits ?? []
        return functional.extractTokenScriptTokenLevelAttributesWithLabels(tokenHolder: tokenHolder, tokenAttributeValues: tokenAttributeValues, assetDefinitionStore: assetDefinitionStore).map { tokenScriptAttributes in
            let tokenScriptAttributeIds: [String] = tokenScriptAttributes.map(\.type)
            let openSeaTraitsNotOverriddenByTokenScript: [OpenSeaNonFungibleTrait] = openSeaTraits.filter { !tokenScriptAttributeIds.contains($0.type) }
            let traits: [OpenSeaNonFungibleTrait] = openSeaTraitsNotOverriddenByTokenScript + tokenScriptAttributes

            let traitsToDisplay = traits.filter { self.displayHelper.shouldDisplayAttribute(name: $0.type) }
            return traitsToDisplay.map { trait in
                let rarity: Int? = self.itemsCountRawValue
                    .flatMap { (Double(trait.count) / $0 * 100.0).rounded(to: 0) }
                    .flatMap { Int($0) }

                if let rarity = rarity {
                    let displayName = self.displayHelper.mapTraitsToDisplayName(name: trait.type)
                    let attribute = TokenAttributeViewModel.boldValueAttributedString("\(trait.value)".titleCasedWords(), alignment: .center)
                    var rarityValue: String
                    if rarity == 0 {
                        rarityValue = R.string.localizable.nonfungiblesValueRarityUnique()
                    } else {
                        rarityValue = R.string.localizable.nonfungiblesValueRarity(rarity, "%")
                    }
                    let rarity = TokenAttributeViewModel.defaultValueAttributedString(rarityValue, alignment: .center)

                    return .init(title: displayName, attributedValue: attribute, attributedCountValue: rarity)
                } else {
                    // swiftlint:disable empty_count
                    if trait.count == 0 {
                    // swiftlint:enable empty_count
                        //Especially for TokenScript attributes
                        return self.mapTraitsToProperName(name: trait.type, value: trait.value, count: nil)
                    } else {
                        return self.mapTraitsToProperName(name: trait.type, value: trait.value, count: String(trait.count))
                    }
                }
            }
        }.eraseToAnyPublisher()
    }

    var rankings: [NonFungibleTraitViewModel] {
        let traits = tokenHolder.openSeaNonFungibleTraits ?? []
        let traitsToDisplay = traits.filter { displayHelper.shouldDisplayRanking(name: $0.type) }
        return traitsToDisplay.map { mapTraitsToProperName(name: $0.type, value: $0.value, count: String($0.count)) }
    }

    var stats: [NonFungibleTraitViewModel] {
        let traits = tokenHolder.openSeaNonFungibleTraits ?? []
        let traitsToDisplay = traits.filter { displayHelper.shouldDisplayStat(name: $0.type) }
        return traitsToDisplay.map { mapTraitsToProperName(name: $0.type, value: $0.value, count: String($0.count)) }
    }

    private func mapTraitsToProperName(name: String, value: String, count: String? = nil) -> NonFungibleTraitViewModel {
        let displayName = displayHelper.mapTraitsToDisplayName(name: name).replacingEmpty("-")
        let displayValue = displayHelper.mapTraitsToDisplayValue(name: name, value: value).replacingEmpty("-")

        let attributedValue = TokenAttributeViewModel.defaultValueAttributedString(displayValue, alignment: .center)
        let count = count.flatMap { TokenAttributeViewModel.defaultValueAttributedString($0, alignment: .center) }

        return .init(title: displayName, attributedValue: attributedValue, attributedCountValue: count)
    }

    var itemsCount: TokenAttributeViewModel? {
        return openSeaStats
            .flatMap { StringFormatter().largeNumberFormatter(for: $0.itemsCount, currency: "", decimals: 0) }
            .flatMap {
                let attributedValue = TokenAttributeViewModel.defaultValueAttributedString($0)
                return .init(title: R.string.localizable.nonfungiblesValueItemsCount(), attributedValue: attributedValue)
            }
    }

    var totalVolume: TokenAttributeViewModel? {
        return openSeaStats
            .flatMap { NumberFormatter.shortCrypto.string(double: $0.totalVolume).flatMap { "\($0) \(RPCServer.main.symbol)" } }
            .flatMap {
                let attributedValue = TokenAttributeViewModel.defaultValueAttributedString($0)
                return .init(title: R.string.localizable.nonfungiblesValueTotalVolume(), attributedValue: attributedValue)
            }
    }

    private var decimalsForTotalSupplyOrTotalSales: Int {
        switch tokenHolder.tokenType(tokenId: tokenId) {
        case .erc20, .erc721, .erc721ForTickets, .erc875, .nativeCryptocurrency, .none:
            return 0
        case .erc1155:
            return 1
        }
    }

    var totalSales: TokenAttributeViewModel? {
        return openSeaStats
            .flatMap { StringFormatter().largeNumberFormatter(for: $0.totalSales, currency: "", decimals: decimalsForTotalSupplyOrTotalSales) }
            .flatMap {
                let attributedValue = TokenAttributeViewModel.defaultValueAttributedString($0)
                return .init(title: R.string.localizable.nonfungiblesValueTotalSales(), attributedValue: attributedValue)
            }
    }

    var totalSupply: TokenAttributeViewModel? {
        return openSeaStats
            .flatMap { StringFormatter().largeNumberFormatter(for: $0.totalSupply, currency: "", decimals: decimalsForTotalSupplyOrTotalSales) }
            .flatMap {
                let attributedValue = TokenAttributeViewModel.defaultValueAttributedString($0)
                return .init(title: R.string.localizable.nonfungiblesValueTotalSupply(), attributedValue: attributedValue)
            }
    }

    var owners: TokenAttributeViewModel? {
        return openSeaStats
            .flatMap { TokenAttributeViewModel.defaultValueAttributedString(String($0.owners)) }
            .flatMap {
                .init(title: R.string.localizable.nonfungiblesValueOwners(), attributedValue: $0)
            }
    }

    var averagePrice: TokenAttributeViewModel? {
        return openSeaStats
            .flatMap { NumberFormatter.shortCrypto.string(double: $0.averagePrice) }
            .flatMap {
                let attributedValue = TokenAttributeViewModel.defaultValueAttributedString($0)
                return .init(title: R.string.localizable.nonfungiblesValueAveragePrice(), attributedValue: attributedValue)
            }
    }

    var marketCap: TokenAttributeViewModel? {
        return openSeaStats
            .flatMap { StringFormatter().largeNumberFormatter(for: $0.marketCap, currency: "") }
            .flatMap {
                let attributedValue = TokenAttributeViewModel.defaultValueAttributedString($0)
                return .init(title: R.string.localizable.nonfungiblesValueMarketCap(), attributedValue: attributedValue)
            }
    }

    var floorPrice: TokenAttributeViewModel? {
        return (overridenFloorPrice ?? openSeaStats?.floorPrice)
            .flatMap { NumberFormatter.shortCrypto.string(double: $0).flatMap { "\($0) \(RPCServer.main.symbol)" } }
            .flatMap {
                let attributedValue = TokenAttributeViewModel.defaultValueAttributedString($0)
                return .init(title: R.string.localizable.nonfungiblesValueFloorPrice(), attributedValue: attributedValue)
            }
    }

    var creator: TokenAttributeViewModel? {
        let value = values?.creatorValue?.contractAddress.eip55String
        return values?.creatorValue.flatMap { creator -> String in
            if let user = creator.user.flatMap({ $0.trimmed }), user.nonEmpty {
                return user
            } else {
                return creator.contractAddress.truncateMiddle
            }
        //TODO localize
        }.flatMap { .init(title: "Created By", attributedValue: TokenAttributeViewModel.urlValueAttributedString($0), value: value) }
    }
}

extension NftAssetDisplayHelper {
    enum functional {}
}

fileprivate extension NftAssetDisplayHelper.functional {
    static func extractTokenScriptTokenLevelAttributesWithLabels(tokenHolder: TokenHolder, tokenAttributeValues: AssetAttributeValues, assetDefinitionStore: AssetDefinitionStore) -> AnyPublisher<[OpenSeaNonFungibleTrait], Never> {
        let xmlHandler = assetDefinitionStore.xmlHandler(forContract: tokenHolder.contractAddress, tokenType: tokenHolder.tokenType)
        return tokenAttributeValues.resolveAllAttributes()
            .map { resolvedTokenAttributeNameValues in
                let tokenLevelAttributeIdsAndNames = xmlHandler.fieldIdsAndNamesExcludingBase
                let tokenLevelAttributeIds = tokenLevelAttributeIdsAndNames.keys
                let toDisplay = resolvedTokenAttributeNameValues.filter { attributeId, _ in !tokenLevelAttributeIdsAndNames[attributeId].isEmpty && tokenLevelAttributeIds.contains(attributeId) }
                var results: [OpenSeaNonFungibleTrait] = []
                for (attributeId, value) in toDisplay {
                    let convertor = AssetAttributeToUserInterfaceConvertor()
                    if let value = convertor.formatAsTokenScriptString(value: value), let name = tokenLevelAttributeIdsAndNames[attributeId]?.trimmed {
                        results.append(OpenSeaNonFungibleTrait(count: 0, type: name, value: value))
                    }
                }
                return results
            }.eraseToAnyPublisher()
    }
}

extension String {
    func replacingEmpty(_ other: String) -> String {
        let value = trimmed
        return value.isEmpty ? other : value
    }
}

