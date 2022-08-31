//
//  NFTCollectionInfoPageViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 07.09.2021.
//

import UIKit
import BigInt
import Combine
import AlphaWalletFoundation

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

struct NFTCollectionInfoPageViewModelInput {
}

struct NFTCollectionInfoPageViewModelOutput {
    let viewState: AnyPublisher<NFTCollectionInfoPageViewModel.ViewState, Never>
}

final class NFTCollectionInfoPageViewModel {
    private var tokenHolderHelper: TokenInstanceViewConfigurationHelper
    private let assetDefinitionStore: AssetDefinitionStore
    private var viewTypes: [NFTCollectionInfoPageViewModel.ViewType] = []
    private let _tokenHolders: AnyPublisher<[TokenHolder], Never>
    private let openSea: OpenSea
    
    var tabTitle: String { return R.string.localizable.tokenTabInfo() }
    let token: Token
    var contractAddress: AlphaWallet.Address { token.contractAddress }
    var tokenImagePlaceholder: UIImage? { return R.image.tokenPlaceholderLarge() }
    var tokenHolder: TokenHolder
    var tokenId: TokenId

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

    var previewViewContentBackgroundColor: UIColor { return Colors.appBackground }

    init(token: Token, assetDefinitionStore: AssetDefinitionStore, tokenHolders: [TokenHolder], wallet: Wallet, _tokenHolders: AnyPublisher<[TokenHolder], Never>, openSea: OpenSea) {
        self.openSea = openSea
        self._tokenHolders = _tokenHolders
        self.assetDefinitionStore = assetDefinitionStore
        self.token = token

        tokenHolder = tokenHolders[0]
        tokenId = tokenHolder.tokenIds[0]

        self.tokenHolderHelper = TokenInstanceViewConfigurationHelper(tokenId: tokenId, tokenHolder: tokenHolder)
    }

    var backgroundColor: UIColor {
        return Screen.TokenCard.Color.background
    } 

    var blockChainTagViewModel: BlockchainTagLabelViewModel {
        .init(server: token.server)
    }

    func transform(input: NFTCollectionInfoPageViewModelInput) -> NFTCollectionInfoPageViewModelOutput {
        let whenOpenSeaStatsHasChanged = PassthroughSubject<Void, Never>()

        if let openSeaSlug = tokenHolder.values.slug, openSeaSlug.trimmed.nonEmpty {
            openSea.collectionStats(slug: openSeaSlug, server: token.server).done { [tokenHolderHelper] overiddenOpenSeaStats in
                tokenHolderHelper.overiddenOpenSeaStats = overiddenOpenSeaStats
                whenOpenSeaStatsHasChanged.send(())
            }.cauterize()
        }

        let tokenHolder = _tokenHolders.compactMap { $0.first }

        let whenTokehHolderHasChanged = tokenHolder.map { tokenHolder -> (tokenHolder: TokenHolder, tokenId: TokenId) in
            return (tokenHolder: tokenHolder, tokenId: tokenHolder.tokenId)
        }.handleEvents(receiveOutput: { [weak self, tokenHolderHelper] in
            self?.tokenId = $0.tokenId
            self?.tokenHolder = $0.tokenHolder
            tokenHolderHelper.update(tokenHolder: $0.tokenHolder, tokenId: $0.tokenId)
        }).map { _ in }

        let viewTypes = Publishers.Merge(whenTokehHolderHasChanged, whenOpenSeaStatsHasChanged)
            .compactMap { [tokenHolderHelper, weak self] _ in self?.buildViewTypes(helper: tokenHolderHelper) }
            .handleEvents(receiveOutput: { [weak self] in self?.viewTypes = $0 })

        let viewState = viewTypes.map {
            NFTCollectionInfoPageViewModel.ViewState(previewViewType: self.previewViewType, previewViewParams: self.previewViewParams, previewViewContentBackgroundColor: self.previewViewContentBackgroundColor, viewTypes: $0)
        }

        return .init(viewState: viewState.eraseToAnyPublisher())
    }

