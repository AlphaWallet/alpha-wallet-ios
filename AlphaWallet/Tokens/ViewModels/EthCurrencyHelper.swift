// Copyright © 2018 Stormbird PTE. LTD.

import Foundation

class EthCurrencyHelper {
    enum Change24h {
        case appreciate(percentageChange24h: Double)
        case depreciate(percentageChange24h: Double)
        case none
    }
    private var ticker: CoinTicker?

    var change24h: Change24h {
        if let value = percentageChange24h {
            if isValueAppreciated24h {
                return .appreciate(percentageChange24h: value)
            } else if isValueDepreciated24h {
                return .depreciate(percentageChange24h: value)
            } else {
                return .none
            }
        } else {
            return .none
        }
    }

    private var percentageChange24h: Double? {
        if let percent_change_24h = ticker?.percent_change_24h {
            return percent_change_24h.rounded(to: 2)
        } else {
            return nil
        }
    }

    private var isValueAppreciated24h: Bool {
        if let percentChange = percentageChange24h {
            return percentChange > 0
        } else {
            return false
        }
    }

    private var isValueDepreciated24h: Bool {
        if let percentChange = percentageChange24h {
            return percentChange < 0
        } else {
            return false
        }
    }

    public func valueChanged24h(currencyAmountWithoutSymbol: Double?) -> String? {
        if let percentChange = percentageChange24h, let value = currencyAmountWithoutSymbol {
            return NumberFormatter.usd.string(from: value * percentChange / 100)
        } else {
            return nil
        }
    }

    init(ticker: CoinTicker?) {
        self.ticker = ticker
    }
}

