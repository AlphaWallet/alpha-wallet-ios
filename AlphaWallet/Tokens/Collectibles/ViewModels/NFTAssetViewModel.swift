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

enum TokenInstanceViewMode {
    case preview
    case interactive
}

struct NFTAssetViewModelInput {
    let appear: AnyPublisher<Void, Never>
}

struct NFTAssetViewModelOutput {
    let state: AnyPublisher<NFTAssetViewModel.ViewState, Never>
}

class NFTAssetViewModel {
    private let displayHelper: OpenSeaNonFungibleTokenDisplayHelper
    private let tokenHolderHelper: TokenInstanceViewConfigurationHelper
    private let nftProvider: NFTProvider
    private let mode: TokenInstanceViewMode
    private let service: TokenViewModelState & TokenHolderState
    private (set) var viewTypes: [NFTAssetViewModel.ViewType] = []
    let session: WalletSession
    let token: Token
    private (set) var tokenId: TokenId
    private (set) var tokenHolder: TokenHolder
    let assetDefinitionStore: AssetDefinitionStore
    var backgroundColor: UIColor = Configuration.Color.Semantic.defaultViewBackground
    var transferTransactionType: TransactionType {
        tokenHolder.select(with: .allFor(tokenId: tokenHolder.tokenId))
        return TransactionType(nonFungibleToken: token, tokenHolders: [tokenHolder])
    }

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
            let tokenImage = tokenHolder.assetImageUrl(tokenId: tokenId)
                .flatMap { TokenImage(image: .url($0), isFinal: true, overlayServerIcon: nil) }

            return .image(iconImage: .just(tokenImage))
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
    private var cancellable = Set<AnyCancellable>()

    init(tokenId: TokenId, token: Token, tokenHolder: TokenHolder, assetDefinitionStore: AssetDefinitionStore, mode: TokenInstanceViewMode, nftProvider: NFTProvider, session: WalletSession, service: TokenViewModelState & TokenHolderState) {
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
        let whenOpenSeaStatsHasChanged = PassthroughSubject<Void, Never>()
        if let collectionId = tokenHolder.values.collectionId, collectionId.trimmed.nonEmpty {
            nftProvider.collectionStats(collectionId: collectionId)
                .receive(on: RunLoop.main)
                .sink(receiveCompletion: { _ in

                }, receiveValue: { [weak self] stats in
                    self?.configure(overiddenOpenSeaStats: stats)
                    whenOpenSeaStatsHasChanged.send(())
                }).store(in: &cancellable)
        }

        let tokenHolderHasChanged = service.tokenHoldersPublisher(for: token)
            .dropFirst()
            .compactMap { [weak self, token] updatedTokenHolders -> (tokenHolder: TokenHolder, tokenId: TokenId)? in
                switch token.type {
                case .erc721, .erc875, .erc721ForTickets:
                    return self?.firstMatchingTokenHolder(from: updatedTokenHolders).flatMap { ($0, $0.tokenId) }
                case .erc1155:
                    return self?.isMatchingTokenHolder(from: updatedTokenHolders)
                case .nativeCryptocurrency, .erc20:
                    return nil
                }
            }.handleEvents(receiveOutput: { [weak self] in
                self?.tokenId = $0.tokenId
                self?.tokenHolder = $0.tokenHolder
                self?.tokenHolderHelper.update(tokenHolder: $0.tokenHolder, tokenId: $0.tokenId)
            }).map { _ in }.eraseToAnyPublisher()

        let viewState = Publishers.Merge3(input.appear, tokenHolderHasChanged, whenOpenSeaStatsHasChanged)
            .compactMap { [weak self] _ -> NFTAssetViewModel.ViewState? in
                guard let strongSelf = self else { return nil }
                strongSelf.viewTypes = strongSelf.buildViewTypes(for: strongSelf.tokenHolderHelper)
                return NFTAssetViewModel.ViewState(title: strongSelf.title, actions: strongSelf.actions, viewTypes: strongSelf.viewTypes, previewViewParams: strongSelf.previewViewParams, previewViewContentBackgroundColor: strongSelf.previewViewContentBackgroundColor)
            }.eraseToAnyPublisher()

        return .init(state: viewState)
    }

