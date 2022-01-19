//
//  TokenInstanceViewConfigurationHelper.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 23.12.2021.
//

import UIKit

final class TokenInstanceViewConfigurationHelper {
    private let tokenId: TokenId
    private let tokenHolder: TokenHolder
    private let displayHelper: OpenSeaNonFungibleTokenDisplayHelper
    
    init(tokenId: TokenId, tokenHolder: TokenHolder) {
        self.tokenId = tokenId
        self.tokenHolder = tokenHolder
        self.displayHelper = OpenSeaNonFungibleTokenDisplayHelper(contract: tokenHolder.contractAddress)
    }

    var values: [AttributeId: AssetAttributeSyntaxValue]? {
        guard let values = tokenHolder.values(tokenId: tokenId), !values.isEmpty else { return nil }
        return values
    }

    var createdDateViewModel: TokenInstanceAttributeViewModel? {
        return values?.collectionCreatedDateGeneralisedTimeValue.flatMap {
            TokenInstanceAttributeViewModel.defaultValueAttributedString($0.formatAsShortDateString())
        }.flatMap {
            .init(title: R.string.localizable.semifungiblesCreatedDate(), attributedValue: $0)
        }
    }

    var tokenIdViewModel: TokenInstanceAttributeViewModel? {
        return values?.tokenIdStringValue.flatMap { tokenId in
            .init(title: R.string.localizable.semifungiblesTokenId(), attributedValue: TokenInstanceAttributeViewModel.defaultValueAttributedString(tokenId))
        }
    }

    var supplyModelViewModel: TokenInstanceAttributeViewModel? {
        return values?.supplyModel.flatMap {
            TokenInstanceAttributeViewModel.defaultValueAttributedString($0)
        }.flatMap {
            .init(title: R.string.localizable.semifungiblesAttributeSupplyType(), attributedValue: $0)
        }
    }

    var transferableViewModel: TokenInstanceAttributeViewModel? {
        return values?.transferable.flatMap {
            TokenInstanceAttributeViewModel.defaultValueAttributedString($0)
        }.flatMap {
            .init(title: R.string.localizable.semifungiblesAttributeTransferable(), attributedValue: $0)
        }
    }

    var meltValueViewModel: TokenInstanceAttributeViewModel? {
        return values?.meltStringValue.flatMap {
            TokenInstanceAttributeViewModel.defaultValueAttributedString($0)
        }.flatMap {
            .init(title: R.string.localizable.semifungiblesAttributeMelt(), attributedValue: $0)
        }
    }

    var meltFeeRatioViewModel: TokenInstanceAttributeViewModel? {
        return values?.meltFeeRatio.flatMap {
            TokenInstanceAttributeViewModel.defaultValueAttributedString(String($0))
        }.flatMap {
            .init(title: R.string.localizable.semifungiblesAttributeMeltFeeRatio(), attributedValue: $0)
        }
    }

    var meltFeeMaxRatioViewModel: TokenInstanceAttributeViewModel? {
        return values?.meltFeeMaxRatio.flatMap {
            TokenInstanceAttributeViewModel.defaultValueAttributedString(String($0))
        }.flatMap {
            .init(title: R.string.localizable.semifungiblesAttributeMeltFeeMaxRatio(), attributedValue: $0)
        }
    }

    var totalSupplyViewModel: TokenInstanceAttributeViewModel? {
        return values?.totalSupplyStringValue.flatMap {
            TokenInstanceAttributeViewModel.defaultValueAttributedString($0)
        }.flatMap {
            .init(title: R.string.localizable.semifungiblesAttributeTotalSupply(), attributedValue: $0)
        }
    }

    var circulatingSupplyViewModel: TokenInstanceAttributeViewModel? {
        return values?.circulatingSupplyStringValue.flatMap {
            TokenInstanceAttributeViewModel.defaultValueAttributedString($0)
        }.flatMap {
            .init(title: R.string.localizable.semifungiblesAttributeCirculatingSupply(), attributedValue: $0)
        }
    }

    var reserveViewModel: TokenInstanceAttributeViewModel? {
        return values?.reserve.flatMap {
            TokenInstanceAttributeViewModel.defaultValueAttributedString($0)
        }.flatMap {
            .init(title: R.string.localizable.semifungiblesAttributeReserve(), attributedValue: $0)
        }
    }

    var nonFungibleViewModel: TokenInstanceAttributeViewModel? {
        return values?.nonFungible.flatMap {
            TokenInstanceAttributeViewModel.defaultValueAttributedString(String($0))
        }.flatMap {
            .init(title: R.string.localizable.semifungiblesAttributeNonFungible(), attributedValue: $0)
        }
    }

    var availableToMintViewModel: TokenInstanceAttributeViewModel? {
        return values?.mintableSupply.flatMap {
            TokenInstanceAttributeViewModel.defaultValueAttributedString(String($0))
        }.flatMap {
            .init(title: R.string.localizable.semifungiblesAttributeAvailableToMint(), attributedValue: $0)
        }
    }

    var issuerViewModel: TokenInstanceAttributeViewModel? {
        return values?.issuer.flatMap {
            TokenInstanceAttributeViewModel.defaultValueAttributedString(String($0))
        }.flatMap {
            .init(title: R.string.localizable.semifungiblesAttributeIssuer(), attributedValue: $0)
        }
    }

    var transferFeeViewModel: TokenInstanceAttributeViewModel? {
        return values?.transferFee.flatMap {
            TokenInstanceAttributeViewModel.defaultValueAttributedString(String($0))
        }.flatMap {
            .init(title: R.string.localizable.semifungiblesAttributeTransferFee(), attributedValue: $0)
        }
    }

    var attributes: [OpenSeaNonFungibleTokenAttributeCellViewModel] {
        let traits = tokenHolder.openSeaNonFungibleTraits ?? []
        let traitsToDisplay = traits.filter { displayHelper.shouldDisplayAttribute(name: $0.type) }
        return traitsToDisplay.map { mapTraitsToProperName(name: $0.type, value: $0.value) }
    }

    var rankings: [OpenSeaNonFungibleTokenAttributeCellViewModel] {
        let traits = tokenHolder.openSeaNonFungibleTraits ?? []
        let traitsToDisplay = traits.filter { displayHelper.shouldDisplayRanking(name: $0.type) }
        return traitsToDisplay.map { mapTraitsToProperName(name: $0.type, value: $0.value) }
    }

    var stats: [OpenSeaNonFungibleTokenAttributeCellViewModel] {
        let traits = tokenHolder.openSeaNonFungibleTraits ?? []
        let traitsToDisplay = traits.filter { displayHelper.shouldDisplayStat(name: $0.type) }
        return traitsToDisplay.map { mapTraitsToProperName(name: $0.type, value: $0.value) }
    }

    private func mapTraitsToProperName(name: String, value: String) -> OpenSeaNonFungibleTokenAttributeCellViewModel {
        let displayName = displayHelper.mapTraitsToDisplayName(name: name)
        let displayValue = displayHelper.mapTraitsToDisplayValue(name: name, value: value)
        return OpenSeaNonFungibleTokenAttributeCellViewModel(name: displayName, value: displayValue)
    }

}
