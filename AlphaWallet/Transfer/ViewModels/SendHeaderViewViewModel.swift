// Copyright © 2018 Stormbird PTE. LTD.

import UIKit

struct TokenInfoPageViewModel {

    var tabTitle: String {
        return R.string.localizable.tokenTabInfo()
    }

    private let token: TokenObject
    let transactionType: TransactionType
    let server: RPCServer
    var title: String
    var ticker: CoinTicker?
    var currencyAmount: String?
    var isShowingValue: Bool = true
    var values: [ChartHistory] = []

    init(server: RPCServer, token: TokenObject, transactionType: TransactionType) {
        self.server = server
        self.token = token
        self.transactionType = transactionType
        title = ""
        ticker = nil
        currencyAmount = nil
    }

    private var valuePercentageChangeValue: String? {
        switch EthCurrencyHelper(ticker: ticker).change24h {
        case .appreciate(let percentageChange24h):
            return "(\(percentageChange24h)%)"
        case .depreciate(let percentageChange24h):
            return "(\(percentageChange24h)%)"
        case .none:
            return nil
        }
    }

    var markerCapViewModel: TickerFieldValueViewModel {
        let value: String = {
            if let market_cap = ticker?.market_cap {
                return StringFormatter().largeNumberFormatter(for: market_cap, currency: "USD")
            } else {
                return "-"
            }
        }()

        let attributedValue: NSAttributedString = .init(string: value, attributes: [
            .font: Screen.TokenCard.Font.valueChangeValue,
            .foregroundColor: Colors.black
        ])

        return .init(title: R.string.localizable.tokenInfoFieldStatsMarket_cap(), attributedValue: attributedValue)
    }

    var totalVolumeViewModel: TickerFieldValueViewModel {
        let value: String = {
            if let total_volume = ticker?.total_supply {
                return String(total_volume)
            } else {
                return "-"
            }
        }()

        let attributedValue: NSAttributedString = .init(string: value, attributes: [
            .font: Screen.TokenCard.Font.valueChangeValue,
            .foregroundColor: Colors.black
        ])
        return .init(title: R.string.localizable.tokenInfoFieldStatsTotal_supply(), attributedValue: attributedValue)
    }

    var maxSupplyViewModel: TickerFieldValueViewModel {
        let value: String = {
            if let max_supply = ticker?.max_supply, let value = NumberFormatter.usd.string(from: max_supply) {
                return String(value)
            } else {
                return "-"
            }
        }()

        let attributedValue: NSAttributedString = .init(string: value, attributes: [
            .font: Screen.TokenCard.Font.valueChangeValue,
            .foregroundColor: Colors.black
        ])
        return .init(title: R.string.localizable.tokenInfoFieldStatsMax_supply(), attributedValue: attributedValue)
    }

    var yearLowViewModel: TickerFieldValueViewModel {
        let value: String = {
            let history = values[safe: ChartHistoryPeriod.year.index]
            if let min = HistoryHelper(history: history).minMax?.min, let value = NumberFormatter.usd.string(from: min) {
                return value
            } else {
                return "-"
            }
        }()

        let attributedValue: NSAttributedString = .init(string: value, attributes: [
            .font: Screen.TokenCard.Font.valueChangeValue,
            .foregroundColor: Colors.black
        ])
        return .init(title: R.string.localizable.tokenInfoFieldPerfomanceYearLow(), attributedValue: attributedValue)
    }

    var yearHighViewModel: TickerFieldValueViewModel {
        let value: String = {
            let history = values[safe: ChartHistoryPeriod.year.index]
            if let max = HistoryHelper(history: history).minMax?.max, let value = NumberFormatter.usd.string(from: max) {
                return value
            } else {
                return "-"
            }
        }()

        let attributedValue: NSAttributedString = .init(string: value, attributes: [
            .font: Screen.TokenCard.Font.valueChangeValue,
            .foregroundColor: Colors.black
        ])
        return .init(title: R.string.localizable.tokenInfoFieldPerfomanceYearHigh(), attributedValue: attributedValue)
    }

    var yearViewModel: TickerFieldValueViewModel {
        let attributedValue: NSAttributedString = attributedHistoryValue(period: ChartHistoryPeriod.year)
        return .init(title: R.string.localizable.tokenInfoFieldStatsYear(), attributedValue: attributedValue)
    }

    var monthViewModel: TickerFieldValueViewModel {
        let attributedValue: NSAttributedString = attributedHistoryValue(period: ChartHistoryPeriod.month)
        return .init(title: R.string.localizable.tokenInfoFieldStatsMonth(), attributedValue: attributedValue)
    }

    var weekViewModel: TickerFieldValueViewModel {
        let attributedValue: NSAttributedString = attributedHistoryValue(period: ChartHistoryPeriod.week)
        return .init(title: R.string.localizable.tokenInfoFieldStatsWeek(), attributedValue: attributedValue)
    }

    var dayViewModel: TickerFieldValueViewModel {
        let attributedValue: NSAttributedString = attributedHistoryValue(period: ChartHistoryPeriod.day)
        return .init(title: R.string.localizable.tokenInfoFieldStatsDay(), attributedValue: attributedValue)
    }

