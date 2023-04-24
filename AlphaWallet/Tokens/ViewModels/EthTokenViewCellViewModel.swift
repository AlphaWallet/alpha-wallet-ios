// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit
import BigInt
import AlphaWalletFoundation
import Combine

struct EthTokenViewCellViewModel: TokenIdentifiable {
    private let safeShortTitleInPluralForm: String
    private let amountShort: String
    private let symbolInPluralForm: String
    private let ticker: CoinTicker?
    private let valueDecimal: Decimal
    private let isVisible: Bool
    private let amountInFiat: Double?

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
        self.amountInFiat = token.balance.amountInFiat
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

    private var apprecation24hoursBackgroundColor: UIColor {
        valuePercentageChangeColor.withAlphaComponent(0.07)
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

    private var apprecation24hoursAttributedString: NSAttributedString {
        let changePercentage: String = {
            guard let ticker = ticker else { return UiTweaks.noPriceMarker }

            let helper = TickerHelper(ticker: ticker)
            let formatter = NumberFormatter.percent

            switch helper.change24h {
            case .appreciate(let percentageChange24h):
                return "\(formatter.string(double: percentageChange24h) ?? "")%"
            case .depreciate(let percentageChange24h):
                return "\(formatter.string(double: percentageChange24h) ?? "")%"
            case .none:
                return UiTweaks.noPriceMarker
            }
        }()

        return NSAttributedString(string: changePercentage, attributes: [
            .foregroundColor: valuePercentageChangeColor,
            .font: Screen.TokenCard.Font.valueChangeLabel
        ])
    }

    private var priceChange: String {
        guard let ticker = ticker else { return UiTweaks.noPriceMarker }
        let formatter = NumberFormatter.priceChange(currency: ticker.currency)

        if let result = TickerHelper(ticker: ticker).valueChanged24h(value: valueDecimal) {
            return formatter.string(double: result) ?? UiTweaks.noPriceMarker
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
        let amountAccordingRPCServer: String? = {
            if server.isTestnet {
                return UiTweaks.noPriceMarker
            } else {
                //FIXME: refactor this, maybe remove `amountInFiat`
                guard let ticker = ticker else { return UiTweaks.noPriceMarker }
                let formatter = NumberFormatter.fiatShort(currency: ticker.currency)

                return amountInFiat.flatMap { formatter.string(double: $0) } ?? UiTweaks.noPriceMarker
            }
        }()

        return NSAttributedString(string: amountAccordingRPCServer ?? UiTweaks.noPriceMarker, attributes: [
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

    private func amountAccordingRPCServer(currencyAmount: String?) -> String? {
        if server.isTestnet {
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

    func apprecation24hoursBackgroundColor(ticker: CoinTicker?) -> UIColor {
        valuePercentageChangeColor(ticker: ticker).withAlphaComponent(0.07)
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

    private func valuePercentageChangeColor(ticker: CoinTicker?) -> UIColor {
        return Screen.TokenCard.Color.valueChangeValue(ticker: ticker)
    }
}

extension EthTokenViewCellViewModel: Hashable { }

extension AnyPublisher: Equatable {
    public static func == (lhs: AnyPublisher, rhs: AnyPublisher) -> Bool {
        return true
    }
}

extension AnyPublisher: Hashable {
    public func hash(into hasher: inout Hasher) {
        //no-op
    }
}
