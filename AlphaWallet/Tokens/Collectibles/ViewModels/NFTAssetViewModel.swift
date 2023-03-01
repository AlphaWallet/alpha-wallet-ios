//
//  NFTAssetViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 07.09.2021.
//

import UIKit
import BigInt
import Combine
import AlphaWalletFoundation
import AlphaWalletLogger

struct AttributeCollectionViewModel {
    let traits: [NonFungibleTraitViewModel]
}

struct NFTAssetViewModelInput {
    let appear: AnyPublisher<Void, Never>
    let action: AnyPublisher<TokenInstanceAction, Never>
}

struct NFTAssetViewModelOutput {
    let state: AnyPublisher<NFTAssetViewModel.ViewState, Never>
    let nftAssetAction: AnyPublisher<NFTAssetViewModel.NftAssetAction, Never>
}

class NFTAssetViewModel {
    private let displayHelper: OpenSeaNonFungibleTokenDisplayHelper
    private let tokenHolderHelper: TokenInstanceViewConfigurationHelper
    private let nftProvider: NFTProvider
    private let mode: NFTAssetViewModel.InterationMode
    private let service: TokenViewModelState & TokenHolderState
    private var actionAdapter: TokenInstanceActionAdapter {
        return TokenInstanceActionAdapter(
           session: session,
           token: token,
           tokenHolder: tokenHolder,
           tokenActionsProvider: tokenActionsProvider)
    }
    private var tokenHolder: TokenHolder
    private let tokenActionsProvider: SupportedTokenActionsProvider
    private (set) var viewTypes: [NFTAssetViewModel.ViewType] = []
    let session: WalletSession
    let token: Token
    let tokenId: TokenId
    let assetDefinitionStore: AssetDefinitionStore

    let contractViewModel: TokenAttributeViewModel
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
            let assetImage = tokenHolder.assetImageUrl(tokenId: tokenId)
                .flatMap { TokenImage(image: .url($0), isFinal: true, overlayServerIcon: nil) }
            
