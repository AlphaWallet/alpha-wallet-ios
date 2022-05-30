//
//  NFTAssetViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 07.09.2021.
//

import UIKit
import AlphaWalletOpenSea
import BigInt

struct AttributeCollectionViewModel {
    let traits: [NonFungibleTraitViewModel]
}

enum TokenInstanceViewConfiguration {
    case header(viewModel: TokenInfoHeaderViewModel)
    case field(viewModel: TokenAttributeViewModel)
    case attributeCollection(viewModel: AttributeCollectionViewModel)
}

enum TokenInstanceViewMode {
    case preview
    case interactive
}

class NFTAssetViewModel {
    private let displayHelper: OpenSeaNonFungibleTokenDisplayHelper
    private let tokenHolderHelper: TokenInstanceViewConfigurationHelper

    let tokenId: TokenId
    let token: TokenObject
    let tokenHolder: TokenHolder
    let assetDefinitionStore: AssetDefinitionStore
    var backgroundColor: UIColor = Colors.appBackground
    let account: Wallet
    var transferTransactionType: TransactionType {
        tokenHolder.select(with: .allFor(tokenId: tokenHolder.tokenId))
        return TransactionType(nonFungibleToken: token, tokenHolders: [tokenHolder])
    }

    var sellTransactionType: TransactionType {
        tokenHolder.select(with: .allFor(tokenId: tokenHolder.tokenId))
        return TransactionType.erc875Token(token, tokenHolders: [tokenHolder])
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
                .flatMap { TokenImage(image: .url($0), symbol: "", isFinal: true, overlayServerIcon: nil) }

            return .image(iconImage: .init(tokenImage))
        }
    }

    var previewViewContentBackgroundColor: UIColor {
        if displayHelper.imageHasBackgroundColor {
            return Colors.appBackground
        } else {
            if let color = tokenHolder.values.backgroundColorStringValue.nilIfEmpty {
                return UIColor(hex: color)
            } else {
                return UIColor(red: 247, green: 197, blue: 196)
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

    init(account: Wallet, tokenId: TokenId, token: TokenObject, tokenHolder: TokenHolder, assetDefinitionStore: AssetDefinitionStore) {
        self.account = account
        self.tokenId = tokenId
        self.token = token
        self.tokenHolder = tokenHolder
        self.assetDefinitionStore = assetDefinitionStore
        self.displayHelper = OpenSeaNonFungibleTokenDisplayHelper(contract: tokenHolder.contractAddress)
        self.tokenHolderHelper = TokenInstanceViewConfigurationHelper(tokenId: tokenId, tokenHolder: tokenHolder)
        self.contractViewModel = TokenAttributeViewModel(title: R.string.localizable.nonfungiblesValueContract(), attributedValue: TokenAttributeViewModel.urlValueAttributedString(token.contractAddress.truncateMiddle))
    }

    func configure(overiddenOpenSeaStats: Stats?) {
        self.tokenHolderHelper.overridenFloorPrice = overiddenOpenSeaStats?.floorPrice
        self.tokenHolderHelper.overridenItemsCount = overiddenOpenSeaStats?.itemsCount
    }

    var actions: [TokenInstanceAction] {
        let xmlHandler = XMLHandler(token: token, assetDefinitionStore: assetDefinitionStore)
        let actionsFromTokenScript = xmlHandler.actions
        if xmlHandler.hasAssetDefinition {
            return actionsFromTokenScript
        } else {
            switch token.type {
            case .erc1155, .erc721:
                return [
                    .init(type: .nonFungibleTransfer)
                ]
            case .erc875, .erc721ForTickets:
                return [
                    .init(type: .nftSell),
                    .init(type: .nonFungibleTransfer)
                ]
            case .nativeCryptocurrency, .erc20:
                return []
            }
        }
    }

    func firstMatchingTokenHolder(from tokenHolders: [TokenHolder]) -> TokenHolder? {
        return tokenHolders.first { $0.tokens[0].id == tokenId }
    }

    func isMatchingTokenHolder(from tokenHolders: [TokenHolder]) -> (tokenHolder: TokenHolder, tokenId: TokenId)? {
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

    var configurations: [TokenInstanceViewConfiguration] {
        var configurations: [TokenInstanceViewConfiguration] = []

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
        ].compactMap { each -> TokenInstanceViewConfiguration? in
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
        ].compactMap { each -> TokenInstanceViewConfiguration? in
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
        ].compactMap { viewModel -> TokenInstanceViewConfiguration? in
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

    var navigationTitle: String {
        let tokenId = tokenHolder.values.tokenIdStringValue ?? ""
        if let name = tokenHolder.values.nameStringValue.nilIfEmpty {
            return name
        } else {
            return displayHelper.title(fromTokenName: tokenHolder.name, tokenId: tokenId)
        }
    }
}
