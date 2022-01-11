//
//  TokenInstanceInfoPageViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 23.12.2021.
//

import UIKit
import BigInt

struct TokenInstanceInfoPageViewModel {

    var tabTitle: String {
        return R.string.localizable.tokenTabInfo(preferredLanguages: Languages.preferred())
    }

    private let tokenObject: TokenObject
    private let tokenHolderHelper: TokenInstanceViewConfigurationHelper
    var contractAddress: AlphaWallet.Address {
        tokenObject.contractAddress
    }
    let tokenId: TokenId
    let tokenHolder: TokenHolder

    var tokenImagePlaceholder: UIImage? {
        return R.image.tokenPlaceholderLarge()
    }

    init(tokenObject: TokenObject, tokenHolder: TokenHolder, tokenId: TokenId) {
        self.tokenObject = tokenObject
        self.tokenHolder = tokenHolder
        self.tokenId = tokenId
        self.tokenHolderHelper = TokenInstanceViewConfigurationHelper(tokenId: tokenId, tokenHolder: tokenHolder)
    }

    var imageUrl: URL? {
        tokenHolderHelper.values?.imageUrlUrlValue ?? tokenHolderHelper.values?.thumbnailUrlUrlValue
    }

    var backgroundColor: UIColor {
        return Screen.TokenCard.Color.background
    }

    var configurations: [TokenInstanceViewConfiguration] {
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

        let value: BigInt = tokenHolderHelper.values?.valueIntValue ?? 0
        let attributedValue = TokenInstanceAttributeViewModel.defaultValueAttributedString(String(value))
        previewViewModels += [
            .field(viewModel: .init(title: R.string.localizable.semifungiblesValue(preferredLanguages: Languages.preferred()), attributedValue: attributedValue))
        ]
        if let description = tokenHolderHelper.values?.descriptionAssetInternalValue?.resolvedValue?.stringValue.nilIfEmpty {
            let attributedValue = TokenInstanceAttributeViewModel.defaultValueAttributedString(description, alignment: .left)
            previewViewModels += [
                .header(viewModel: .init(title: R.string.localizable.semifungiblesDescription(preferredLanguages: Languages.preferred()))),
                .field(viewModel: .init(title: nil, attributedValue: attributedValue, isSeparatorHidden: true))
            ]
        }

        return [
            .header(viewModel: .init(title: R.string.localizable.semifungiblesDetails(preferredLanguages: Languages.preferred())))
        ] + previewViewModels
    }
}