            return .image(iconImage: .just(assetImage))
        }
    }

    var previewViewContentBackgroundColor: UIColor {
        if displayHelper.imageHasBackgroundColor {
            return Configuration.Color.Semantic.defaultViewBackground
        } else {
            if let color = tokenHolder.values.backgroundColorStringValue.nilIfEmpty {
                return UIColor(hex: color)
            } else {
                return Configuration.Color.Semantic.NFTAssetViewPreviewViewContentBackgroundColor
            }
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

    init(tokenId: TokenId,
         token: Token,
         tokenHolder: TokenHolder,
         assetDefinitionStore: AssetDefinitionStore,
         mode: NFTAssetViewModel.InterationMode,
         nftProvider: NFTProvider,
         session: WalletSession,
         service: TokenViewModelState & TokenHolderState,
         tokenActionsProvider: SupportedTokenActionsProvider) {

        self.tokenActionsProvider = tokenActionsProvider
        self.service = service
        self.nftProvider = nftProvider
        self.session = session
        self.tokenId = tokenId
        self.mode = mode
        self.token = token
        self.tokenHolder = tokenHolder
        self.assetDefinitionStore = assetDefinitionStore
        self.displayHelper = OpenSeaNonFungibleTokenDisplayHelper(contract: tokenHolder.contractAddress)
        self.tokenHolderHelper = TokenInstanceViewConfigurationHelper(tokenId: tokenId, tokenHolder: tokenHolder, assetDefinitionStore: assetDefinitionStore)
        self.contractViewModel = TokenAttributeViewModel(title: R.string.localizable.nonfungiblesValueContract(), attributedValue: TokenAttributeViewModel.urlValueAttributedString(token.contractAddress.truncateMiddle))
    }

    func transform(input: NFTAssetViewModelInput) -> NFTAssetViewModelOutput {
        let collectionStats = loadCollectionStats()
        let tokenHolderPublisher = tokenHolderPublisher()

        let viewTypes = Publishers.Merge3(input.appear, tokenHolderPublisher, collectionStats)
            .map { _ in self.buildViewTypes(for: self.tokenHolderHelper) }
            .handleEvents(receiveOutput: { self.viewTypes = $0 })

        let actionButtons = buildActionButtons(trigger: tokenHolderPublisher)

        let viewState = Publishers.CombineLatest(viewTypes, actionButtons)
            .map { viewTypes, actionButtons in
                return NFTAssetViewModel.ViewState(
                    title: self.title,
                    actionButtons: actionButtons,
                    viewTypes: viewTypes,
                    previewViewParams: self.previewViewParams,
                    previewViewContentBackgroundColor: self.previewViewContentBackgroundColor)
            }

        let nftAssetAction = input.action
            .compactMap { self.buildNftAssetAction(action: $0) }

        return .init(
            state: viewState.eraseToAnyPublisher(),
            nftAssetAction: nftAssetAction.eraseToAnyPublisher())
    }

    private func buildNftAssetAction(action: TokenInstanceAction) -> NFTAssetViewModel.NftAssetAction? {
        switch action.type {
        case .nftRedeem:
            return .redeem(token: token, tokenHolder: tokenHolder)
        case .nftSell:
            return .sell(tokenHolder: tokenHolder)
        case .erc20Send, .erc20Receive, .swap, .buy, .bridge:
            //TODO when we support TokenScript views for ERC20s, we need to perform the action here
            return nil
        case .nonFungibleTransfer:
            tokenHolder.select(with: .allFor(tokenId: tokenHolder.tokenId))
            let transactionType = TransactionType(nonFungibleToken: token, tokenHolders: [tokenHolder])

            return .transfer(token: token, tokenHolder: tokenHolder, transactionType: transactionType)
        case .tokenScript:
            if let message = actionAdapter.tokenScriptWarningMessage(for: action, fungibleBalance: nil) {
                guard case .warning(let denialMessage) = message else { return nil }

                return .display(warning: denialMessage)
            } else {
                return .tokenScript(action: action, tokenHolder: tokenHolder)
            }
        }
    }

    private func configure(overiddenOpenSeaStats: Stats?) {
        tokenHolderHelper.overridenFloorPrice = overiddenOpenSeaStats?.floorPrice
        tokenHolderHelper.overridenItemsCount = overiddenOpenSeaStats?.itemsCount
    }

    private func tokenHolderPublisher() -> AnyPublisher<Void, Never> {
        return service.tokenHolderPublisher(for: token, tokenId: tokenId)
            .compactMap { $0 }
            .handleEvents(receiveOutput: { [weak self] in
                self?.tokenHolder = $0
                self?.tokenHolderHelper.update(tokenHolder: $0, tokenId: $0.tokenId)
            }).mapToVoid()
            .eraseToAnyPublisher()
    }

    private func loadCollectionStats() -> AnyPublisher<Void, Never> {
        if let collectionId = tokenHolder.values.collectionId, collectionId.trimmed.nonEmpty {
            return nftProvider.collectionStats(collectionId: collectionId)
                .handleEvents(receiveOutput: { [weak self] in self?.configure(overiddenOpenSeaStats: $0) })
                .mapToVoid()
                .replaceError(with: ())
                .eraseToAnyPublisher()
        } else {
            return .empty()
        }
    }

    private func buildActionButtons(trigger: AnyPublisher<Void, Never>) -> AnyPublisher<[FungibleTokenDetailsViewModel.ActionButton], Never> {
        return trigger
            .map { _ in self.actionAdapter.availableActions() }
            .map { actions in
                actions.map {
                    FungibleTokenDetailsViewModel.ActionButton(
                        actionType: $0,
                        name: $0.name,
                        state: self.actionAdapter.state(for: $0, fungibleBalance: nil))
                }
            }.eraseToAnyPublisher()
    }

    var tokenIdViewModel: TokenAttributeViewModel? {
        tokenHolderHelper.tokenIdViewModel
    }

    var creatorOnOpenSeaUrl: URL? {
        return tokenHolder.values.creatorValue
            .flatMap { URL(string: "https://opensea.io/\($0.contractAddress)?tab=created") }
    }

    var contractOnExplorerUrl: URL? {
        ConfigExplorer(server: token.server)
            .contractUrl(address: token.contractAddress)?.url
    }

    var creatorViewModel: TokenAttributeViewModel? {
        tokenHolderHelper.creator
    }

    var tokenImagePlaceholder: UIImage? {
        return R.image.tokenPlaceholderLarge()
    }

    private func buildViewTypes(for tokenHolderHelper: TokenInstanceViewConfigurationHelper) -> [NFTAssetViewModel.ViewType] {
        var configurations: [NFTAssetViewModel.ViewType] = []

        configurations += [
            tokenHolderHelper.valueModelViewModel,
            tokenHolderHelper.issuerViewModel,
            tokenHolderHelper.transferFeeViewModel,
            tokenHolderHelper.createdDateViewModel,
            tokenHolderHelper.meltValueViewModel,
            tokenHolderHelper.meltFeeRatioViewModel,
            tokenHolderHelper.meltFeeMaxRatioViewModel,
            tokenHolderHelper.totalSupplyViewModel,
            tokenHolderHelper.circulatingSupplyViewModel,
            tokenHolderHelper.reserveViewModel,
            tokenHolderHelper.nonFungibleViewModel,
            tokenHolderHelper.availableToMintViewModel,
            tokenHolderHelper.transferableViewModel,
        ].compactMap { each -> NFTAssetViewModel.ViewType? in
            return each.flatMap { .field(viewModel: $0) }
        }

        configurations += [
            .header(viewModel: .init(title: R.string.localizable.semifungiblesDetails())),
        ] + [
            tokenHolderHelper.creator,
            tokenHolderHelper.tokenIdViewModel,
            contractViewModel,
            TokenAttributeViewModel(title: R.string.localizable.nonfungiblesValueBlockchain(), attributedValue: TokenAttributeViewModel.defaultValueAttributedString(token.server.blockChainName)),
            TokenAttributeViewModel(title: R.string.localizable.nonfungiblesValueTokenStandard(), attributedValue: TokenAttributeViewModel.defaultValueAttributedString(token.type.rawValue))
        ].compactMap { each -> NFTAssetViewModel.ViewType? in
            return each.flatMap { .field(viewModel: $0) }
        }

        configurations += [
            tokenHolderHelper.itemsCount,
            tokenHolderHelper.totalVolume,
            tokenHolderHelper.totalSales,
            tokenHolderHelper.totalSupply,
            tokenHolderHelper.owners,
            tokenHolderHelper.averagePrice,
            tokenHolderHelper.floorPrice
        ].compactMap { viewModel -> NFTAssetViewModel.ViewType? in
            return viewModel.flatMap { .field(viewModel: $0) }
        }

        if let viewModel = tokenHolderHelper.descriptionViewModel {
            configurations += [
                .header(viewModel: .init(title: R.string.localizable.semifungiblesDescription())),
                .field(viewModel: viewModel)
            ]
        }

        if !tokenHolderHelper.attributes.isEmpty {
            configurations += [
                .header(viewModel: .init(title: R.string.localizable.semifungiblesAttributes())),
                .attributeCollection(viewModel: .init(traits: tokenHolderHelper.attributes))
            ]
        }

        if !tokenHolderHelper.stats.isEmpty {
            configurations += [
                .header(viewModel: .init(title: R.string.localizable.semifungiblesStats())),
                .attributeCollection(viewModel: .init(traits: tokenHolderHelper.stats))
            ]
        }

        if !tokenHolderHelper.rankings.isEmpty {
            configurations += [
                .header(viewModel: .init(title: R.string.localizable.semifungiblesRankings())),
                .attributeCollection(viewModel: .init(traits: tokenHolderHelper.rankings))
            ]
        }

        return configurations
    }

    var title: String {
        let tokenId = tokenHolder.values.tokenIdStringValue ?? ""
        if let name = tokenHolder.values.nameStringValue.nilIfEmpty {
            return name
        } else {
            return displayHelper.title(fromTokenName: tokenHolder.name, tokenId: tokenId)
        }
    }
}

extension NFTAssetViewModel {

    enum InterationMode {
        case preview
        case interactive
    }

    enum ViewType {
        case header(viewModel: TokenInfoHeaderViewModel)
        case field(viewModel: TokenAttributeViewModel)
        case attributeCollection(viewModel: AttributeCollectionViewModel)
    }

    struct ViewState {
        let title: String
        let actionButtons: [FungibleTokenDetailsViewModel.ActionButton]
        let viewTypes: [NFTAssetViewModel.ViewType]
        let previewViewParams: NFTPreviewViewType.Params
        let previewViewContentBackgroundColor: UIColor
    }

    enum NftAssetAction {
        case redeem(token: Token, tokenHolder: TokenHolder)
        case sell(tokenHolder: TokenHolder)
        case transfer(token: Token, tokenHolder: TokenHolder, transactionType: TransactionType)
        case display(warning: String)
        case tokenScript(action: TokenInstanceAction, tokenHolder: TokenHolder)
    }
}

extension TokenInstanceAction {
    var name: String {
        switch type {
        case .erc20Send:
            return R.string.localizable.send()
        case .erc20Receive:
            return R.string.localizable.receive()
        case .nftRedeem:
            return R.string.localizable.aWalletTokenRedeemButtonTitle()
        case .nftSell:
            return R.string.localizable.aWalletTokenSellButtonTitle()
        case .nonFungibleTransfer:
            return R.string.localizable.aWalletTokenTransferButtonTitle()
        case .tokenScript(_, let title, _, _, _, _):
            return title
        case .swap(let service):
            return service.action
        case .buy(let service):
            return service.action
        case .bridge(let service):
            return service.action
        }
    }
}