    private func configure(overiddenOpenSeaStats: Stats?) {
        tokenHolderHelper.overridenFloorPrice = overiddenOpenSeaStats?.floorPrice
        tokenHolderHelper.overridenItemsCount = overiddenOpenSeaStats?.itemsCount
    }

    var actions: [TokenInstanceAction] {
        switch mode {
        case .preview:
            return []
        case .interactive:
            break
        }

        let xmlHandler = XMLHandler(token: token, assetDefinitionStore: assetDefinitionStore)
        let actionsFromTokenScript = xmlHandler.actions
        infoLog("[TokenScript] actions names: \(actionsFromTokenScript.map(\.name))")
        let results: [TokenInstanceAction]
        if xmlHandler.hasAssetDefinition {
            results = actionsFromTokenScript
        } else {
            switch token.type {
            case .erc1155, .erc721:
                results = [
                    .init(type: .nonFungibleTransfer)
                ]
            case .erc875, .erc721ForTickets:
                results = [
                    .init(type: .nftSell),
                    .init(type: .nonFungibleTransfer)
                ]
            case .nativeCryptocurrency, .erc20:
                results = []
            }
        }

        if Features.default.isAvailable(.isNftTransferEnabled) {
            return results
        } else {
            return results.filter {
                $0.type != .nonFungibleTransfer
            }
        }
    }

    private func firstMatchingTokenHolder(from tokenHolders: [TokenHolder]) -> TokenHolder? {
        return tokenHolders.first { $0.tokens[0].id == tokenId }
    }

    private func isMatchingTokenHolder(from tokenHolders: [TokenHolder]) -> (tokenHolder: TokenHolder, tokenId: TokenId)? {
        return tokenHolders.first(where: { $0.tokens.contains(where: { $0.id == tokenId }) }).flatMap { ($0, tokenId) }
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

    var contractViewModel: TokenAttributeViewModel

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

    func tokenScriptWarningMessage(for action: TokenInstanceAction) -> FungibleTokenDetailsViewModel.TokenScriptWarningMessage? {
        if let selection = action.activeExcludingSelection(selectedTokenHolders: [tokenHolder], forWalletAddress: session.account.address) {
            if let denialMessage = selection.denial {
                return .warning(string: denialMessage)
            } else {
                //no-op shouldn't have reached here since the button should be disabled. So just do nothing to be safe
                return .undefined
            }
        } else {
            return nil
        }
    }

    func buttonState(for action: TokenInstanceAction) -> FungibleTokenDetailsViewModel.ActionButtonState {
        func _configButton(action: TokenInstanceAction) -> FungibleTokenDetailsViewModel.ActionButtonState {
            if let selection = action.activeExcludingSelection(selectedTokenHolders: [tokenHolder], forWalletAddress: session.account.address) {
                if selection.denial == nil {
                    return .isDisplayed(false)
                }
            }
            return .noOption
        }

        switch session.account.type {
        case .real:
            return _configButton(action: action)
        case .watch:
            if session.config.development.shouldPretendIsRealWallet {
                return _configButton(action: action)
            } else {
                return .isEnabled(false)
            }
        }
    }
}

extension NFTAssetViewModel {
    enum ViewType {
        case header(viewModel: TokenInfoHeaderViewModel)
        case field(viewModel: TokenAttributeViewModel)
        case attributeCollection(viewModel: AttributeCollectionViewModel)
    }

    struct ViewState {
        let title: String
        let actions: [TokenInstanceAction]
        let viewTypes: [NFTAssetViewModel.ViewType]
        let previewViewParams: NFTPreviewViewType.Params
        let previewViewContentBackgroundColor: UIColor
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
