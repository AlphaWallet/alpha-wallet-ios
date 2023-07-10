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
import AlphaWalletCore
import struct AlphaWalletTokenScript.Constants

struct NFTCollectionInfoPageViewModelInput {
    let selection: AnyPublisher<IndexPath, Never>
}

struct NFTCollectionInfoPageViewModelOutput {
    let viewState: AnyPublisher<NFTCollectionInfoPageViewModel.ViewState, Never>
    let attributeAction: AnyPublisher<NFTCollectionInfoPageViewModel.AttributeSelectionAction, Never>
}

final class NFTCollectionInfoPageViewModel {
    private var collectionDisplayHelper: NftCollectionDisplayHelper?
    private var viewTypes: [NFTCollectionInfoPageViewModel.ViewType] = []
    private let tokenHolder: AnyPublisher<TokenHolder?, Never>
    private let nftProvider: NFTProvider
    private let assetDefinitionStore: AssetDefinitionStore
    private let tokenImageFetcher: TokenImageFetcher

    var tabTitle: String { return R.string.localizable.tokenTabInfo() }
    let token: Token
    var contractAddress: AlphaWallet.Address { token.contractAddress }
    var tokenImagePlaceholder: UIImage? { return R.image.tokenPlaceholderLarge() }
    let previewViewType: NFTPreviewViewType

    var previewEdgeInsets: UIEdgeInsets {
        switch previewViewType {
        case .tokenCardView:
            return .init(top: 0, left: 8, bottom: 0, right: 8)
        case .imageView:
            return .init(top: 0, left: 15, bottom: 0, right: 15)
        }
    }

    var previewViewContentBackgroundColor: UIColor { return Configuration.Color.Semantic.defaultViewBackground }
    private let contractViewModel: TokenAttributeViewModel

    init(token: Token,
         previewViewType: NFTPreviewViewType,
         tokenHolder: AnyPublisher<TokenHolder?, Never>,
         nftProvider: NFTProvider,
         assetDefinitionStore: AssetDefinitionStore,
         tokenImageFetcher: TokenImageFetcher) {

        self.tokenImageFetcher = tokenImageFetcher
        self.previewViewType = previewViewType
        self.nftProvider = nftProvider
        self.tokenHolder = tokenHolder
        self.token = token
        self.assetDefinitionStore = assetDefinitionStore

        self.contractViewModel = TokenAttributeViewModel(
            title: R.string.localizable.nonfungiblesValueContract(),
            attributedValue: TokenAttributeViewModel.urlValueAttributedString(token.contractAddress.truncateMiddle))
    }

    func transform(input: NFTCollectionInfoPageViewModelInput) -> NFTCollectionInfoPageViewModelOutput {
        let helper = buildViewHelper(for: tokenHolder)

        let viewState = Publishers.CombineLatest(previewViewParams(for: helper), viewTypes(for: helper))
            .map { [previewViewContentBackgroundColor] params, viewTypes in
                ViewState(
                    previewViewParams: params,
                    previewViewContentBackgroundColor: previewViewContentBackgroundColor,
                    viewTypes: viewTypes)
            }

        let attributeAction = input.selection
            .compactMap { self.buildSelectionAction(indexPath: $0) }

        return .init(
            viewState: viewState.eraseToAnyPublisher(),
            attributeAction: attributeAction.eraseToAnyPublisher())
    }

    private func loadCollectionStats(for tokenHolder: AnyPublisher<TokenHolder?, Never>) -> AnyPublisher<Loadable<Stats, PromiseError>, Never> {
        return tokenHolder
            .flatMapLatest { [nftProvider] tokenHolder -> AnyPublisher<Loadable<Stats, PromiseError>, Never> in
                if let collectionId = tokenHolder?.values.collectionId, collectionId.trimmed.nonEmpty {
                    return nftProvider.collectionStats(collectionId: collectionId)
                        .map { stats -> Loadable<Stats, PromiseError> in .done(stats) }
                        .catch { return Just(.failure($0)) }
                        .eraseToAnyPublisher()
                } else {
                    struct OpenSeaCollectionStatsNotFoundError: Error {}
                    return .just(.failure(PromiseError(error: OpenSeaCollectionStatsNotFoundError())))
                }
            }.prepend(.loading)
            .eraseToAnyPublisher()
    }

