// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit
import BigInt

struct EthTokenViewCellViewModel {
    private let shortFormatter = EtherNumberFormatter.short
    private let token: TokenObject
    private let currencyAmount: String?
    private let currencyAmountWithoutSymbol: Double?
    private let ticker: CoinTicker?
    private let server: RPCServer
    private let assetDefinitionStore: AssetDefinitionStore
    private let isVisible: Bool
    init(
        token: TokenObject,
        ticker: CoinTicker?,
        currencyAmount: String?,
        currencyAmountWithoutSymbol: Double?,
        server: RPCServer,
        assetDefinitionStore: AssetDefinitionStore,
        isVisible: Bool = true
    ) {
        self.token = token
        self.ticker = ticker
        self.currencyAmount = currencyAmount
        self.currencyAmountWithoutSymbol = currencyAmountWithoutSymbol
        self.server = server
        self.assetDefinitionStore = assetDefinitionStore
        self.isVisible = isVisible
    }

    var title: String {
        return token.titleInPluralForm(withAssetDefinitionStore: assetDefinitionStore)
    }

    var amount: String {
        return shortFormatter.string(from: BigInt(token.value) ?? BigInt(), decimals: token.decimals)
    }

    var issuer: String {
        return ""
    }

    var blockChainNameFont: UIFont {
        return Screen.TokenCard.Font.blockChainName
    }

    var blockChainNameColor: UIColor {
        return Screen.TokenCard.Color.blockChainName
    }

    var blockChainNameBackgroundColor: UIColor {
        return server.blockChainNameColor
    }

    var blockChainTag: String {
        return "  \(server.name)     "
    }

    var blockChainNameTextAlignment: NSTextAlignment {
        return .center
    }

    var blockChainNameCornerRadius: CGFloat {
        return Screen.TokenCard.Metric.blockChainTagCornerRadius
    }

    var blockChainName: String {
        return server.blockChainName
    }

    var backgroundColor: UIColor {
        return Screen.TokenCard.Color.background
    }

    var contentsBackgroundColor: UIColor {
        return Screen.TokenCard.Color.background
    }

    var contentsCornerRadius: CGFloat {
        return Metrics.CornerRadius.box
    }

    var titleColor: UIColor {
        return Screen.TokenCard.Color.title
    }

    var subtitleColor: UIColor {
        return Screen.TokenCard.Color.subtitle
    }

    var borderColor: UIColor {
        return UIColor(red: 236, green: 236, blue: 236)
    }

    var titleFont: UIFont {
        return Screen.TokenCard.Font.title
    }

    var subtitleFont: UIFont {
        return Screen.TokenCard.Font.subtitle
    }

    var textColor: UIColor {
        return Screen.TokenCard.Color.valueChangeLabel
    }

    var valuePercentageChangeColor: UIColor {
        return Screen.TokenCard.Color.valueChangeValue(ticker: ticker)
    }

    var textValueFont: UIFont {
        return Screen.TokenCard.Font.valueChangeValue
    }

    var textLabelFont: UIFont {
        return Screen.TokenCard.Font.valueChangeLabel
    }

    var valuePercentageChangeValue: String {
        switch EthCurrencyHelper(ticker: ticker).change24h {
        case .appreciate(let percentageChange24h):
            return "\(percentageChange24h)%"
        case .depreciate(let percentageChange24h):
            return "\(percentageChange24h)%"
        case .none:
            return "-"
        }
    }

    var valuePercentageChangePeriod: String {
        return R.string.localizable.aWalletContentsValuePeriodTitle()
    }

    var valueChange: String {
        if let value = EthCurrencyHelper(ticker: ticker).valueChanged24h(currencyAmountWithoutSymbol: currencyAmountWithoutSymbol) {
            return value
        } else {
            return "-"
        }
    }

    var valueChangeName: String {
        return R.string.localizable.aWalletContentsValueAppreciationTitle()
    }

    var value: String {
        if let currencyAmount = currencyAmount {
            return currencyAmount
        } else {
            return "-"
        }
    }

    var valueName: String {
        return R.string.localizable.aWalletContentsValueDollarTitle()
    }

    var alpha: CGFloat {
        return isVisible ? 1.0 : 0.4
    }
}
