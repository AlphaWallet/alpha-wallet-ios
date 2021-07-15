// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit
import BigInt

struct EthTokenViewCellViewModel {
    private let shortFormatter = EtherNumberFormatter.short
    private let token: TokenObject
    private let currencyAmount: String?
    private let ticker: CoinTicker?
    private let assetDefinitionStore: AssetDefinitionStore
    private let isVisible: Bool
    init(
        token: TokenObject,
        ticker: CoinTicker?,
        currencyAmount: String?,
        assetDefinitionStore: AssetDefinitionStore,
        isVisible: Bool = true
    ) {
        self.token = token
        self.ticker = ticker
        self.currencyAmount = currencyAmount
        self.assetDefinitionStore = assetDefinitionStore
        self.isVisible = isVisible
    }

    private var amount: String {
        return shortFormatter.string(from: BigInt(token.value) ?? BigInt(), decimals: token.decimals)
    }

    private var title: String {
        return token.titleInPluralForm(withAssetDefinitionStore: assetDefinitionStore)
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

    func cryptoValueAttributedString(amount: String) -> NSAttributedString {
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
            return "▲ \(percentageChange24h)%"
        case .depreciate(let percentageChange24h):
            return "▼ \(percentageChange24h)%"
        case .none:
            return "-"
        }
    }

    private var priceChangeUSDValue: String {
        if let result = EthCurrencyHelper(ticker: ticker).valueChanged24h(value: token.optionalDecimalValue) {
            return NumberFormatter.usd.string(from: result) ?? "-"
        } else {
            return "-"
        }
    }

    var priceChangeUSDAttributedString: NSAttributedString {
        return NSAttributedString(string: priceChangeUSDValue, attributes: [
            .foregroundColor: Screen.TokenCard.Color.valueChangeLabel,
            .font: Screen.TokenCard.Font.valueChangeLabel
        ])
    }

    private var amountAccordingRPCServer: String? {
        if token.server.isTestnet {
            return nil
        } else {
            return currencyAmount
        }
    }

    var fiatValueAttributedString: NSAttributedString {
        return NSAttributedString(string: amountAccordingRPCServer ?? "-", attributes: [
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

    func priceChangeUSDAttributedString(ticker: CoinTicker?) -> NSAttributedString {
        return NSAttributedString(string: priceChangeUSDValue, attributes: [
            .foregroundColor: Screen.TokenCard.Color.valueChangeLabel,
            .font: Screen.TokenCard.Font.valueChangeLabel
        ])
    }

    private func amountAccordingRPCServer(currencyAmount: String?) -> String? {
        if token.server.isTestnet {
            return nil
        } else {
            return currencyAmount
        }
    }

    func fiatValueAttributedString(currencyAmount: String?) -> NSAttributedString {
        return NSAttributedString(string: amountAccordingRPCServer(currencyAmount: currencyAmount) ?? "-", attributes: [
            .foregroundColor: Screen.TokenCard.Color.title,
            .font: Screen.TokenCard.Font.valueChangeValue
        ])
    }

    private func priceChangeUSDValue(ticker: CoinTicker?) -> String {
        if let result = EthCurrencyHelper(ticker: ticker).valueChanged24h(value: token.optionalDecimalValue) {
            return NumberFormatter.usd.string(from: result) ?? "-"
        } else {
            return "-"
        }
    }

    func apprecation24hoursBackgroundColor(ticker: CoinTicker?) -> UIColor {
        valuePercentageChangeColor(ticker: ticker).withAlphaComponent(0.07)
    }

    func apprecation24hoursAttributedString(ticker: CoinTicker?) -> NSAttributedString {
        return NSAttributedString(string: " " + valuePercentageChangeValue(ticker: ticker) + " ", attributes: [
            .foregroundColor: valuePercentageChangeColor,
            .font: Screen.TokenCard.Font.valueChangeLabel
        ])
    }

    private func valuePercentageChangeColor(ticker: CoinTicker?) -> UIColor {
        return Screen.TokenCard.Color.valueChangeValue(ticker: ticker)
    }

    private func valuePercentageChangeValue(ticker: CoinTicker?) -> String {
        switch EthCurrencyHelper(ticker: ticker).change24h {
        case .appreciate(let percentageChange24h):
            return "▲ \(percentageChange24h)%"
        case .depreciate(let percentageChange24h):
            return "▼ \(percentageChange24h)%"
        case .none:
            return "-"
        }
    }
}
