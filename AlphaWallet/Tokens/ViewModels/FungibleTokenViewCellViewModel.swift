// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit
import BigInt

struct FungibleTokenViewCellViewModel {
    private let shortFormatter = EtherNumberFormatter.short
    private let token: TokenObject
    private let server: RPCServer
    private let assetDefinitionStore: AssetDefinitionStore
    private let isVisible: Bool
    private let ticker: CoinTicker?

    init(token: TokenObject, server: RPCServer, assetDefinitionStore: AssetDefinitionStore, isVisible: Bool = true, ticker: CoinTicker?) {
        self.token = token
        self.server = server
        self.assetDefinitionStore = assetDefinitionStore
        self.isVisible = isVisible
        self.ticker = ticker
    }

    var title: String {
        return token.titleInPluralForm(withAssetDefinitionStore: assetDefinitionStore)
    }

    var amount: String {
        return shortFormatter.string(from: BigInt(token.value) ?? BigInt(), decimals: token.decimals)
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

    var alpha: CGFloat {
        return isVisible ? 1.0 : 0.4
    }

    var iconImage: Subscribable<TokenImage> {
        token.icon
    }

    var blockChainTagViewModel: BlockchainTagLabelViewModel {
        return .init(server: server)
    }

    var valuePercentageChangeColor: UIColor {
        return Screen.TokenCard.Color.valueChangeValue(ticker: ticker)
    }

    var textValueFont: UIFont {
        return Screen.TokenCard.Font.valueChangeLabel
    }

    var textLabelFont: UIFont {
        return Screen.TokenCard.Font.valueChangeLabel
    }

    var valuePercentageChangeValue: String {
        switch EthCurrencyHelper(ticker: ticker).change24h {
        case .appreciate(let percentageChange24h):
            return "(\(percentageChange24h)%)"
        case .depreciate(let percentageChange24h):
            return "(\(percentageChange24h)%)"
        case .none:
            return "-"
        }
    }

    var marketPriceValue: String? {
        if let value = EthCurrencyHelper(ticker: ticker).marketPrice {
            return NumberFormatter.usd.string(from: value)
        } else {
            return nil
        }
    }

    var textColor: UIColor {
        return Screen.TokenCard.Color.valueChangeLabel
    }

}