    private func previewViewParams(for helper: AnyPublisher<NftCollectionDisplayHelper?, Never>) -> AnyPublisher<NFTPreviewViewType.Params, Never> {
        helper.map { [token, previewViewType, tokenImageFetcher] helper in
            guard let helper = helper else { return .image(iconImage: .just(nil)) }

            switch previewViewType {
            case .tokenCardView:
                return .tokenScriptWebView(tokenHolder: helper.tokenHolder, tokenId: helper.tokenId)
            case .imageView:
                let iconImage = tokenImageFetcher.image(token: token, size: .s750)
                return .image(iconImage: iconImage )
            }
        }.eraseToAnyPublisher()
    }

    private func viewTypes(for helper: AnyPublisher<NftCollectionDisplayHelper?, Never>) -> AnyPublisher<[NFTCollectionInfoPageViewModel.ViewType], Never> {
        helper.map { [weak self] helper in
            guard let strongSelf = self, let helper = helper else { return [] }
            return strongSelf.buildViewTypes(helper: helper)
        }.handleEvents(receiveOutput: { [weak self] in self?.viewTypes = $0 })
        .eraseToAnyPublisher()
    }

    private func buildViewHelper(for tokenHolder: AnyPublisher<TokenHolder?, Never>) -> AnyPublisher<NftCollectionDisplayHelper?, Never> {
        //TODO: move loadCollectionStats to other place, looks not correctly here, but good for now.
        return Publishers.CombineLatest(loadCollectionStats(for: tokenHolder), tokenHolder)
            .map { [assetDefinitionStore] stats, tokenHolder -> NftCollectionDisplayHelper? in
                guard let tokenHolder = tokenHolder, let tokenId = tokenHolder.tokens.first?.id else {
                    return nil
                }
                //TODO: add support of loadable fields, make tokenHolderHelpers fields depended from open sea stats loadable to display loading process, for better ux
                let helper = NftCollectionDisplayHelper(tokenId: tokenId, tokenHolder: tokenHolder, assetDefinitionStore: assetDefinitionStore)
                switch stats {
                case .done(let stats):
                    helper.overiddenOpenSeaStats = stats
                case .loading, .failure:
                    helper.overiddenOpenSeaStats = nil
                }

                return helper
            }.handleEvents(receiveOutput: { [weak self] in self?.collectionDisplayHelper = $0 })
            .share(replay: 1)
            .eraseToAnyPublisher()
    }

    private func buildSelectionAction(indexPath: IndexPath) -> AttributeSelectionAction? {
        switch viewTypes[indexPath.row] {
        case .field(let vm) where collectionDisplayHelper?.wikiUrlViewModel == vm:
            return collectionDisplayHelper?.wikiUrlViewModel?.value
                .flatMap { URL(string: $0) }
                .flatMap { AttributeSelectionAction.openUrl($0) }
        case .field(let vm) where collectionDisplayHelper?.instagramUsernameViewModel == vm:
            return collectionDisplayHelper?.instagramUsernameViewModel?.value
                .flatMap { SocialNetworkUrlProvider.resolveUrl(for: $0, urlProvider: .instagram) }
                .flatMap { AttributeSelectionAction.openUrl($0) }
        case .field(let vm) where collectionDisplayHelper?.twitterUsernameViewModel == vm:
            return collectionDisplayHelper?.twitterUsernameViewModel?.value
                .flatMap { SocialNetworkUrlProvider.resolveUrl(for: $0, urlProvider: .twitter) }
                .flatMap { AttributeSelectionAction.openUrl($0) }
        case .field(let vm) where collectionDisplayHelper?.discordUrlViewModel == vm:
            return collectionDisplayHelper?.discordUrlViewModel?.value
                .flatMap { SocialNetworkUrlProvider.resolveUrl(for: $0, urlProvider: .discord) }
                .flatMap { AttributeSelectionAction.openUrl($0) }
        case .field(let vm) where collectionDisplayHelper?.telegramUrlViewModel == vm:
            return collectionDisplayHelper?.telegramUrlViewModel?.value
                .flatMap { SocialNetworkUrlProvider.resolveUrl(for: $0, urlProvider: .telegram) }
                .flatMap { AttributeSelectionAction.openUrl($0) }
        case .field(let vm) where collectionDisplayHelper?.externalUrlViewModel == vm:
            return collectionDisplayHelper?.externalUrlViewModel?.value
                .flatMap { URL(string: $0) }
                .flatMap { AttributeSelectionAction.openUrl($0) }
        case .field(let vm) where contractViewModel == vm:
            return ConfigExplorer(server: token.server).contractUrl(address: token.contractAddress)
                .flatMap { AttributeSelectionAction.openUrl($0.url) }
        case .header, .field:
            return nil
        }
    }

