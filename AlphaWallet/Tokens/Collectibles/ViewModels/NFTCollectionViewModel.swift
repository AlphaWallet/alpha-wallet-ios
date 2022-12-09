//
//  NFTCollectionViewModel.swift
//  Alpha-Wallet
//
//  Created by Oguzhan Gungor on 2/24/18.
//  Copyright © 2018 Alpha-Wallet. All rights reserved.
//

import Foundation
import BigInt
import Combine
import AlphaWalletFoundation

struct NFTCollectionViewModelInput {
    let appear: AnyPublisher<Void, Never>
    let pullToRefresh: AnyPublisher<Void, Never>
}

struct NFTCollectionViewModelOutput {
    let viewState: AnyPublisher<NFTCollectionViewModel.ViewState, Never>
    let activities: AnyPublisher<ActivityPageViewModel, Never>
    let pullToRefreshState: AnyPublisher<TokensViewModel.RefreshControlState, Never>
}

final class NFTCollectionViewModel {
    private var cancelable = Set<AnyCancellable>()
    private let assetDefinitionStore: AssetDefinitionStore
    private let tokensService: TokenViewModelState & TokenHolderState
    private let nftProvider: NFTProvider
    private (set) var openInUrl: URL?
    private (set) lazy var tokenScriptFileStatusHandler: XMLHandler = XMLHandler(token: token, assetDefinitionStore: assetDefinitionStore)
    
    let activitiesService: ActivitiesServiceType
    let tokenHolders: CurrentValueSubject<[TokenHolder], Never>
    let token: Token
    let initiallySelectedTabIndex: Int = 1
    let wallet: Wallet

    private var previewViewType: NFTPreviewViewType {
        switch OpenSeaBackedNonFungibleTokenHandling(token: token, assetDefinitionStore: assetDefinitionStore, tokenViewType: .viewIconified) {
        case .backedByOpenSea:
            return .imageView
        case .notBackedByOpenSea:
            return .tokenCardView
        }
    }

    private (set) lazy var infoPageViewModel: NFTCollectionInfoPageViewModel = {
        let tokenHolder = tokenHolders.value[0]
        let tokenId = tokenHolder.tokenIds[0]
        return NFTCollectionInfoPageViewModel(token: token, previewViewType: previewViewType, tokenHolder: tokenHolder, tokenId: tokenId, tokenHolders: tokenHolders.eraseToAnyPublisher(), nftProvider: nftProvider, assetDefinitionStore: assetDefinitionStore)
    }()

    private (set) lazy var nftAssetsPageViewModel = NFTAssetsPageViewModel(token: token, assetDefinitionStore: assetDefinitionStore, tokenHolders: tokenHolders.eraseToAnyPublisher(), layout: .list)

    init(token: Token, wallet: Wallet, assetDefinitionStore: AssetDefinitionStore, tokensService: TokenViewModelState & TokenHolderState, activitiesService: ActivitiesServiceType, nftProvider: NFTProvider) {
        self.activitiesService = activitiesService
        self.nftProvider = nftProvider
        self.tokensService = tokensService
        self.token = token
        self.wallet = wallet
        self.tokenHolders = .init(tokensService.tokenHolders(for: token))
        self.assetDefinitionStore = assetDefinitionStore
    } 
    
    func transform(input: NFTCollectionViewModelInput) -> NFTCollectionViewModelOutput {
        activitiesService.start()
        
        let tokenViewModel = tokensService.tokenViewModelPublisher(for: token)

        let beginLoading = input.pullToRefresh.map { _ in TokensViewModel.PullToRefreshState.beginLoading }
        let loadingHasEnded = beginLoading.delay(for: .seconds(2), scheduler: RunLoop.main)
            .map { _ in TokensViewModel.PullToRefreshState.endLoading }

        let fakePullToRefreshState = Just<TokensViewModel.PullToRefreshState>(TokensViewModel.PullToRefreshState.idle)
            .merge(with: beginLoading, loadingHasEnded)
            .compactMap { state -> TokensViewModel.RefreshControlState? in
                switch state {
                case .idle: return nil
                case .endLoading: return .endLoading
                case .beginLoading: return .beginLoading
                }
            }.eraseToAnyPublisher()

        let whenPullToRefresh = loadingHasEnded.map { [token] _ in token }
            .compactMap { [tokensService] in tokensService.tokenHolders(for: $0) }

        let whenViewModelHasChanged = tokenViewModel.dropFirst()
            .compactMap { [tokensService] in $0.flatMap { tokensService.tokenHolders(for: $0) } }

        Publishers.Merge(whenViewModelHasChanged, whenPullToRefresh)
            .assign(to: \.value, on: tokenHolders)
            .store(in: &cancelable)

        let actions = tokenHolders.compactMap { $0.first }
            .map {
                $0.values.collectionValue.flatMap { collection -> URL? in
                    guard collection.slug.trimmed.nonEmpty else { return nil }
                    return URL(string: "https://opensea.io/collection/\(collection.slug)")
                }
            }.handleEvents(receiveOutput: { [weak self] in self?.openInUrl = $0 })
            .map { $0 == nil ? [] : [NonFungibleTokenAction.openInUrl] }

        let title = tokenViewModel.compactMap { $0?.tokenScriptOverrides?.titleInPluralForm }

        let viewState = Publishers.CombineLatest3(title, tokenHolders, actions)
            .map { title, tokenHolders, actions in
                NFTCollectionViewModel.ViewState(title: title, actions: actions, tokenHolders: tokenHolders)
            }.eraseToAnyPublisher()

        let activities = activitiesService.activitiesPublisher
            .receive(on: RunLoop.main)
            .map { ActivityPageViewModel(activitiesViewModel: .init(collection: .init(activities: $0))) }
            .eraseToAnyPublisher()

        return .init(viewState: viewState, activities: activities, pullToRefreshState: fakePullToRefreshState)
    }

    var rightBarButtonItem: NFTCollectionViewModel.RightBarButtonItem {
        switch token.type {
        case .erc1155:
            switch wallet.type {
            case .real:
                return .assetSelection(isEnabled: true)
            case .watch:
                return .assetSelection(isEnabled: Config().development.shouldPretendIsRealWallet)
            }
        case .erc721, .erc721ForTickets, .erc875:
            return .assetsDisplayType(layout: nftAssetsPageViewModel.layout.inverted)
        case .erc20, .nativeCryptocurrency:
            return .none
        }
    }
}

extension NFTCollectionViewModel {
    struct ViewState {
        let title: String
        let actions: [NonFungibleTokenAction]
        let tokenHolders: [TokenHolder]
    }

    enum NonFungibleTokenAction {
        case openInUrl
    }

    enum RightBarButtonItem {
        case assetSelection(isEnabled: Bool)
        case assetsDisplayType(layout: GridOrListLayout)
        case none
    }
}
