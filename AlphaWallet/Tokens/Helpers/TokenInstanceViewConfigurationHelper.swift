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

    init(tokenId: TokenId, tokenHolder: TokenHolder) {
        self.tokenId = tokenId
        self.tokenHolder = tokenHolder
    }

    var values: [AttributeId: AssetAttributeSyntaxValue]? {
        guard let values = tokenHolder.values(tokenId: tokenId), !values.isEmpty else { return nil }
        return values
    }

    var createdDateViewModel: TokenInstanceAttributeViewModel? {
        return values?.collectionCreatedDateGeneralisedTimeValue.flatMap {
            TokenInstanceAttributeViewModel.defaultValueAttributedString($0.formatAsShortDateString())
        }.flatMap {
            .init(title: R.string.localizable.semifungiblesCreatedDate(preferredLanguages: Languages.preferred()), attributedValue: $0)
        }
    }

    var tokenIdViewModel: TokenInstanceAttributeViewModel? {
        return values?.tokenIdStringValue.flatMap { tokenId in
            .init(title: R.string.localizable.semifungiblesTokenId(preferredLanguages: Languages.preferred()), attributedValue: TokenInstanceAttributeViewModel.defaultValueAttributedString(tokenId))
        }
    }

    var supplyModelViewModel: TokenInstanceAttributeViewModel? {
        return values?.supplyModel.flatMap {
            TokenInstanceAttributeViewModel.defaultValueAttributedString($0)
        }.flatMap {
            .init(title: R.string.localizable.semifungiblesAttributeSupplyType(preferredLanguages: Languages.preferred()), attributedValue: $0)
        }
    }

    var transferableViewModel: TokenInstanceAttributeViewModel? {
        return values?.transferable.flatMap {
            TokenInstanceAttributeViewModel.defaultValueAttributedString($0)
        }.flatMap {
            .init(title: R.string.localizable.semifungiblesAttributeTransferable(preferredLanguages: Languages.preferred()), attributedValue: $0)
        }
    }

    var meltValueViewModel: TokenInstanceAttributeViewModel? {
        return values?.meltStringValue.flatMap {
            TokenInstanceAttributeViewModel.defaultValueAttributedString($0)
        }.flatMap {
            .init(title: R.string.localizable.semifungiblesAttributeMelt(preferredLanguages: Languages.preferred()), attributedValue: $0)
        }
    }

    var meltFeeRatioViewModel: TokenInstanceAttributeViewModel? {
        return values?.meltFeeRatio.flatMap {
            TokenInstanceAttributeViewModel.defaultValueAttributedString(String($0))
        }.flatMap {
            .init(title: R.string.localizable.semifungiblesAttributeMeltFeeRatio(preferredLanguages: Languages.preferred()), attributedValue: $0)
        }
    }

    var meltFeeMaxRatioViewModel: TokenInstanceAttributeViewModel? {
        return values?.meltFeeMaxRatio.flatMap {
            TokenInstanceAttributeViewModel.defaultValueAttributedString(String($0))
        }.flatMap {
            .init(title: R.string.localizable.semifungiblesAttributeMeltFeeMaxRatio(preferredLanguages: Languages.preferred()), attributedValue: $0)
        }
    }

    var totalSupplyViewModel: TokenInstanceAttributeViewModel? {
        return values?.totalSupplyStringValue.flatMap {
            TokenInstanceAttributeViewModel.defaultValueAttributedString($0)
        }.flatMap {
            .init(title: R.string.localizable.semifungiblesAttributeTotalSupply(preferredLanguages: Languages.preferred()), attributedValue: $0)
        }
    }

    var circulatingSupplyViewModel: TokenInstanceAttributeViewModel? {
        return values?.circulatingSupplyStringValue.flatMap {
            TokenInstanceAttributeViewModel.defaultValueAttributedString($0)
        }.flatMap {
            .init(title: R.string.localizable.semifungiblesAttributeCirculatingSupply(preferredLanguages: Languages.preferred()), attributedValue: $0)
        }
    }

    var reserveViewModel: TokenInstanceAttributeViewModel? {
        return values?.reserve.flatMap {
            TokenInstanceAttributeViewModel.defaultValueAttributedString($0)
        }.flatMap {
            .init(title: R.string.localizable.semifungiblesAttributeReserve(preferredLanguages: Languages.preferred()), attributedValue: $0)
        }
    }

    var nonFungibleViewModel: TokenInstanceAttributeViewModel? {
        return values?.nonFungible.flatMap {
            TokenInstanceAttributeViewModel.defaultValueAttributedString(String($0))
        }.flatMap {
            .init(title: R.string.localizable.semifungiblesAttributeNonFungible(preferredLanguages: Languages.preferred()), attributedValue: $0)
        }
    }

    var availableToMintViewModel: TokenInstanceAttributeViewModel? {
        return values?.mintableSupply.flatMap {
            TokenInstanceAttributeViewModel.defaultValueAttributedString(String($0))
        }.flatMap {
            .init(title: R.string.localizable.semifungiblesAttributeAvailableToMint(preferredLanguages: Languages.preferred()), attributedValue: $0)
        }
    }

    var issuerViewModel: TokenInstanceAttributeViewModel? {
        return values?.issuer.flatMap {
            TokenInstanceAttributeViewModel.defaultValueAttributedString(String($0))
        }.flatMap {
            .init(title: R.string.localizable.semifungiblesAttributeIssuer(preferredLanguages: Languages.preferred()), attributedValue: $0)
        }
    }

    var transferFeeViewModel: TokenInstanceAttributeViewModel? {
        return values?.transferFee.flatMap {
            TokenInstanceAttributeViewModel.defaultValueAttributedString(String($0))
        }.flatMap {
            .init(title: R.string.localizable.semifungiblesAttributeTransferFee(preferredLanguages: Languages.preferred()), attributedValue: $0)
        }
    }

}
