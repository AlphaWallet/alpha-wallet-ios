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
}

enum TokenInstanceViewMode {
    case preview
    case interactive
}

struct Erc1155TokenInstanceViewModel {
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
    }

    var actions: [TokenInstanceAction] {
        let xmlHandler = XMLHandler(token: token, assetDefinitionStore: assetDefinitionStore)
        let actionsFromTokenScript = xmlHandler.actions
        if xmlHandler.hasAssetDefinition {
            return actionsFromTokenScript
        } else {
            switch token.type {
            case .erc1155:
                return [
                    .init(type: .nonFungibleTransfer)
                ]
            case .erc875, .erc721ForTickets:
                return [
                    .init(type: .nftSell),
                    .init(type: .nonFungibleTransfer)
                ]
            case .erc721:
                return [
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

    var tokenImagePlaceholder: UIImage? {
        return R.image.tokenPlaceholderLarge()
    }

    var configurations: [TokenInstanceViewConfiguration] {
        guard let values = tokenHolderHelper.values else { return [] }

        var previewViewModels: [TokenInstanceViewConfiguration] = []
        if let viewModel = tokenHolderHelper.tokenIdViewModel {
            previewViewModels += [
                .field(viewModel: viewModel)
            ]
        }

        previewViewModels += [
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
            return each.flatMap { TokenInstanceViewConfiguration.field(viewModel: $0) }
        } 

        let value: BigInt = values.valueIntValue ?? 0
        previewViewModels += [
            .field(viewModel: .init(title: R.string.localizable.semifungiblesValue(), attributedValue: TokenInstanceAttributeViewModel.defaultValueAttributedString(String(value))))
        ]
        if let description = values.descriptionAssetInternalValue?.resolvedValue?.stringValue.nilIfEmpty {
            previewViewModels += [
                .header(viewModel: .init(title: R.string.localizable.semifungiblesDescription())),
                .field(viewModel: .init(title: nil, attributedValue: TokenInstanceAttributeViewModel.defaultValueAttributedString(description, alignment: .left), isSeparatorHidden: true))
            ]
        }

        return [
            .header(viewModel: .init(title: R.string.localizable.semifungiblesDetails()))
        ] + previewViewModels
    }

    var navigationTitle: String? {
        let tokenId = tokenHolder.values.tokenIdStringValue ?? ""
        if let name = tokenHolder.values.nameStringValue.nilIfEmpty {
            return name
        } else {
            return displayHelper.title(fromTokenName: tokenHolder.name, tokenId: tokenId)
        }
    }

    func toggleSelection(for indexPath: IndexPath) {
        if tokenHolder.areDetailsVisible {
            tokenHolder.areDetailsVisible = false
            tokenHolder.isSelected = false
        } else {
            tokenHolder.areDetailsVisible = true
            tokenHolder.isSelected = true
        }
    }
}
