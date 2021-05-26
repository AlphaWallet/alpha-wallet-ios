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
        return token.titleInPluralForm(withAssetDefinitionStore: assetDefinitionStore)
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

    var apprecation24hoursAttributedString: NSAttributedString {
        return NSAttributedString(string: " " + valuePercentageChangeValue + " ", attributes: [
            .foregroundColor: valuePercentageChangeColor,
            .font: Screen.TokenCard.Font.valueChangeLabel
        ])
    }

    private var valuePercentageChangeValue: String {
        switch EthCurrencyHelper(ticker: ticker).change24h {
        case .appreciate(let percentageChange24h):
            return "▲ (\(percentageChange24h)%)"
        case .depreciate(let percentageChange24h):
            return "▼ (\(percentageChange24h)%)"
        case .none:
            return "-"
        }
    }

    private var marketPriceValue: String {
        if let value = EthCurrencyHelper(ticker: ticker).marketPrice {
            return NumberFormatter.usd.string(from: value) ?? "-"
        } else {
            return "-"
        }
    }

    var marketPriceAttributedString: NSAttributedString {
        return NSAttributedString(string: marketPriceValue, attributes: [
            .foregroundColor: Screen.TokenCard.Color.valueChangeLabel,
            .font: Screen.TokenCard.Font.valueChangeLabel
        ])
    }
    
    private var fiatValue: String {
        let amount = EtherNumberFormatter.plain.string(from: BigInt(token.value) ?? BigInt(), decimals: token.decimals)
        if let value = amount.optionalDecimalValue, let ticker = ticker {
            let fiatValue = value.doubleValue * ticker.price_usd
            return NumberFormatter.usd.string(from: fiatValue) ?? "-"
        } else {
            return "-"
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
        token.icon
    }

    var blockChainTagViewModel: BlockchainTagLabelViewModel {
        return .init(server: token.server)
    }
}
