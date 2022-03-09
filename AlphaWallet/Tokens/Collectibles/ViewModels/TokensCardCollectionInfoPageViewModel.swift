//
//  TokensCardCollectionInfoPageViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 07.09.2021.
//

import UIKit
import BigInt

enum TokensCardCollectionInfoPageViewConfiguration {
    case field(viewModel: TokenInstanceAttributeViewModel)
    case header(viewModel: TokenInfoHeaderViewModel)
}

struct TokensCardCollectionInfoPageViewModel {
    var tabTitle: String {
        return R.string.localizable.tokenTabInfo()
    }

    private let tokenObject: TokenObject

    let server: RPCServer
    var contractAddress: AlphaWallet.Address {
        tokenObject.contractAddress
    }
    let tokenHolders: [TokenHolder]

    var tokenImagePlaceholder: UIImage? {
        return R.image.tokenPlaceholderLarge()
    }
    private let tokenHolderHelper: TokenInstanceViewConfigurationHelper

    var openInUrl: URL? {
        let values = tokenHolders[0].values
        return values.collectionValue.flatMap { collection -> URL? in
            guard collection.slug.trimmed.nonEmpty else { return nil }
            return URL(string: "https://opensea.io/collection/\(collection.slug)")
        }
    }

    var wikiUrl: URL? {
        tokenHolderHelper.wikiUrlViewModel?.value.flatMap {
            URL(string: $0)
        }
    }

    var instagramUrl: URL? {
        tokenHolderHelper.instagramUsernameViewModel?.value
            .flatMap { SocialNetworkUrlProvider.resolveUrl(for: $0, urlProvider: .instagram) }
    }

    var twitterUrl: URL? {
        tokenHolderHelper.twitterUsernameViewModel?.value
            .flatMap { SocialNetworkUrlProvider.resolveUrl(for: $0, urlProvider: .twitter) }
    }

    var discordUrl: URL? {
        tokenHolderHelper.discordUrlViewModel?.value
            .flatMap { SocialNetworkUrlProvider.resolveUrl(for: $0, urlProvider: .discord) }
    }

    var telegramUrl: URL? {
        tokenHolderHelper.telegramUrlViewModel?.value
            .flatMap { SocialNetworkUrlProvider.resolveUrl(for: $0, urlProvider: .telegram) }
    }

    var externalUrl: URL? {
        tokenHolderHelper.externalUrlViewModel?.value
            .flatMap { URL(string: $0) }
    }

    init(server: RPCServer, token: TokenObject, assetDefinitionStore: AssetDefinitionStore, eventsDataStore: NonActivityEventsDataStore, forWallet wallet: Wallet) {
        self.server = server
        self.tokenObject = token
        tokenHolders = TokenAdaptor(token: token, assetDefinitionStore: assetDefinitionStore, eventsDataStore: eventsDataStore).getTokenHolders(forWallet: wallet)
        let tokenHolder = tokenHolders[0]
        let tokenId = tokenHolder.tokenIds[0]

        self.tokenHolderHelper = TokenInstanceViewConfigurationHelper(tokenId: tokenId, tokenHolder: tokenHolder)
    }

    mutating func configure(overiddenOpenSeaStats: OpenSea.Stats?) {
        self.tokenHolderHelper.overiddenOpenSeaStats = overiddenOpenSeaStats
    }

    var backgroundColor: UIColor {
        return Screen.TokenCard.Color.background
    }

    var iconImage: Subscribable<TokenImage> {
        tokenObject.icon(withSize: .s750)
    }

    var blockChainTagViewModel: BlockchainTagLabelViewModel {
        .init(server: server)
    }

    var wikiUrlViewModel: TokenInstanceAttributeViewModel? {
        tokenHolderHelper.wikiUrlViewModel
    }

    var instagramUsernameViewModel: TokenInstanceAttributeViewModel? {
        tokenHolderHelper.instagramUsernameViewModel
    }

    var twitterUsernameViewModel: TokenInstanceAttributeViewModel? {
        tokenHolderHelper.twitterUsernameViewModel
    }

    var discordUrlViewModel: TokenInstanceAttributeViewModel? {
        tokenHolderHelper.discordUrlViewModel
    }

    var telegramUrlViewModel: TokenInstanceAttributeViewModel? {
        tokenHolderHelper.telegramUrlViewModel
    }

    var externalUrlViewModel: TokenInstanceAttributeViewModel? {
        tokenHolderHelper.externalUrlViewModel
    }

    var configurations: [TokensCardCollectionInfoPageViewConfiguration] {
        var configurations: [TokensCardCollectionInfoPageViewConfiguration] = []

        let detailsSectionViewModels = [
            tokenHolderHelper.createdDateViewModel,
            tokenHolderHelper.ownedAssetCountViewModel,
            tokenHolderHelper.itemsCount,
            tokenHolderHelper.totalVolume,
            tokenHolderHelper.totalSales,
            tokenHolderHelper.totalSupply,
            tokenHolderHelper.owners,
            tokenHolderHelper.averagePrice,
            tokenHolderHelper.marketCap,
            tokenHolderHelper.floorPrice,
            tokenHolderHelper.numReports,
        ].compactMap { viewModel -> TokensCardCollectionInfoPageViewConfiguration? in
            return viewModel.flatMap { .field(viewModel: $0) }
        }

        if detailsSectionViewModels.isEmpty {
            //no-op
        } else {
            configurations += [
                .header(viewModel: .init(title: R.string.localizable.semifungiblesDetails())),
            ] + detailsSectionViewModels
        }

        let descriptionSectionViewModels = [
            tokenHolderHelper.descriptionViewModel
        ].compactMap { viewModel -> TokensCardCollectionInfoPageViewConfiguration? in
            return viewModel.flatMap { .field(viewModel: $0) }
        }

        if descriptionSectionViewModels.isEmpty {
            //no-op
        } else {
            configurations += [
                .header(viewModel: .init(title: R.string.localizable.semifungiblesDescription())),
            ] + descriptionSectionViewModels
        }

        let linksSectionViewModels = [
            tokenHolderHelper.wikiUrlViewModel,
            tokenHolderHelper.instagramUsernameViewModel,
            tokenHolderHelper.twitterUsernameViewModel,
            tokenHolderHelper.discordUrlViewModel,
            tokenHolderHelper.telegramUrlViewModel,
            tokenHolderHelper.externalUrlViewModel
        ].compactMap { viewModel -> TokensCardCollectionInfoPageViewConfiguration? in
            return viewModel.flatMap { TokensCardCollectionInfoPageViewConfiguration.field(viewModel: $0) }
        }

        if linksSectionViewModels.isEmpty {
            //no-op
        } else {
            configurations += [
                .header(viewModel: .init(title: R.string.localizable.semifungiblesLinks())),
            ] + linksSectionViewModels
        }

        return configurations
    }
}