    private func buildViewTypes(helper tokenHolderHelper: TokenInstanceViewConfigurationHelper) -> [NFTCollectionInfoPageViewModel.ViewType] {
        if Constants.ticketContractAddress.sameContract(as: token.contractAddress) {
            return buildViewTypesForFifaToken(helper: tokenHolderHelper)
        } else {
            return buildDefaultViewTypes(helper: tokenHolderHelper)
        }
    }

    private func buildViewTypesForFifaToken(helper tokenHolderHelper: TokenInstanceViewConfigurationHelper) -> [NFTCollectionInfoPageViewModel.ViewType] {
        let string = TokenAttributeViewModel.defaultValueAttributedString(R.string.localizable.semifungiblesEdconDescription(), alignment: .left)
        let descriptionViewModel = TokenAttributeViewModel(title: nil, attributedValue: string, value: string.string, isSeparatorHidden: true)

        return [
            .header(viewModel: .init(title: R.string.localizable.semifungiblesProjectInfo())),
            .field(viewModel: descriptionViewModel)
        ]
    }

    private func buildDefaultViewTypes(helper tokenHolderHelper: TokenInstanceViewConfigurationHelper) -> [NFTCollectionInfoPageViewModel.ViewType] {
        var configurations: [NFTCollectionInfoPageViewModel.ViewType] = []

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
        ].compactMap { viewModel -> NFTCollectionInfoPageViewModel.ViewType? in
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
        ].compactMap { viewModel -> NFTCollectionInfoPageViewModel.ViewType? in
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
        ].compactMap { viewModel -> NFTCollectionInfoPageViewModel.ViewType? in
            return viewModel.flatMap { NFTCollectionInfoPageViewModel.ViewType.field(viewModel: $0) }
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
        switch viewTypes[indexPath.row] {
        case .field(let vm) where tokenHolderHelper.wikiUrlViewModel == vm:
            return tokenHolderHelper.wikiUrlViewModel?.value.flatMap { URL(string: $0) }
        case .field(let vm) where tokenHolderHelper.instagramUsernameViewModel == vm:
            return tokenHolderHelper.instagramUsernameViewModel?.value.flatMap { SocialNetworkUrlProvider.resolveUrl(for: $0, urlProvider: .instagram) }
        case .field(let vm) where tokenHolderHelper.twitterUsernameViewModel == vm:
            return tokenHolderHelper.twitterUsernameViewModel?.value.flatMap { SocialNetworkUrlProvider.resolveUrl(for: $0, urlProvider: .twitter) }
        case .field(let vm) where tokenHolderHelper.discordUrlViewModel == vm:
            return tokenHolderHelper.discordUrlViewModel?.value.flatMap { SocialNetworkUrlProvider.resolveUrl(for: $0, urlProvider: .discord) }
        case .field(let vm) where tokenHolderHelper.telegramUrlViewModel == vm:
            return tokenHolderHelper.telegramUrlViewModel?.value.flatMap { SocialNetworkUrlProvider.resolveUrl(for: $0, urlProvider: .telegram) }
        case .field(let vm) where tokenHolderHelper.externalUrlViewModel == vm:
            return tokenHolderHelper.externalUrlViewModel?.value.flatMap { URL(string: $0) }
        case .header, .field:
            return .none
        }
    }
}

extension NFTCollectionInfoPageViewModel {
    enum ViewType {
        case field(viewModel: TokenAttributeViewModel)
        case header(viewModel: TokenInfoHeaderViewModel)
    }

    struct ViewState {
        let previewViewType: NFTPreviewViewType
        let previewViewParams: NFTPreviewViewType.Params
        let previewViewContentBackgroundColor: UIColor
        let viewTypes: [NFTCollectionInfoPageViewModel.ViewType]
    }
}

extension SocialNetworkUrlProvider {
    static func resolveUrl(for user: String, urlProvider: SocialNetworkUrlProvider) -> URL? {
        if let url = URL(string: user), user.isValidURL {
            return url
        }

        guard let deepLink = urlProvider.deepLinkURL(user: user), UIApplication.shared.canOpenURL(deepLink) else {
            if let url = urlProvider.remoteURL(user: user) {
                return url
            } else {
                return URL(string: user)
            }
        }
        return deepLink
    }
}
