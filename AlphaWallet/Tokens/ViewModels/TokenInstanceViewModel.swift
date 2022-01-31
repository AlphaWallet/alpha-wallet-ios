//
//  TokenInstanceViewModel2.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 07.09.2021.
//

import UIKit
import BigInt

enum TokenInstanceViewConfiguration {
    case header(viewModel: TokenInfoHeaderViewModel)
    case field(viewModel: TokenInstanceAttributeViewModel)
    case attributeCollection(viewModel: [NonFungibleTraitViewModel])
}

enum TokenInstanceViewMode {
    case preview
    case interactive
}

struct TokenInstanceViewModel {
    let tokenId: TokenId
    let token: TokenObject
    let tokenHolder: TokenHolder
    let assetDefinitionStore: AssetDefinitionStore
    private let displayHelper: OpenSeaNonFungibleTokenDisplayHelper
    var backgroundColor: UIColor = Colors.appBackground
    private let tokenHolderHelper: TokenInstanceViewConfigurationHelper

    init(tokenId: TokenId, token: TokenObject, tokenHolder: TokenHolder, assetDefinitionStore: AssetDefinitionStore) {
        self.tokenId = tokenId
        self.token = token
        self.tokenHolder = tokenHolder
        self.assetDefinitionStore = assetDefinitionStore
        self.displayHelper = OpenSeaNonFungibleTokenDisplayHelper(contract: tokenHolder.contractAddress)
        self.tokenHolderHelper = TokenInstanceViewConfigurationHelper(tokenId: tokenId, tokenHolder: tokenHolder)
        self.contractViewModel = TokenInstanceAttributeViewModel(title: R.string.localizable.nonfungiblesValueContract(), attributedValue: TokenInstanceAttributeViewModel.urlValueAttributedString(token.contractAddress.truncateMiddle))
    }

    mutating func configure(overiddenOpenSeaStats: OpenSea.Stats?) {
        self.tokenHolderHelper.overridenFloorPrice = overiddenOpenSeaStats?.floorPrice
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

    var tokenIdViewModel: TokenInstanceAttributeViewModel? {
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

    var creatorViewModel: TokenInstanceAttributeViewModel? {
        tokenHolderHelper.creator
    }

    var contractViewModel: TokenInstanceAttributeViewModel

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
            TokenInstanceAttributeViewModel(title: R.string.localizable.nonfungiblesValueBlockchain(), attributedValue: TokenInstanceAttributeViewModel.defaultValueAttributedString(token.server.blockChainName)),
            TokenInstanceAttributeViewModel(title: R.string.localizable.nonfungiblesValueTokenStandard(), attributedValue: TokenInstanceAttributeViewModel.defaultValueAttributedString(token.type.rawValue))
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
                .attributeCollection(viewModel: tokenHolderHelper.attributes)
            ]
        }

        if !tokenHolderHelper.stats.isEmpty {
            configurations += [
                .header(viewModel: .init(title: R.string.localizable.semifungiblesStats())),
                .attributeCollection(viewModel: tokenHolderHelper.stats)
            ]
        }

        if !tokenHolderHelper.rankings.isEmpty {
            configurations += [
                .header(viewModel: .init(title: R.string.localizable.semifungiblesRankings())),
                .attributeCollection(viewModel: tokenHolderHelper.rankings)
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
