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
    let selection: AnyPublisher<IndexPath, Never>
}

struct NFTAssetViewModelOutput {
    let state: AnyPublisher<NFTAssetViewModel.ViewState, Never>
    let nftAssetAction: AnyPublisher<NFTAssetViewModel.NftAssetAction, Never>
    let attributeSelectionAction: AnyPublisher<NFTAssetViewModel.AttributeSelectionAction, Never>
}

class NFTAssetViewModel {
    private let displayHelper: OpenSeaNonFungibleTokenDisplayHelper
    private let assetDisplayHelper: NftAssetDisplayHelper
    private let nftProvider: NFTProvider
    private let mode: NFTAssetViewModel.InterationMode
    private let service: TokensProcessingPipeline
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

    var previewViewType: NFTPreviewViewType {
        switch OpenSeaBackedNonFungibleTokenHandling(token: token, assetDefinitionStore: assetDefinitionStore, tokenViewType: .view) {
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
         service: TokensProcessingPipeline,
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
        self.assetDisplayHelper = NftAssetDisplayHelper(
            tokenId: tokenId,
            tokenHolder: tokenHolder,
            assetDefinitionStore: assetDefinitionStore)
    }

    func transform(input: NFTAssetViewModelInput) -> NFTAssetViewModelOutput {
        let collectionStats = loadCollectionStats()
        let tokenHolderPublisher = tokenHolderPublisher()

        let viewTypes = Publishers.Merge3(input.appear, tokenHolderPublisher, collectionStats)
            .flatMap { [assetDisplayHelper] _ in assetDisplayHelper.attributes }
            .map { [assetDisplayHelper] attributes in self.buildViewTypes(nftAssetDisplayHelper: assetDisplayHelper, attributes: attributes) }
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

        let attributeSelectionAction = input.selection
            .compactMap { self.buildAttributeSelectionAction(indexPath: $0) }

        return .init(
            state: viewState.eraseToAnyPublisher(),
            nftAssetAction: nftAssetAction.eraseToAnyPublisher(),
            attributeSelectionAction: attributeSelectionAction.eraseToAnyPublisher())
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
        assetDisplayHelper.overridenFloorPrice = overiddenOpenSeaStats?.floorPrice
        assetDisplayHelper.overridenItemsCount = overiddenOpenSeaStats?.itemsCount
    }

    private func tokenHolderPublisher() -> AnyPublisher<Void, Never> {
        return service.tokenHolderPublisher(for: token, tokenId: tokenId)
            .compactMap { $0 }
            .handleEvents(receiveOutput: { [weak self] in
                self?.tokenHolder = $0
                self?.assetDisplayHelper.update(tokenHolder: $0, tokenId: $0.tokenId)
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

    var tokenImagePlaceholder: UIImage? {
        return R.image.tokenPlaceholderLarge()
    }

    private func buildAttributeSelectionAction(indexPath: IndexPath) -> AttributeSelectionAction? {
        switch viewTypes[indexPath.row] {
        case .field(let vm) where assetDisplayHelper.tokenIdViewModel == vm:
            UIPasteboard.general.string = vm.value

            return .showCopiedToClipboard(title: R.string.localizable.copiedToClipboard())
        case .field(let vm) where assetDisplayHelper.creator == vm:
            guard let url = tokenHolder.values.creatorValue
                .flatMap({ URL(string: "https://opensea.io/\($0.contractAddress)?tab=created") }) else { return nil }

            return .openContractWebPage(url: url)
        case .header, .field, .attributeCollection:
            return nil
        }
    }

    private func buildViewTypes(nftAssetDisplayHelper: NftAssetDisplayHelper, attributes: [NonFungibleTraitViewModel]) -> [NFTAssetViewModel.ViewType] {
        var configurations: [NFTAssetViewModel.ViewType] = []

        configurations += [
            nftAssetDisplayHelper.valueModelViewModel,
            nftAssetDisplayHelper.issuerViewModel,
            nftAssetDisplayHelper.transferFeeViewModel,
            nftAssetDisplayHelper.createdDateViewModel,
            nftAssetDisplayHelper.meltValueViewModel,
            nftAssetDisplayHelper.meltFeeRatioViewModel,
            nftAssetDisplayHelper.meltFeeMaxRatioViewModel,
            nftAssetDisplayHelper.totalSupplyViewModel,
            nftAssetDisplayHelper.circulatingSupplyViewModel,
            nftAssetDisplayHelper.reserveViewModel,
            nftAssetDisplayHelper.nonFungibleViewModel,
            nftAssetDisplayHelper.availableToMintViewModel,
            nftAssetDisplayHelper.transferableViewModel,
        ].compactMap { each -> NFTAssetViewModel.ViewType? in
            return each.flatMap { .field(viewModel: $0) }
        }

        configurations += [
            nftAssetDisplayHelper.creator,
            nftAssetDisplayHelper.tokenIdViewModel,
        ].compactMap { each -> NFTAssetViewModel.ViewType? in
            return each.flatMap { .field(viewModel: $0) }
        }

        configurations += [
            nftAssetDisplayHelper.itemsCount,
            nftAssetDisplayHelper.totalVolume,
            nftAssetDisplayHelper.totalSales,
            nftAssetDisplayHelper.totalSupply,
            nftAssetDisplayHelper.owners,
            nftAssetDisplayHelper.averagePrice,
            nftAssetDisplayHelper.floorPrice
        ].compactMap { viewModel -> NFTAssetViewModel.ViewType? in
            return viewModel.flatMap { .field(viewModel: $0) }
        }

        if !configurations.isEmpty {
            configurations = [
                .header(viewModel: .init(title: R.string.localizable.semifungiblesDetails())),
            ] + configurations
        }

        if let viewModel = nftAssetDisplayHelper.descriptionViewModel {
            configurations += [
                .header(viewModel: .init(title: R.string.localizable.semifungiblesDescription())),
                .field(viewModel: viewModel)
            ]
        }

        if !attributes.isEmpty {
            configurations += [
                .header(viewModel: .init(title: R.string.localizable.semifungiblesAttributes())),
                .attributeCollection(viewModel: .init(traits: attributes))
            ]
        }

        if !nftAssetDisplayHelper.stats.isEmpty {
            configurations += [
                .header(viewModel: .init(title: R.string.localizable.semifungiblesStats())),
                .attributeCollection(viewModel: .init(traits: nftAssetDisplayHelper.stats))
            ]
        }

        if !nftAssetDisplayHelper.rankings.isEmpty {
            configurations += [
                .header(viewModel: .init(title: R.string.localizable.semifungiblesRankings())),
                .attributeCollection(viewModel: .init(traits: nftAssetDisplayHelper.rankings))
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

    enum AttributeSelectionAction {
        case showCopiedToClipboard(title: String)
        case openContractWebPage(url: URL)
    }

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
