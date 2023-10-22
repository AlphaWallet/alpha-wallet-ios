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
import AlphaWalletTokenScript

struct NFTCollectionViewModelInput {
    let willAppear: AnyPublisher<Void, Never>
    let pullToRefresh: AnyPublisher<Void, Never>
}

struct NFTCollectionViewModelOutput {
    let viewState: AnyPublisher<NFTCollectionViewModel.ViewState, Never>
    let activities: AnyPublisher<ActivityPageViewModel, Never>
    let pullToRefreshState: AnyPublisher<Loadable<Void, Error>, Never>
}

final class NFTCollectionViewModel {
    private var cancelable = Set<AnyCancellable>()
    private let assetDefinitionStore: AssetDefinitionStore
    private let tokensService: TokensProcessingPipeline
    private let nftProvider: NFTProvider
    private let config: Config
    private (set) lazy var tokenScriptFileStatusHandler: XMLHandler = assetDefinitionStore.xmlHandler(forTokenScriptSupportable: token)
    private let tokenImageFetcher: TokenImageFetcher

    let activitiesService: ActivitiesServiceType
    let tokenHolders: CurrentValueSubject<[TokenHolder], Never> = .init([])
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
        return NFTCollectionInfoPageViewModel(
            token: token,
            previewViewType: previewViewType,
            tokenHolder: tokenHolders.map { $0.first }.eraseToAnyPublisher(),
            nftProvider: nftProvider,
            assetDefinitionStore: assetDefinitionStore,
            tokenImageFetcher: tokenImageFetcher)
    }()

    private (set) lazy var nftAssetsPageViewModel = NFTAssetsPageViewModel(
        token: token,
        assetDefinitionStore: assetDefinitionStore,
        tokenHolders: tokenHolders.eraseToAnyPublisher(),
        layout: .list)

    init(token: Token,
         wallet: Wallet,
         assetDefinitionStore: AssetDefinitionStore,
         tokensService: TokensProcessingPipeline,
         activitiesService: ActivitiesServiceType,
         nftProvider: NFTProvider,
         config: Config,
         tokenImageFetcher: TokenImageFetcher) {

        self.config = config
        self.activitiesService = activitiesService
        self.nftProvider = nftProvider
        self.tokensService = tokensService
        self.token = token
        self.wallet = wallet
        self.assetDefinitionStore = assetDefinitionStore
        self.tokenImageFetcher = tokenImageFetcher
    }

    func transform(input: NFTCollectionViewModelInput) -> NFTCollectionViewModelOutput {
        Task {
            await activitiesService.start()
        }

        tokensService.tokenHoldersPublisher(for: token)
            .assign(to: \.value, on: tokenHolders)
            .store(in: &cancelable)

        let pullToRefreshState = refreshTokenHolders(input: input.pullToRefresh)
        let tokenHolder = tokenHolders.map { $0.first }.eraseToAnyPublisher()
        let actions = actions(for: tokenHolder)

        let title = tokensService.tokenViewModelPublisher(for: token)
            .compactMap { $0?.tokenScriptOverrides?.titleInPluralForm ?? "-" }

        let viewState = Publishers.CombineLatest3(title, tokenHolders, actions)
            .map { title, tokenHolders, actions in
                NFTCollectionViewModel.ViewState(title: title, actions: actions, tokenHolders: tokenHolders)
            }.eraseToAnyPublisher()

        let activities = activitiesService.activitiesPublisher
            .receive(on: RunLoop.main)
            .map { ActivityPageViewModel(activitiesViewModel: .init(collection: .init(activities: $0))) }
            .eraseToAnyPublisher()

        return .init(
            viewState: viewState,
            activities: activities,
            pullToRefreshState: pullToRefreshState)
    }

    private func actions(for trigger: AnyPublisher<TokenHolder?, Never>) -> AnyPublisher<[NonFungibleTokenAction], Never> {
        trigger.map {
            $0?.values.collectionValue.flatMap { collection -> URL? in
                guard collection.id.trimmed.nonEmpty else { return nil }
                return URL(string: "https://opensea.io/collection/\(collection.id)")
            }
        }.map { $0.flatMap { [NonFungibleTokenAction.openInUrl(url: $0)] } ?? [] }
        .eraseToAnyPublisher()
    }

    private func refreshTokenHolders(input: AnyPublisher<Void, Never>) -> AnyPublisher<Loadable<Void, Error>, Never> {
        input.map { _ in Loadable<Void, Error>.loading }
            .delay(for: .seconds(1), scheduler: RunLoop.main)
            .handleEvents(receiveOutput: { [tokensService, token, tokenHolders] _ in
                Task { @MainActor in
                    tokenHolders.value = await tokensService.tokenHolders(for: token)
                }
            })
            .map { _ in Loadable<Void, Error>.done(()) }
            .eraseToAnyPublisher()
    }

    var rightBarButtonItem: NFTCollectionViewModel.RightBarButtonItem {
        switch token.type {
        case .erc1155:
            guard Features.current.isAvailable(.isNftTransferEnabled) else { return .assetSelection(isEnabled: false) }

            switch wallet.type {
            case .real, .hardware:
                return .assetSelection(isEnabled: true)
            case .watch:
                return .assetSelection(isEnabled: config.development.shouldPretendIsRealWallet)
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
        case openInUrl(url: URL)

        var name: String {
            switch self {
            case .openInUrl:
                return R.string.localizable.openOnOpenSea()
            }
        }
    }

    enum RightBarButtonItem {
        case assetSelection(isEnabled: Bool)
        case assetsDisplayType(layout: GridOrListLayout)
        case none
    }
}
