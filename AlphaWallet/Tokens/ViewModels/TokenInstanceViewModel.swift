// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import BigInt
import UIKit

struct TokenInstanceViewModel {
    let tokenId: TokenId
    let token: TokenObject
    let tokenHolder: TokenHolder
    let assetDefinitionStore: AssetDefinitionStore
    private let displayHelper: OpenSeaNonFungibleTokenDisplayHelper
    var backgroundColor: UIColor = Colors.appBackground

    init(tokenId: TokenId, token: TokenObject, tokenHolder: TokenHolder, assetDefinitionStore: AssetDefinitionStore) {
        self.tokenId = tokenId
        self.token = token
        self.tokenHolder = tokenHolder
        self.assetDefinitionStore = assetDefinitionStore
        self.displayHelper = OpenSeaNonFungibleTokenDisplayHelper(contract: tokenHolder.contractAddress)
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

    var supplyModelViewModel: TokenInstanceAttributeViewModel? {
        return tokenHolder.values.supplyModel.flatMap {
            TokenInstanceAttributeViewModel.defaultValueAttributedString($0)
        }.flatMap {
            .init(title: R.string.localizable.semifungiblesAttributeSupplyType(preferredLanguages: Languages.preferred()), attributedValue: $0)
        }
    }

    var transferableViewModel: TokenInstanceAttributeViewModel? {
        return tokenHolder.values.transferable.flatMap {
            TokenInstanceAttributeViewModel.defaultValueAttributedString($0)
        }.flatMap {
            .init(title: R.string.localizable.semifungiblesAttributeTransferable(preferredLanguages: Languages.preferred()), attributedValue: $0)
        }
    }

    var meltValueViewModel: TokenInstanceAttributeViewModel? {
        return tokenHolder.values.meltStringValue.flatMap {
            TokenInstanceAttributeViewModel.defaultValueAttributedString($0)
        }.flatMap {
            .init(title: R.string.localizable.semifungiblesAttributeMelt(preferredLanguages: Languages.preferred()), attributedValue: $0)
        }
    }

    var meltFeeRatioViewModel: TokenInstanceAttributeViewModel? {
        return tokenHolder.values.meltFeeRatio.flatMap {
            TokenInstanceAttributeViewModel.defaultValueAttributedString(String($0))
        }.flatMap {
            .init(title: R.string.localizable.semifungiblesAttributeMeltFeeRatio(preferredLanguages: Languages.preferred()), attributedValue: $0)
        }
    }

    var meltFeeMaxRatioViewModel: TokenInstanceAttributeViewModel? {
        return tokenHolder.values.meltFeeMaxRatio.flatMap {
            TokenInstanceAttributeViewModel.defaultValueAttributedString(String($0))
        }.flatMap {
            .init(title: R.string.localizable.semifungiblesAttributeMeltFeeMaxRatio(preferredLanguages: Languages.preferred()), attributedValue: $0)
        }
    }

    var totalSupplyViewModel: TokenInstanceAttributeViewModel? {
        return tokenHolder.values.totalSupplyStringValue.flatMap {
            TokenInstanceAttributeViewModel.defaultValueAttributedString($0)
        }.flatMap {
            .init(title: R.string.localizable.semifungiblesAttributeTotalSupply(preferredLanguages: Languages.preferred()), attributedValue: $0)
        }
    }

    var circulatingSupplyViewModel: TokenInstanceAttributeViewModel? {
        return tokenHolder.values.circulatingSupplyStringValue.flatMap {
            TokenInstanceAttributeViewModel.defaultValueAttributedString($0)
        }.flatMap {
            .init(title: R.string.localizable.semifungiblesAttributeCirculatingSupply(preferredLanguages: Languages.preferred()), attributedValue: $0)
        }
    }

    var reserveViewModel: TokenInstanceAttributeViewModel? {
        return tokenHolder.values.reserve.flatMap {
            TokenInstanceAttributeViewModel.defaultValueAttributedString($0)
        }.flatMap {
            .init(title: R.string.localizable.semifungiblesAttributeReserve(preferredLanguages: Languages.preferred()), attributedValue: $0)
        }
    }

    var nonFungibleViewModel: TokenInstanceAttributeViewModel? {
        return tokenHolder.values.nonFungible.flatMap {
            TokenInstanceAttributeViewModel.defaultValueAttributedString(String($0))
        }.flatMap {
            .init(title: R.string.localizable.semifungiblesAttributeNonFungible(preferredLanguages: Languages.preferred()), attributedValue: $0)
        }
    }

    var availableToMintViewModel: TokenInstanceAttributeViewModel? {
        return tokenHolder.values.mintableSupply.flatMap {
            TokenInstanceAttributeViewModel.defaultValueAttributedString(String($0))
        }.flatMap {
            .init(title: R.string.localizable.semifungiblesAttributeAvailableToMint(preferredLanguages: Languages.preferred()), attributedValue: $0)
        }
    }

    var issuerViewModel: TokenInstanceAttributeViewModel? {
        return tokenHolder.values.issuer.flatMap {
            TokenInstanceAttributeViewModel.defaultValueAttributedString(String($0))
        }.flatMap {
            .init(title: R.string.localizable.semifungiblesAttributeIssuer(preferredLanguages: Languages.preferred()), attributedValue: $0)
        }
    }

    var transferFeeViewModel: TokenInstanceAttributeViewModel? {
        return tokenHolder.values.transferFee.flatMap {
            TokenInstanceAttributeViewModel.defaultValueAttributedString(String($0))
        }.flatMap {
            .init(title: R.string.localizable.semifungiblesAttributeTransferFee(preferredLanguages: Languages.preferred()), attributedValue: $0)
        }
    }

    var createdDateViewModel: TokenInstanceAttributeViewModel {
        let string: String? = tokenHolder.values.collectionCreatedDateGeneralisedTimeValue?.formatAsShortDateString()
        let attributedString: NSAttributedString? = string.flatMap {
            TokenInstanceAttributeViewModel.defaultValueAttributedString($0)
        }
        return .init(title: R.string.localizable.semifungiblesCreatedDate(preferredLanguages: Languages.preferred()), attributedValue: attributedString)
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
            .init(title: R.string.localizable.semifungiblesTokenId(preferredLanguages: Languages.preferred()), attributedValue: TokenInstanceAttributeViewModel.defaultValueAttributedString(tokenId))
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
            .field(viewModel: .init(title: R.string.localizable.semifungiblesValue(preferredLanguages: Languages.preferred()), attributedValue: TokenInstanceAttributeViewModel.defaultValueAttributedString(String(value))))
        ]
        if let description = values.descriptionAssetInternalValue?.resolvedValue?.stringValue.nilIfEmpty {
            previewViewModels += [
                .header(viewModel: .init(title: R.string.localizable.semifungiblesDescription(preferredLanguages: Languages.preferred()))),
                .field(viewModel: .init(title: nil, attributedValue: TokenInstanceAttributeViewModel.defaultValueAttributedString(description, alignment: .left), isSeparatorHidden: true))
            ]
        }

        return [
            .header(viewModel: .init(title: R.string.localizable.semifungiblesDetails(preferredLanguages: Languages.preferred())))
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
}
