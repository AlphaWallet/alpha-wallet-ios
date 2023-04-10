// Copyright © 2018 Stormbird PTE. LTD.

import UIKit
import AlphaWalletFoundation
import Combine

struct FungibleTokenViewCellViewModel: TokenIdentifiable {
    private let safeShortTitleInPluralForm: String
    private let amountShort: String
    private let symbolInPluralForm: String
    private let ticker: CoinTicker?
    private let valueDecimal: Decimal
    private let isVisible: Bool

    let type: TokenType
    let contractAddress: AlphaWallet.Address
    let server: RPCServer
    let iconImage: TokenImagePublisher
    let accessoryType: UITableViewCell.AccessoryType

    init(token: TokenViewModel,
         isVisible: Bool = true,
         accessoryType: UITableViewCell.AccessoryType = .none,
         tokenImageFetcher: TokenImageFetcher) {

        self.type = token.type
        self.safeShortTitleInPluralForm = token.tokenScriptOverrides?.safeShortTitleInPluralForm ?? ""
        self.amountShort = token.balance.amountShort
        self.symbolInPluralForm = token.tokenScriptOverrides?.symbolInPluralForm ?? ""
        self.ticker = token.balance.ticker
        self.contractAddress = token.contractAddress
        self.server = token.server
        self.valueDecimal = token.balance.valueDecimal
        self.iconImage = tokenImageFetcher.image(token: token, size: .s300)
        self.isVisible = isVisible
        self.accessoryType = accessoryType
    }

    var titleAttributedString: NSAttributedString {
        return NSAttributedString(string: safeShortTitleInPluralForm, attributes: [
            .foregroundColor: Configuration.Color.Semantic.defaultForegroundText,
            .font: Screen.TokenCard.Font.title
        ])
    }

    var cryptoValueAttributedString: NSAttributedString {
        return NSAttributedString(string: amountShort + " " + symbolInPluralForm, attributes: [
            .foregroundColor: Configuration.Color.Semantic.defaultSubtitleText,
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
            if apprecation24hoursAttributedString.string.trimmed.isEmpty {
                return .clear
            } else {
                return apprecation24hoursBackgroundColor
            }
        }()
        return .init(icon: apprecation24hoursImage, valueAttributedString: apprecation24hoursAttributedString, backgroundColor: backgroundColor)
    }

    private var apprecation24hoursAttributedString: NSAttributedString {
        let apprecation24hours: String = {
            guard let ticker = ticker else { return UiTweaks.noPriceMarker }

            let formatter = NumberFormatter.percent
            switch TickerHelper(ticker: ticker).change24h {
            case .appreciate(let percentageChange24h):
                return "\(formatter.string(double: percentageChange24h) ?? "")%"
            case .depreciate(let percentageChange24h):
                return "\(formatter.string(double: percentageChange24h) ?? "")%"
            case .none:
                if priceChange == UiTweaks.noPriceMarker {
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
        switch TickerHelper(ticker: ticker).change24h {
        case .appreciate:
            return R.image.price_up()
        case .depreciate:
            return R.image.price_down()
        case .none:
            return .none
        }
    }

    private var priceChange: String {
        guard let ticker = ticker else { return UiTweaks.noPriceMarker }

        if let result = TickerHelper(ticker: ticker).valueChanged24h(value: valueDecimal) {
            return NumberFormatter.priceChange(currency: ticker.currency).string(double: result) ?? UiTweaks.noPriceMarker
        } else {
            return UiTweaks.noPriceMarker
        }
    }

    var priceChangeAttributedString: NSAttributedString {
        return NSAttributedString(string: priceChange, attributes: [
            .foregroundColor: valuePercentageChangeColor,
            .font: Screen.TokenCard.Font.valueChangeLabel
        ])
    }

    var fiatValueAttributedString: NSAttributedString {
        let fiatValue: String = {
            guard let ticker = ticker else { return UiTweaks.noPriceMarker }

            if let fiatValue = TickerHelper(ticker: ticker).fiatValue(value: valueDecimal) {
                return NumberFormatter.fiatShort(currency: ticker.currency).string(double: fiatValue) ?? UiTweaks.noPriceMarker
            } else {
                return UiTweaks.noPriceMarker
            }
        }()

        return NSAttributedString(string: fiatValue, attributes: [
            .foregroundColor: Configuration.Color.Semantic.defaultForegroundText,
            .font: Screen.TokenCard.Font.valueChangeValue
        ])
    }

    var alpha: CGFloat {
        return isVisible ? 1.0 : 0.4
    }

    var blockChainTagViewModel: BlockchainTagLabelViewModel {
        return .init(server: server)
    }
}

extension FungibleTokenViewCellViewModel: Hashable { }
