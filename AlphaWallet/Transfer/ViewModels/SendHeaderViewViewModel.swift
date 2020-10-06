// Copyright © 2018 Stormbird PTE. LTD.

import UIKit

struct SendHeaderViewViewModel {
    private let token: TokenObject
    private let transferType: TransferType
    let server: RPCServer
    var title: String
    var ticker: CoinTicker?
    var currencyAmount: String?
    var isShowingValue: Bool = true

    init(server: RPCServer, token: TokenObject, transferType: TransferType) {
        self.server = server
        self.token = token
        self.transferType = transferType
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
            .font: Fonts.regular(size: ScreenChecker().isNarrowScreen ? 26 : 36)!,
            .foregroundColor: Colors.black
        ])
    }

    var valueAttributedString: NSAttributedString? {
        if server.isTestnet {
            return nil
        } else {
            switch transferType {
            case .nativeCryptocurrency:
                if isShowingValue {
                    return tokenValueAttributedString
                } else {
                    return marketPriceAttributedString
                }
            case .ERC20Token, .ERC875Token, .ERC875TokenOrder, .ERC721Token, .ERC721ForTicketToken, .dapp:
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
            .font: Fonts.semibold(size: ScreenChecker().isNarrowScreen ? 14 : 17)!,
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
