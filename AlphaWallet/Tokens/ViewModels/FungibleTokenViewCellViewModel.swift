// Copyright © 2018 Stormbird PTE. LTD.

import UIKit
import AlphaWalletFoundation

struct FungibleTokenViewCellViewModel {
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

        return NSAttributedString(string: apprecation24hours, attributes: [
            .foregroundColor: valuePercentageChangeColor,
            .font: Screen.TokenCard.Font.valueChangeLabel
        ])
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

    private var fiatValue: String {
        if let fiatValue = EthCurrencyHelper(ticker: token.balance.ticker).fiatValue(value: token.valueDecimal) {
            return Formatter.fiat.string(from: fiatValue) ?? UiTweaks.noPriceMarker
        } else {
            return UiTweaks.noPriceMarker
        }
    }

    var fiatValueAttributedString: NSAttributedString {
        return NSAttributedString(string: fiatValue, attributes: [
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
}

extension FungibleTokenViewCellViewModel: Hashable {
    static func == (lhs: FungibleTokenViewCellViewModel, rhs: FungibleTokenViewCellViewModel) -> Bool {
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
