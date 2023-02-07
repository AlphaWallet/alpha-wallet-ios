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

struct NFTCollectionInfoPageViewModelInput {
}

struct NFTCollectionInfoPageViewModelOutput {
    let viewState: AnyPublisher<NFTCollectionInfoPageViewModel.ViewState, Never>
}

final class NFTCollectionInfoPageViewModel {
    private var tokenHolderHelper: TokenInstanceViewConfigurationHelper?
    private var viewTypes: [NFTCollectionInfoPageViewModel.ViewType] = []
    private let tokenHolder: AnyPublisher<TokenHolder?, Never>
    private let nftProvider: NFTProvider
    private let assetDefinitionStore: AssetDefinitionStore

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

    init(token: Token,
         previewViewType: NFTPreviewViewType,
         tokenHolder: AnyPublisher<TokenHolder?, Never>,
         nftProvider: NFTProvider,
         assetDefinitionStore: AssetDefinitionStore) {

        self.previewViewType = previewViewType
        self.nftProvider = nftProvider
        self.tokenHolder = tokenHolder
        self.token = token
        self.assetDefinitionStore = assetDefinitionStore
    }

    var blockChainTagViewModel: BlockchainTagLabelViewModel {
        .init(server: token.server)
    }

    func transform(input: NFTCollectionInfoPageViewModelInput) -> NFTCollectionInfoPageViewModelOutput {
        let helper = buildViewHelper(for: tokenHolder)

        let viewState = Publishers.CombineLatest(previewViewParams(for: helper), viewTypes(for: helper))
            .map { [previewViewContentBackgroundColor] params, viewTypes in
                ViewState(
                    previewViewParams: params,
                    previewViewContentBackgroundColor: previewViewContentBackgroundColor,
                    viewTypes: viewTypes)
            }.eraseToAnyPublisher()

        return .init(viewState: viewState)
    }

    private func loadCollectionStats(for tokenHolder: AnyPublisher<TokenHolder?, Never>) -> AnyPublisher<Loadable<Stats, PromiseError>, Never> {
        return tokenHolder
            .flatMapLatest { [nftProvider, token] tokenHolder -> AnyPublisher<Loadable<Stats, PromiseError>, Never> in
                if let openSeaSlug = tokenHolder?.values.slug, openSeaSlug.trimmed.nonEmpty {
                    return nftProvider.collectionStats(slug: openSeaSlug, server: token.server)
                        .publisher()
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

    private func previewViewParams(for helper: AnyPublisher<TokenInstanceViewConfigurationHelper?, Never>) -> AnyPublisher<NFTPreviewViewType.Params, Never> {
        helper.map { [token, previewViewType] helper in
            guard let helper = helper else { return .image(iconImage: .init(nil)) }

            switch previewViewType {
            case .tokenCardView:
                return .tokenScriptWebView(tokenHolder: helper.tokenHolder, tokenId: helper.tokenId)
            case .imageView:
                return .image(iconImage: token.icon(withSize: .s750))
            }
        }.eraseToAnyPublisher()
    }

    private func viewTypes(for helper: AnyPublisher<TokenInstanceViewConfigurationHelper?, Never>) -> AnyPublisher<[NFTCollectionInfoPageViewModel.ViewType], Never> {
        helper.map { [weak self] helper in
            guard let strongSelf = self, let helper = helper else { return [] }
            return strongSelf.buildViewTypes(helper: helper)
        }.handleEvents(receiveOutput: { [weak self] in self?.viewTypes = $0 })
        .eraseToAnyPublisher()
    }

    private func buildViewHelper(for tokenHolder: AnyPublisher<TokenHolder?, Never>) -> AnyPublisher<TokenInstanceViewConfigurationHelper?, Never> {
        //TODO: move loadCollectionStats to other place, looks not correctly here, but good for now.
        return Publishers.CombineLatest(loadCollectionStats(for: tokenHolder), tokenHolder)
            .map { [assetDefinitionStore] stats, tokenHolder -> TokenInstanceViewConfigurationHelper? in
                guard let tokenHolder = tokenHolder, let tokenId = tokenHolder.tokens.first?.id else {
                    return nil
                }
                //TODO: add support of loadable fields, make tokenHolderHelpers fields depended from open sea stats loadable to display loading process, for better ux
                let helper = TokenInstanceViewConfigurationHelper(tokenId: tokenId, tokenHolder: tokenHolder, assetDefinitionStore: assetDefinitionStore)
                switch stats {
                case .done(let stats):
                    helper.overiddenOpenSeaStats = stats
                case .loading, .failure:
                    helper.overiddenOpenSeaStats = nil
                }

                return helper
            }.handleEvents(receiveOutput: { [weak self] in self?.tokenHolderHelper = $0 })
            .share(replay: 1)
            .eraseToAnyPublisher()
    }

    private func buildViewTypes(helper tokenHolderHelper: TokenInstanceViewConfigurationHelper) -> [NFTCollectionInfoPageViewModel.ViewType] {
        if Constants.ticketContractAddress == token.contractAddress {
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
        case .field(let vm) where tokenHolderHelper?.wikiUrlViewModel == vm:
            return tokenHolderHelper?.wikiUrlViewModel?.value.flatMap { URL(string: $0) }
        case .field(let vm) where tokenHolderHelper?.instagramUsernameViewModel == vm:
            return tokenHolderHelper?.instagramUsernameViewModel?.value.flatMap { SocialNetworkUrlProvider.resolveUrl(for: $0, urlProvider: .instagram) }
        case .field(let vm) where tokenHolderHelper?.twitterUsernameViewModel == vm:
            return tokenHolderHelper?.twitterUsernameViewModel?.value.flatMap { SocialNetworkUrlProvider.resolveUrl(for: $0, urlProvider: .twitter) }
        case .field(let vm) where tokenHolderHelper?.discordUrlViewModel == vm:
            return tokenHolderHelper?.discordUrlViewModel?.value.flatMap { SocialNetworkUrlProvider.resolveUrl(for: $0, urlProvider: .discord) }
        case .field(let vm) where tokenHolderHelper?.telegramUrlViewModel == vm:
            return tokenHolderHelper?.telegramUrlViewModel?.value.flatMap { SocialNetworkUrlProvider.resolveUrl(for: $0, urlProvider: .telegram) }
        case .field(let vm) where tokenHolderHelper?.externalUrlViewModel == vm:
            return tokenHolderHelper?.externalUrlViewModel?.value.flatMap { URL(string: $0) }
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
