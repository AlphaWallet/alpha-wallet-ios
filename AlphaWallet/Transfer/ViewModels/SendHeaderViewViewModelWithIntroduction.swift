// Copyright © 2018 Stormbird PTE. LTD.

import UIKit

//TODO remove duplicate of SendHeaderViewViewModel once IFRAME design is clear
struct SendHeaderViewViewModelWithIntroduction {
    private let assetDefinitionStore: AssetDefinitionStore

    let server: RPCServer
    var title = ""
    var ticker: CoinTicker?
    var currencyAmount: String?
    var currencyAmountWithoutSymbol: Double?
    var showAlternativeAmount = false
    var contractAddress: AlphaWallet.Address?

    var issuer: String {
        return ""
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

    var titleColor: UIColor {
        return Screen.TokenCard.Color.title
    }

    var subtitleColor: UIColor {
        return Screen.TokenCard.Color.subtitle
    }

    var titleFont: UIFont {
        return Screen.TokenCard.Font.title
    }

    var subtitleFont: UIFont {
        return Screen.TokenCard.Font.subtitle
    }

    var borderColor: UIColor {
        return UIColor(red: 236, green: 236, blue: 236)
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

    var tbmlIntroductionHtmlString: String {
        guard let contract = contractAddress else { return "" }
        let xmlHandler = XMLHandler(contract: contract, assetDefinitionStore: assetDefinitionStore)
        //Any number works for tokenId here, since it's only used for generating the unique CSS ID
        return wrapWithHtmlViewport(html: xmlHandler.introductionHtmlString, style: "", forTokenId: 1)
    }

    init(server: RPCServer, assetDefinitionStore: AssetDefinitionStore) {
        self.server = server
        self.assetDefinitionStore = assetDefinitionStore
    }
}
