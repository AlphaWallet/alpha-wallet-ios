// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit
import BigInt

struct FungibleTokenViewCellViewModel {
    private let shortFormatter = EtherNumberFormatter.short
    private let token: TokenObject
    private let ticker: CoinTicker?
    private let assetDefinitionStore: AssetDefinitionStore
    private let isVisible: Bool

    init(token: TokenObject, assetDefinitionStore: AssetDefinitionStore, isVisible: Bool = true, ticker: CoinTicker?) {
        self.token = token
        self.ticker = ticker
        self.assetDefinitionStore = assetDefinitionStore
        self.isVisible = isVisible
    }

    private var title: String {
        return token.shortTitleInPluralForm(withAssetDefinitionStore: assetDefinitionStore)
    }

    private var amount: String {
        return shortFormatter.string(from: BigInt(token.value) ?? BigInt(), decimals: token.decimals)
    }

    var backgroundColor: UIColor {
        return Screen.TokenCard.Color.background
    }

    var contentsBackgroundColor: UIColor {
        return Screen.TokenCard.Color.background
    }

    var titleAttributedString: NSAttributedString {
        return NSAttributedString(string: title, attributes: [
            .foregroundColor: Screen.TokenCard.Color.title,
            .font: Screen.TokenCard.Font.title
        ])
    }

    var cryptoValueAttributedString: NSAttributedString {
        return NSAttributedString(string: amount + " " + token.symbolInPluralForm(withAssetDefinitionStore: assetDefinitionStore), attributes: [
            .foregroundColor: Screen.TokenCard.Color.subtitle,
            .font: Screen.TokenCard.Font.subtitle
        ])
    }

    private var valuePercentageChangeColor: UIColor {
        return Screen.TokenCard.Color.valueChangeValue(ticker: ticker)
    }

    var apprecation24hoursBackgroundColor: UIColor {
        valuePercentageChangeColor.withAlphaComponent(0.07)
    }

    var apprecationViewModel: ApprecationViewModel {
        let backgroundColor: UIColor = {
            if apprecation24hoursAttributedString.string.isEmpty {
                return .clear
            } else {
                return apprecation24hoursBackgroundColor
            }
        }()
        return .init(icon: apprecation24hoursImage, valueAttributedString: apprecation24hoursAttributedString, backgroundColor: backgroundColor)
    }

    private var apprecation24hoursAttributedString: NSAttributedString {
        let apprecation24hours: String = {
            switch EthCurrencyHelper(ticker: ticker).change24h {
            case .appreciate(let percentageChange24h):
                return "\(percentageChange24h)%"
            case .depreciate(let percentageChange24h):
                return "\(percentageChange24h)%"
            case .none:
                if priceChangeUSDValue == UiTweaks.noPriceMarker {
                    return UiTweaks.noPriceMarker
                } else {
                    return "-"
                }
            }
        }()

        return NSAttributedString(string: apprecation24hours, attributes: [
            .foregroundColor: valuePercentageChangeColor,
            .font: Screen.TokenCard.Font.valueChangeLabel
        ])
    }

    private var apprecation24hoursImage: UIImage? {
        switch EthCurrencyHelper(ticker: ticker).change24h {
        case .appreciate:
            return R.image.price_up()
        case .depreciate:
            return R.image.price_down()
        case .none:
            return .none
        }
    }

    private var priceChangeUSDValue: String {
        if let result = EthCurrencyHelper(ticker: ticker).valueChanged24h(value: token.optionalDecimalValue) {
            return Formatter.priceChange.string(from: result) ?? UiTweaks.noPriceMarker
        } else {
            return UiTweaks.noPriceMarker
        }
    }

    var priceChangeUSDValueAttributedString: NSAttributedString {
        return NSAttributedString(string: priceChangeUSDValue, attributes: [
            .foregroundColor: valuePercentageChangeColor,
            .font: Screen.TokenCard.Font.valueChangeLabel
        ])
    }

    private var fiatValue: String {
        if let fiatValue = EthCurrencyHelper(ticker: ticker).fiatValue(value: token.optionalDecimalValue) {
            return Formatter.fiat.string(from: fiatValue) ?? UiTweaks.noPriceMarker
        } else {
            return UiTweaks.noPriceMarker
        }
    }

    var fiatValueAttributedString: NSAttributedString {
        return NSAttributedString(string: fiatValue, attributes: [
            .foregroundColor: Screen.TokenCard.Color.title,
            .font: Screen.TokenCard.Font.valueChangeValue
        ])
    }

    var alpha: CGFloat {
        return isVisible ? 1.0 : 0.4
    }

    var iconImage: Subscribable<TokenImage> {
        token.icon(withSize: .s300)
    }

    var blockChainTagViewModel: BlockchainTagLabelViewModel {
        return .init(server: token.server)
    }
}