    private func buildViewTypes(helper collectionDisplayHelper: NftCollectionDisplayHelper) -> [NFTCollectionInfoPageViewModel.ViewType] {
        if Constants.ticketContractAddress == token.contractAddress {
            return buildViewTypesForFifaToken()
        } else {
            return buildDefaultViewTypes(collectionDisplayHelper: collectionDisplayHelper)
        }
    }

    private func buildViewTypesForFifaToken() -> [NFTCollectionInfoPageViewModel.ViewType] {
        let string = TokenAttributeViewModel.defaultValueAttributedString(R.string.localizable.semifungiblesEdconDescription(), alignment: .left)
        let descriptionViewModel = TokenAttributeViewModel(title: nil, attributedValue: string, value: string.string, isSeparatorHidden: true)

        return [
            .header(viewModel: .init(title: R.string.localizable.semifungiblesProjectInfo())),
            .field(viewModel: descriptionViewModel)
        ]
    }

    private func buildDefaultViewTypes(collectionDisplayHelper: NftCollectionDisplayHelper) -> [NFTCollectionInfoPageViewModel.ViewType] {
        var configurations: [NFTCollectionInfoPageViewModel.ViewType] = []

        let detailsSectionViewModels = [
            contractViewModel,
            TokenAttributeViewModel(title: R.string.localizable.nonfungiblesValueBlockchain(), attributedValue: TokenAttributeViewModel.defaultValueAttributedString(token.server.blockChainName)),
            TokenAttributeViewModel(title: R.string.localizable.nonfungiblesValueTokenStandard(), attributedValue: TokenAttributeViewModel.defaultValueAttributedString(token.type.rawValue)),
            collectionDisplayHelper.createdDateViewModel,
            collectionDisplayHelper.ownedAssetCountViewModel,
            collectionDisplayHelper.itemsCount,
            collectionDisplayHelper.totalVolume,
            collectionDisplayHelper.totalSales,
            collectionDisplayHelper.totalSupply,
            collectionDisplayHelper.owners,
            collectionDisplayHelper.averagePrice,
            collectionDisplayHelper.marketCap,
            collectionDisplayHelper.floorPrice,
            collectionDisplayHelper.numReports,
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
            collectionDisplayHelper.descriptionViewModel
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
            collectionDisplayHelper.wikiUrlViewModel,
            collectionDisplayHelper.instagramUsernameViewModel,
            collectionDisplayHelper.twitterUsernameViewModel,
            collectionDisplayHelper.discordUrlViewModel,
            collectionDisplayHelper.telegramUrlViewModel,
            collectionDisplayHelper.externalUrlViewModel
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
}

extension NFTCollectionInfoPageViewModel {
    enum AttributeSelectionAction {
        case openUrl(URL)
    }

    enum ViewType {
        case field(viewModel: TokenAttributeViewModel)
        case header(viewModel: TokenInfoHeaderViewModel)
    }

    struct ViewState {
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