    private func attributedHistoryValue(period: ChartHistoryPeriod) -> NSAttributedString {
        let result: (String, UIColor) = {
            let result = HistoryHelper(history: values[safe: period.index])

            switch result.change {
            case .appreciate(let percentage, let value):
                let p = NumberFormatter.percent.string(from: percentage) ?? "-"
                let v = NumberFormatter.usd.string(from: value) ?? "-"

                return ("\(v) (\(p)%)", Colors.appActionButtonGreen)
            case .depreciate(let percentage, let value):
                let p = NumberFormatter.percent.string(from: percentage) ?? "-"
                let v = NumberFormatter.usd.string(from: value) ?? "-"

                return ("\(v) (\(p)%)", Colors.appRed)
            case .none:
                return ("-", Colors.black)
            }
        }()

        return .init(string: result.0, attributes: [
            .font: Screen.TokenCard.Font.valueChangeValue,
            .foregroundColor: result.1
        ])
    }

    var backgroundColor: UIColor {
        return Screen.TokenCard.Color.background
    }

    var iconImage: Subscribable<TokenImage> {
        token.icon
    }

    var blockChainTagViewModel: BlockchainTagLabelViewModel {
        .init(server: server)
    }

    var titleAttributedString: NSAttributedString {
        return NSAttributedString(string: title, attributes: [
            .font: Fonts.regular(size: ScreenChecker().isNarrowScreen ? 26 : 36),
            .foregroundColor: Colors.black
        ])
    }

    var valueAttributedString: NSAttributedString? {
        if server.isTestnet {
            return nil
        } else {
            switch transactionType {
            case .nativeCryptocurrency, .ERC20Token:
                if isShowingValue {
                    return tokenValueAttributedString
                } else {
                    return marketPriceAttributedString
                }
            case .ERC875Token, .ERC875TokenOrder, .ERC721Token, .ERC721ForTicketToken, .dapp, .tokenScript, .claimPaidErc875MagicLink:
                return nil
            }
        }
    }

    private var tokenValueAttributedString: NSAttributedString? {
        let string = R.string.localizable.aWalletTokenValue(currencyAmount ?? "-")

        return NSAttributedString(string: string, attributes: [
            .font: Screen.TokenCard.Font.placeholderLabel,
            .foregroundColor: R.color.dove()!
        ])
    }

    private var marketPriceAttributedString: NSAttributedString? {
        guard let marketPrice = marketPriceValue, let valuePercentageChange = valuePercentageChangeValue else {
            return nil
        }

        let string = R.string.localizable.aWalletTokenMarketPrice(marketPrice, valuePercentageChange)

        guard let valuePercentageChangeRange = string.range(of: valuePercentageChange) else { return nil }

        let mutableAttributedString = NSMutableAttributedString(string: string, attributes: [
            .font: Screen.TokenCard.Font.placeholderLabel,
            .foregroundColor: R.color.dove()!
        ])

        let range = NSRange(valuePercentageChangeRange, in: string)
        mutableAttributedString.setAttributes([
            .font: Fonts.semibold(size: ScreenChecker().isNarrowScreen ? 14 : 17),
            .foregroundColor: Screen.TokenCard.Color.valueChangeValue(ticker: ticker)
        ], range: range)

        return mutableAttributedString
    }

    private var marketPriceValue: String? {
        if let value = EthCurrencyHelper(ticker: ticker).marketPrice {
            return NumberFormatter.usd.string(from: value)
        } else {
            return nil
        }
    }
}

struct HistoryHelper {

    enum Change {
        case appreciate(percentage: Double, value: Double)
        case depreciate(percentage: Double, value: Double)
        case none
    }

    private let history: ChartHistory?

    init(history: ChartHistory?) {
        self.history = history
    }

    var minMax: (min: Double, max: Double)? {
        guard let history = history else { return nil }
        guard let min = history.prices.min(by: { $0.value < $1.value }), let max = history.prices.max(by: { $0.value < $1.value }) else { return nil }

        return (min.value, max.value)
    }

    var change: HistoryHelper.Change {
        changeValues.flatMap { values -> HistoryHelper.Change in
            if isValueAppreciated24h(values.percentage) {
                return .appreciate(percentage: values.percentage, value: values.change)
            } else if isValueDepreciated24h(values.percentage) {
                return .depreciate(percentage: values.percentage, value: values.change)
            } else {
                return .none
            }
        } ?? .none
    }

    private var changeValues: (change: Double, percentage: Double)? {
        history.flatMap { history -> (Double, Double)? in
            let value = history.prices
            if value.isEmpty { return nil }

            var changeSum: Double = 0
            var percChangeSum: Double = 0
            for i in 0 ..< value.count - 1 {
                let change = value[i+1].value - value[i].value

                changeSum += change
                percChangeSum += change / value[i+1].value
            }
            return (changeSum, percChangeSum * 100)
        }
    }

    private func isValueAppreciated24h(_ value: Double?) -> Bool {
        if let percentChange = value {
            return percentChange > 0
        } else {
            return false
        }
    }

    private func isValueDepreciated24h(_ value: Double?) -> Bool {
        if let percentChange = value {
            return percentChange < 0
        } else {
            return false
        }
    }
}
