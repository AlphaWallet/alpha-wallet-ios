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
    let pullToRefreshState: AnyPublisher<TokensViewModel.PullToRefreshState, Never>
}

final class NFTCollectionViewModel {
    private var cancelable = Set<AnyCancellable>()
    private let assetDefinitionStore: AssetDefinitionStore
    private let tokensService: TokenViewModelState & TokenHolderState
    private let openSea: OpenSea
    private (set) var openInUrl: URL?
    private (set) lazy var tokenScriptFileStatusHandler: XMLHandler = XMLHandler(token: token, assetDefinitionStore: assetDefinitionStore)
    
    let activitiesService: ActivitiesServiceType
    let tokenHolders: CurrentValueSubject<[TokenHolder], Never>
    let token: Token
    let initiallySelectedTabIndex: Int = 1
    let backgroundColor: UIColor = Colors.appBackground
    let wallet: Wallet

    private (set) lazy var infoPageViewModel = NFTCollectionInfoPageViewModel(token: token, assetDefinitionStore: assetDefinitionStore, tokenHolders: tokenHolders.value, wallet: wallet, _tokenHolders: tokenHolders.eraseToAnyPublisher(), openSea: openSea)
    private (set) lazy var nftAssetsPageViewModel = NFTAssetsPageViewModel(token: token, assetDefinitionStore: assetDefinitionStore, tokenHolders: tokenHolders.eraseToAnyPublisher(), selection: .list)

    init(token: Token, wallet: Wallet, assetDefinitionStore: AssetDefinitionStore, tokensService: TokenViewModelState & TokenHolderState, activitiesService: ActivitiesServiceType, openSea: OpenSea) {
        self.activitiesService = activitiesService
        self.openSea = openSea
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
            .eraseToAnyPublisher()

        let whenPullToRefresh = loadingHasEnded.map { [token] _ in token }
            .compactMap { [tokensService] in tokensService.tokenHolders(for: $0) }

        let whenViewModelHasChanged = tokenViewModel.dropFirst().compactMap { [tokensService] in $0.flatMap { tokensService.tokenHolders(for: $0) } }

        Publishers.Merge(whenViewModelHasChanged, whenPullToRefresh)
            .assign(to: \.value, on: tokenHolders)
            .store(in: &cancelable)

        let actions = tokenHolders.compactMap { $0.first }
            .map {
                return $0.values.collectionValue.flatMap { collection -> URL? in
                    guard collection.slug.trimmed.nonEmpty else { return nil }
                    return URL(string: "https://opensea.io/collection/\(collection.slug)")
                }
            }.handleEvents(receiveOutput: { [weak self] in self?.openInUrl = $0 })
            .map { $0 == nil ? [] : [NonFungibleTokenAction.openInUrl] }

        let navigationTitle = tokenViewModel.compactMap { $0?.tokenScriptOverrides?.titleInPluralForm }

        let viewState = Publishers.CombineLatest3(navigationTitle, tokenHolders, actions)
            .map { navigationTitle, tokenHolders, actions in
                NFTCollectionViewModel.ViewState(navigationTitle: navigationTitle, actions: actions, tokenHolders: tokenHolders)
            }

        let activities = activitiesService.activitiesPublisher
            .receive(on: RunLoop.main)
            .map { ActivityPageViewModel(activitiesViewModel: .init(collection: .init(activities: $0))) }
            .eraseToAnyPublisher()

        return .init(viewState: viewState.eraseToAnyPublisher(), activities: activities, pullToRefreshState: fakePullToRefreshState)
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
            return .assetsDisplayType(selection: nftAssetsPageViewModel.selection.inverted)
        case .erc20, .nativeCryptocurrency:
            return .none
        }
    }
}

extension NFTCollectionViewModel {
    struct ViewState {
        let navigationTitle: String
        let actions: [NonFungibleTokenAction]
        let tokenHolders: [TokenHolder]
    }

    enum NonFungibleTokenAction {
        case openInUrl
    }

    enum RightBarButtonItem {
        case assetSelection(isEnabled: Bool)
        case assetsDisplayType(selection: GridOrListSelectionState)
        case none
    }
}
