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

    var backgroundColor: UIColor = Colors.appBackground
    var tokenImagePlaceholder: UIImage? {
        return R.image.tokenPlaceholderLarge()
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

    var configurations: [TokenInstanceViewConfiguration] {
        guard let values = tokenHolder.values(tokenId: tokenId), !values.isEmpty else { return [] }
        var previewViewModels: [TokenInstanceViewConfiguration] = []
        if let tokenId = values.tokenIdStringValue {
            previewViewModels += [
                .field(viewModel: .init(title: R.string.localizable.semifungiblesTokenId(), attributedValue: TokenInstanceAttributeViewModel.defaultValueAttributedString(tokenId)))
            ]
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
        tokenHolder.values.nameStringValue
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
