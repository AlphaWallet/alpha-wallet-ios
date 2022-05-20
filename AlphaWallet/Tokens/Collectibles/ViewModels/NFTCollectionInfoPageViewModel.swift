//
//  NFTCollectionInfoPageViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 07.09.2021.
//

import UIKit
import BigInt
import AlphaWalletOpenSea

enum NFTCollectionInfoPageViewConfiguration {
    case field(viewModel: TokenInstanceAttributeViewModel)
    case header(viewModel: TokenInfoHeaderViewModel)
}

enum NFTPreviewViewType {
    case tokenCardView
    case imageView
}

extension NFTPreviewViewType {
    enum Params {
        case image(iconImage: Subscribable<TokenImage>)
        case some(tokenHolder: TokenHolder, tokenId: TokenId, tokenView: TokenView, assetDefinitionStore: AssetDefinitionStore)
    }
}

protocol ConfigurableNFTPreviewView {
    func configure(params: NFTPreviewViewType.Params)
}

struct NFTCollectionInfoPageViewModel {
    private let tokenHolderHelper: TokenInstanceViewConfigurationHelper
    private let assetDefinitionStore: AssetDefinitionStore

    var tabTitle: String {
        return R.string.localizable.tokenTabInfo()
    }

    let token: TokenObject
    let server: RPCServer
    var contractAddress: AlphaWallet.Address {
        token.contractAddress
    }
    let tokenHolders: [TokenHolder]

    var tokenImagePlaceholder: UIImage? {
        return R.image.tokenPlaceholderLarge()
    }

    var wikiUrl: URL? {
        tokenHolderHelper.wikiUrlViewModel?.value
            .flatMap { URL(string: $0) }
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
    
    let tokenHolder: TokenHolder
    let tokenId: TokenId

    var previewViewType: NFTPreviewViewType {
        switch OpenSeaBackedNonFungibleTokenHandling(token: token, assetDefinitionStore: assetDefinitionStore, tokenViewType: .viewIconified) {
        case .backedByOpenSea:
            return .imageView
        case .notBackedByOpenSea:
            return .tokenCardView
        }
    }

    var previewViewParams: NFTPreviewViewType.Params {
        switch previewViewType {
        case .tokenCardView:
            return .some(tokenHolder: tokenHolder, tokenId: tokenId, tokenView: .viewIconified, assetDefinitionStore: assetDefinitionStore)
        case .imageView:
            return .image(iconImage: token.icon(withSize: .s750))
        }
    }

    var previewEdgeInsets: UIEdgeInsets {
        return .init(top: 0, left: 8, bottom: 0, right: 8)
    }

    init(server: RPCServer, token: TokenObject, assetDefinitionStore: AssetDefinitionStore, eventsDataStore: NonActivityEventsDataStore, forWallet wallet: Wallet) {
        self.assetDefinitionStore = assetDefinitionStore
        self.server = server
        self.token = token
        tokenHolders = token.getTokenHolders(assetDefinitionStore: assetDefinitionStore, eventsDataStore: eventsDataStore, forWallet: wallet)
        tokenHolder = tokenHolders[0]
        tokenId = tokenHolder.tokenIds[0]

        self.tokenHolderHelper = TokenInstanceViewConfigurationHelper(tokenId: tokenId, tokenHolder: tokenHolder)
    }

    mutating func configure(overiddenOpenSeaStats: Stats?) {
        self.tokenHolderHelper.overiddenOpenSeaStats = overiddenOpenSeaStats
    }

    var backgroundColor: UIColor {
        return Screen.TokenCard.Color.background
    }

    var iconImage: Subscribable<TokenImage> {
        token.icon(withSize: .s750)
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

    var configurations: [NFTCollectionInfoPageViewConfiguration] {
        if Constants.ticketContractAddress.sameContract(as: token.contractAddress) {
            return some_2()
        } else {
            return some()
        }
    }

    private func some_2() -> [NFTCollectionInfoPageViewConfiguration] {
        let s = TokenInstanceAttributeViewModel.defaultValueAttributedString("Edcon is a game centered around breedable, collectible, and adorable creatures where digital pandas live in the blockchain! Each panda comes from descendants of 50 giant pandas that have been officially licensed by China Panda Conservation and Research Center.", alignment: .left)
        let descriptionViewModel = TokenInstanceAttributeViewModel(title: nil, attributedValue: s, value: s.string, isSeparatorHidden: true)

        return [
            .header(viewModel: .init(title: "Project Info")),
            .field(viewModel: descriptionViewModel)
        ]
    }

    private func some() -> [NFTCollectionInfoPageViewConfiguration] {
        var configurations: [NFTCollectionInfoPageViewConfiguration] = []

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
        ].compactMap { viewModel -> NFTCollectionInfoPageViewConfiguration? in
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
        ].compactMap { viewModel -> NFTCollectionInfoPageViewConfiguration? in
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
        ].compactMap { viewModel -> NFTCollectionInfoPageViewConfiguration? in
            return viewModel.flatMap { NFTCollectionInfoPageViewConfiguration.field(viewModel: $0) }
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

    func someUrlFor(indexPath: IndexPath) -> URL? {
        switch configurations[indexPath.row] {
        case .field(let vm) where wikiUrlViewModel == vm:
            return wikiUrl
        case .field(let vm) where instagramUsernameViewModel == vm:
            return instagramUrl
        case .field(let vm) where twitterUsernameViewModel == vm:
            return twitterUrl
        case .field(let vm) where discordUrlViewModel == vm:
            return discordUrl
        case .field(let vm) where telegramUrlViewModel == vm:
            return telegramUrl
        case .field(let vm) where externalUrlViewModel == vm:
            return externalUrl
        case .header, .field:
            return .none
        }
    }
}
