//
//  NftCollectionDisplayHelper.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 02.03.2023.
//

import Foundation
import AlphaWalletOpenSea
import AlphaWalletFoundation
import AlphaWalletTokenScript

final class NftCollectionDisplayHelper {
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

    var itemsCountRawValue: Double? {
        return tokenHolder.values.collectionValue?.stats?.itemsCount ?? overridenItemsCount
    }

    var ownedAssetCountViewModel: TokenAttributeViewModel? {
        openSeaCollection.flatMap {
            TokenAttributeViewModel.defaultValueAttributedString(String($0.ownedAssetCount))
        }.flatMap { .init(title: R.string.localizable.nonfungiblesValueOwnedAssetCount(), attributedValue: $0, value: $0.string) }
    }

    var wikiUrlViewModel: TokenAttributeViewModel? {
        openSeaCollection?.wikiUrl.flatMap {
            guard $0.nonEmpty else { return nil }
            return TokenAttributeViewModel.urlValueAttributedString(R.string.localizable.visitWiki())
        }.flatMap { .init(title: R.string.localizable.wiki(), attributedValue: $0, value: openSeaCollection?.wikiUrl) }
    }

    var instagramUsernameViewModel: TokenAttributeViewModel? {
        openSeaCollection?.instagramUsername.flatMap {
            guard $0.nonEmpty else { return nil }
            return TokenAttributeViewModel.urlValueAttributedString(R.string.localizable.openOnInstagram())
        }.flatMap { .init(title: R.string.localizable.instagram(), attributedValue: $0, value: openSeaCollection?.instagramUsername) }
    }

    var twitterUsernameViewModel: TokenAttributeViewModel? {
        openSeaCollection?.twitterUsername.flatMap {
            guard $0.nonEmpty else { return nil }
            return TokenAttributeViewModel.urlValueAttributedString(R.string.localizable.openOnTwitter())
        }.flatMap { .init(title: R.string.localizable.twitter(), attributedValue: $0, value: openSeaCollection?.twitterUsername) }
    }

    var discordUrlViewModel: TokenAttributeViewModel? {
        openSeaCollection?.discordUrl.flatMap {
            guard $0.nonEmpty else { return nil }
            return TokenAttributeViewModel.urlValueAttributedString(R.string.localizable.openOnDiscord())
        }.flatMap { .init(title: R.string.localizable.discord(), attributedValue: $0, value: openSeaCollection?.discordUrl) }
    }

    var telegramUrlViewModel: TokenAttributeViewModel? {
        openSeaCollection?.telegramUrl.flatMap {
            guard $0.nonEmpty else { return nil }
            return TokenAttributeViewModel.urlValueAttributedString(R.string.localizable.openOnTelegram())
        }.flatMap { .init(title: R.string.localizable.telegram(), attributedValue: $0, value: openSeaCollection?.telegramUrl) }
    }

    var externalUrlViewModel: TokenAttributeViewModel? {
        openSeaCollection?.externalUrl.flatMap {
            guard $0.nonEmpty else { return nil }
            return TokenAttributeViewModel.urlValueAttributedString(R.string.localizable.visitWebsite())
        }.flatMap { .init(title: R.string.localizable.website(), attributedValue: $0, value: openSeaCollection?.externalUrl, isSeparatorHidden: true) }
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

    var numReports: TokenAttributeViewModel? {
        return openSeaStats
            .flatMap { TokenAttributeViewModel.defaultValueAttributedString(String($0.numReports)) }
            .flatMap { .init(title: R.string.localizable.nonfungiblesValueNumReports(), attributedValue: $0) }
    }
}
