//
//  TokenInstanceViewModel2.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 07.09.2021.
//

import UIKit

enum TokenInstanceViewConfiguration {
    case header(viewModel: TokenInfoHeaderViewModel)
    case field(viewModel: TokenInstanceAttributeViewModel)
}

enum TokenInstanceViewMode {
    case preview
    case interactive
}

struct TokenInstanceViewModel2 {
    let tokenId: TokenId
    let token: TokenObject
    let tokenHolder: TokenHolder
    let assetDefinitionStore: AssetDefinitionStore

    var backgroundColor: UIColor = Colors.appBackground

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
        for (key, each) in values {
            guard key != "description" else { continue }
            guard var value = each.value.resolvedValue?.description, !each.value.isSubscribableValue else { continue }
            value = value.isEmpty ? "None" : value

            previewViewModels += [
                .field(viewModel: .init(title: key, attributedValue: TokenInstanceAttributeViewModel.defaultValueAttributedString(value)))
            ]
        }

        if let value = values["description"]?.value.resolvedValue?.description, value.nonEmpty {
            previewViewModels += [
                .header(viewModel: .init(title: "Details")),
                .field(viewModel: .init(title: nil, attributedValue: TokenInstanceAttributeViewModel.defaultValueAttributedString(value, alignment: .left), isSeparatorHidden: true))
            ]
        }

        return [
            .header(viewModel: .init(title: "Details"))
        ] + previewViewModels
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


