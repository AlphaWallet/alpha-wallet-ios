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

    var tokenImagePlaceholder: UIImage? {
        return R.image.tokenPlaceholderLarge()
    }

    var supplyModelViewModel: TokenInstanceAttributeViewModel? {
        return tokenHolder.values.supplyModel.flatMap {
            TokenInstanceAttributeViewModel.defaultValueAttributedString($0)
        }.flatMap {
            .init(title: R.string.localizable.semifungiblesAttributeSupplyType(), attributedValue: $0)
        }
    }
    
    var transferableViewModel: TokenInstanceAttributeViewModel? {
        return tokenHolder.values.transferable.flatMap {
            TokenInstanceAttributeViewModel.defaultValueAttributedString($0)
        }.flatMap {
            .init(title: R.string.localizable.semifungiblesAttributeTransferable(), attributedValue: $0)
        }
    }

    var meltValueViewModel: TokenInstanceAttributeViewModel? {
        return tokenHolder.values.meltStringValue.flatMap {
            TokenInstanceAttributeViewModel.defaultValueAttributedString($0)
        }.flatMap {
            .init(title: R.string.localizable.semifungiblesAttributeMelt(), attributedValue: $0)
        }
    }

    var meltFeeRatioViewModel: TokenInstanceAttributeViewModel? {
        return tokenHolder.values.meltFeeRatio.flatMap {
            TokenInstanceAttributeViewModel.defaultValueAttributedString(String($0))
        }.flatMap {
            .init(title: R.string.localizable.semifungiblesAttributeMeltFeeRatio(), attributedValue: $0)
        }
    }

    var meltFeeMaxRatioViewModel: TokenInstanceAttributeViewModel? {
        return  tokenHolder.values.meltFeeMaxRatio.flatMap {
            TokenInstanceAttributeViewModel.defaultValueAttributedString(String($0))
        }.flatMap {
            .init(title: R.string.localizable.semifungiblesAttributeMeltFeeMaxRatio(), attributedValue: $0)
        }
    }

    var totalSupplyViewModel: TokenInstanceAttributeViewModel? {
        return tokenHolder.values.totalSupplyStringValue.flatMap {
            TokenInstanceAttributeViewModel.defaultValueAttributedString($0)
        }.flatMap {
            .init(title: R.string.localizable.semifungiblesAttributeTotalSupply(), attributedValue: $0)
        }
    }

    var circulatingSupplyViewModel: TokenInstanceAttributeViewModel? {
        return tokenHolder.values.circulatingSupplyStringValue.flatMap {
            TokenInstanceAttributeViewModel.defaultValueAttributedString($0)
        }.flatMap {
            .init(title: R.string.localizable.semifungiblesAttributeCirculatingSupply(), attributedValue: $0)
        }
    }

    var reserveViewModel: TokenInstanceAttributeViewModel? {
        return tokenHolder.values.reserve.flatMap {
            TokenInstanceAttributeViewModel.defaultValueAttributedString($0)
        }.flatMap {
            .init(title: R.string.localizable.semifungiblesAttributeReserve(), attributedValue: $0)
        }
    }

    var nonFungibleViewModel: TokenInstanceAttributeViewModel? {
        return tokenHolder.values.nonFungible.flatMap {
            TokenInstanceAttributeViewModel.defaultValueAttributedString(String($0))
        }.flatMap {
            .init(title: R.string.localizable.semifungiblesAttributeNonFungible(), attributedValue: $0)
        }
    }

    var availableToMintViewModel: TokenInstanceAttributeViewModel? {
        return tokenHolder.values.mintableSupply.flatMap {
            TokenInstanceAttributeViewModel.defaultValueAttributedString(String($0))
        }.flatMap {
            .init(title: R.string.localizable.semifungiblesAttributeAvailableToMint(), attributedValue: $0)
        }
    }

    var issuerViewModel: TokenInstanceAttributeViewModel? {
        return tokenHolder.values.issuer.flatMap {
            TokenInstanceAttributeViewModel.defaultValueAttributedString(String($0))
        }.flatMap {
            .init(title: R.string.localizable.semifungiblesAttributeIssuer(), attributedValue: $0)
        }
    }

    var transferFeeViewModel: TokenInstanceAttributeViewModel? {
        return tokenHolder.values.transferFee.flatMap {
            TokenInstanceAttributeViewModel.defaultValueAttributedString(String($0))
        }.flatMap {
            .init(title: R.string.localizable.semifungiblesAttributeTransferFee(), attributedValue: $0)
        }
    }

    var createdDateViewModel: TokenInstanceAttributeViewModel {
        let string: String? = tokenHolder.values.collectionCreatedDateGeneralisedTimeValue?.formatAsShortDateString()
        let attributedString: NSAttributedString? = string.flatMap {
            TokenInstanceAttributeViewModel.defaultValueAttributedString($0)
        }
        return .init(title: R.string.localizable.semifungiblesCreatedDate(), attributedValue: attributedString)
    }

    var descriptionViewModel: TokenInstanceAttributeViewModel {
        let string = tokenHolder.values.collectionDescriptionStringValue.flatMap {
            TokenInstanceAttributeViewModel.defaultValueAttributedString($0, alignment: .left)
        }
        return .init(title: nil, attributedValue: string, isSeparatorHidden: true)
    }

    var tokenIdViewModel: TokenInstanceAttributeViewModel? {
        guard let values = tokenHolder.values(tokenId: tokenId), !values.isEmpty else { return nil }
        return values.tokenIdStringValue.flatMap { tokenId in
            .init(title: R.string.localizable.semifungiblesTokenId(), attributedValue: TokenInstanceAttributeViewModel.defaultValueAttributedString(tokenId))
        }
    }

    var configurations: [TokenInstanceViewConfiguration] {
        guard let values = tokenHolder.values(tokenId: tokenId), !values.isEmpty else { return [] }

        var previewViewModels: [TokenInstanceViewConfiguration] = []
        if let viewModel = tokenIdViewModel {
            previewViewModels += [
                .field(viewModel: viewModel)
            ]
        }

        previewViewModels += [
            issuerViewModel,
            transferFeeViewModel,
            createdDateViewModel,
            meltValueViewModel,
            meltFeeRatioViewModel,
            meltFeeMaxRatioViewModel,
            totalSupplyViewModel,
            circulatingSupplyViewModel,
            reserveViewModel,
            nonFungibleViewModel,
            availableToMintViewModel,
            transferableViewModel,
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
