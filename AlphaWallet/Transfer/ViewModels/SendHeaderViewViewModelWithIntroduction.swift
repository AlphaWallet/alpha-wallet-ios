// Copyright © 2018 Stormbird PTE. LTD.

import UIKit

//TODO remove duplicate of SendHeaderViewViewModel once IFRAME design is clear
struct SendHeaderViewViewModelWithIntroduction {
    var title = ""
    var ticker: CoinTicker?
    var currencyAmount: String?
    var currencyAmountWithoutSymbol: Double?
    var showAlternativeAmount = false
    var contractAddress: String?
    let server: RPCServer

    var issuer: String {
        return ""
    }

    var blockChainName: String {
        switch server {
        case .xDai:
            return R.string.localizable.blockchainXDAI()
        case .rinkeby, .ropsten, .main, .custom, .callisto, .classic, .kovan, .sokol, .poa:
            return R.string.localizable.blockchainEthereum()
        }
    }

    var backgroundColor: UIColor {
        return Colors.appWhite
    }

    var contentsBackgroundColor: UIColor {
        return Colors.appWhite
    }

    var titleColor: UIColor {
        return Colors.appText
    }

    var subtitleColor: UIColor {
        return Colors.appBackground
    }

    var titleFont: UIFont {
        return Fonts.light(size: 25)!
    }

    var subtitleFont: UIFont {
        return Fonts.semibold(size: 10)!
    }
    
    var borderColor: UIColor {
        return UIColor(red: 236, green: 236, blue: 236)
    }

    var textColor: UIColor {
        return Colors.appGrayLabelColor
    }

    var valuePercentageChangeColor: UIColor {
        switch EthCurrencyHelper(ticker: ticker).change24h {
        case .appreciate:
            return Colors.appHighlightGreen
        case .depreciate:
            return Colors.appRed
        case .none:
            return Colors.appGrayLabelColor
        }
    }

    var textValueFont: UIFont {
        return Fonts.semibold(size: 15)!
    }

    var textLabelFont: UIFont {
        return Fonts.regular(size: 10)!
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

    var tbmlIntroductionHtmlString: String {
        guard let contract = contractAddress else { return "" }
        let xmlHandler = XMLHandler(contract: contract)
        return wrapWithHtmlViewport(xmlHandler.introductionHtmlString)
    }

    private func wrapWithHtmlViewport(_ html: String) -> String {
        if html.isEmpty {
            return ""
        } else {
            return """
                   <html>
                   <head>
                   <meta name="viewport" content="width=device-width, initial-scale=1, shrink-to-fit=no">
                   </head>
                   \(html)
                   </html>
                   """
        }
    }

    init(server: RPCServer) {
        self.server = server
    }
}
