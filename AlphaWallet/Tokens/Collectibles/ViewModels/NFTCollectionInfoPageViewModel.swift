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
    case field(viewModel: TokenAttributeViewModel)
    case header(viewModel: TokenInfoHeaderViewModel)
}

enum NFTPreviewViewType {
    case tokenCardView
    case imageView
}

extension NFTPreviewViewType {
    enum Params {
        case image(iconImage: Subscribable<TokenImage>)
        case tokenScriptWebView(tokenHolder: TokenHolder, tokenId: TokenId)
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
            return .tokenScriptWebView(tokenHolder: tokenHolder, tokenId: tokenId)
        case .imageView:
            return .image(iconImage: token.icon(withSize: .s750))
        }
    }

    var previewEdgeInsets: UIEdgeInsets {
        switch previewViewType {
        case .tokenCardView:
            return .init(top: 0, left: 8, bottom: 0, right: 8)
        case .imageView:
            return .init(top: 0, left: 15, bottom: 0, right: 15)
        }
    }

    var previewViewContentBackgroundColor: UIColor {
        return Colors.appBackground
    }

    init(token: TokenObject, assetDefinitionStore: AssetDefinitionStore, eventsDataStore: NonActivityEventsDataStore, wallet: Wallet) {
        self.assetDefinitionStore = assetDefinitionStore
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

    var blockChainTagViewModel: BlockchainTagLabelViewModel {
        .init(server: token.server)
    }

    var wikiUrlViewModel: TokenAttributeViewModel? {
        tokenHolderHelper.wikiUrlViewModel
    }

    var instagramUsernameViewModel: TokenAttributeViewModel? {
        tokenHolderHelper.instagramUsernameViewModel
    }

    var twitterUsernameViewModel: TokenAttributeViewModel? {
        tokenHolderHelper.twitterUsernameViewModel
    }

    var discordUrlViewModel: TokenAttributeViewModel? {
        tokenHolderHelper.discordUrlViewModel
    }

    var telegramUrlViewModel: TokenAttributeViewModel? {
        tokenHolderHelper.telegramUrlViewModel
    }

    var externalUrlViewModel: TokenAttributeViewModel? {
        tokenHolderHelper.externalUrlViewModel
    }

    var configurations: [NFTCollectionInfoPageViewConfiguration] {
        if Constants.ticketContractAddress.sameContract(as: token.contractAddress) {
            return generateFieldsConfigurationsForFifaToken()
        } else {
            return generateFieldsConfigurations()
        }
    }

    private func generateFieldsConfigurationsForFifaToken() -> [NFTCollectionInfoPageViewConfiguration] {
        let string = TokenAttributeViewModel.defaultValueAttributedString(R.string.localizable.semifungiblesEdconDescription(), alignment: .left)
        let descriptionViewModel = TokenAttributeViewModel(title: nil, attributedValue: string, value: string.string, isSeparatorHidden: true)

        return [
            .header(viewModel: .init(title: R.string.localizable.semifungiblesProjectInfo())),
            .field(viewModel: descriptionViewModel)
        ]
    }

    private func generateFieldsConfigurations() -> [NFTCollectionInfoPageViewConfiguration] {
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

    func urlForField(indexPath: IndexPath) -> URL? {
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
