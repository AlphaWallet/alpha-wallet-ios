// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit
import BigInt
import AlphaWalletFoundation

struct EthTokenViewCellViewModel {
    private let token: TokenViewModel
    private let isVisible: Bool
    let accessoryType: UITableViewCell.AccessoryType

    init(token: TokenViewModel, isVisible: Bool = true, accessoryType: UITableViewCell.AccessoryType = .none) {
        self.token = token
        self.isVisible = isVisible
        self.accessoryType = accessoryType
    }

    var backgroundColor: UIColor {
        return Screen.TokenCard.Color.background
    }

    var contentsBackgroundColor: UIColor {
        return Configuration.Color.Semantic.tableViewCellBackground
    }

    var titleAttributedString: NSAttributedString {
        return NSAttributedString(string: token.tokenScriptOverrides?.safeShortTitleInPluralForm ?? "", attributes: [
            .foregroundColor: Configuration.Color.Semantic.defaultForegroundText,
            .font: Screen.TokenCard.Font.title
        ])
    }

    var cryptoValueAttributedString: NSAttributedString {
        return NSAttributedString(string: token.balance.amountShort + " " + (token.tokenScriptOverrides?.symbolInPluralForm ?? ""), attributes: [
            .foregroundColor: Configuration.Color.Semantic.defaultSubtitleText,
            .font: Screen.TokenCard.Font.subtitle
        ])
    }

    private var valuePercentageChangeColor: UIColor {
        return Screen.TokenCard.Color.valueChangeValue(ticker: token.balance.ticker)
    }

    private var apprecation24hoursBackgroundColor: UIColor {
        valuePercentageChangeColor.withAlphaComponent(0.07)
    }

    private var apprecation24hoursImage: UIImage? {
        switch EthCurrencyHelper(ticker: token.balance.ticker).change24h {
        case .appreciate:
            return R.image.price_up()
        case .depreciate:
            return R.image.price_down()
        case .none:
            return .none
        }
    }

    private var apprecation24hoursAttributedString: NSAttributedString {
        let valuePercentageChangeValue: String = {
            switch EthCurrencyHelper(ticker: token.balance.ticker).change24h {
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

        return NSAttributedString(string: valuePercentageChangeValue, attributes: [
            .foregroundColor: valuePercentageChangeColor,
            .font: Screen.TokenCard.Font.valueChangeLabel
        ])
    }

    private var priceChangeUSDValue: String {
        if let result = EthCurrencyHelper(ticker: token.balance.ticker).valueChanged24h(value: token.valueDecimal) {
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

    private var amountAccordingRPCServer: String? {
        if token.server.isTestnet {
            return UiTweaks.noPriceMarker
        } else {
            return token.balance.currencyAmountWithoutSymbol.flatMap { Formatter.fiat.string(from: $0) ?? UiTweaks.noPriceMarker }
        }
    }

    var fiatValueAttributedString: NSAttributedString {
        return NSAttributedString(string: amountAccordingRPCServer ?? UiTweaks.noPriceMarker, attributes: [
            .foregroundColor: Configuration.Color.Semantic.defaultForegroundText,
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
        if let result = EthCurrencyHelper(ticker: ticker).valueChanged24h(value: token.valueDecimal) {
            return Formatter.usd.string(from: result) ?? "-"
        } else {
            return "-"
        }
    }

    func apprecation24hoursBackgroundColor(ticker: CoinTicker?) -> UIColor {
        valuePercentageChangeColor(ticker: ticker).withAlphaComponent(0.07)
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

    private func valuePercentageChangeColor(ticker: CoinTicker?) -> UIColor {
        return Screen.TokenCard.Color.valueChangeValue(ticker: ticker)
    }
}

extension EthTokenViewCellViewModel: Hashable {
    static func == (lhs: EthTokenViewCellViewModel, rhs: EthTokenViewCellViewModel) -> Bool {
        return lhs.token == rhs.token &&
            lhs.token.tokenScriptOverrides?.safeShortTitleInPluralForm == rhs.token.tokenScriptOverrides?.shortTitleInPluralForm &&
            lhs.token.tokenScriptOverrides?.symbolInPluralForm == rhs.token.tokenScriptOverrides?.symbolInPluralForm &&
            lhs.token.valueDecimal == rhs.token.valueDecimal &&
            lhs.token.balance.ticker == rhs.token.balance.ticker
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(isVisible)
        hasher.combine(accessoryType)
        hasher.combine(token.contractAddress)
        hasher.combine(token.server)
        hasher.combine(token.tokenScriptOverrides?.safeShortTitleInPluralForm)
        hasher.combine(token.tokenScriptOverrides?.symbolInPluralForm)
        hasher.combine(token.valueDecimal)
        hasher.combine(token.balance.ticker)
    }
}
