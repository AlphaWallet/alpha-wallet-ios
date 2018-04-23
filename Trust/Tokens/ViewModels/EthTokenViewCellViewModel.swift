// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit
import BigInt

struct EthTokenViewCellViewModel {
    private let shortFormatter = EtherNumberFormatter.short
    private let token: TokenObject
    private let currencyAmount: String?
    let ticker: CoinTicker?

    init(
        token: TokenObject,
        ticker: CoinTicker?,
        currencyAmount: String?
    ) {
        self.token = token
        self.ticker = ticker
        self.currencyAmount = currencyAmount
    }

    var title: String {
        return token.title
    }

    var amount: String {
        return shortFormatter.string(from: BigInt(token.value) ?? BigInt(), decimals: token.decimals)
    }

    var issuer: String {
        return ""
    }

    var blockChainName: String {
        return "Ethereum Blockchain"
    }

    var backgroundColor: UIColor {
        return Colors.appBackground
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

    var borderColor: UIColor {
        return UIColor(red: 236, green: 236, blue: 236)
    }

    var titleFont: UIFont {
        if ScreenChecker().isNarrowScreen() {
            return Fonts.light(size: 22)!
        } else {
            return Fonts.light(size: 25)!
        }
    }

    var subtitleFont: UIFont {
        return Fonts.semibold(size: 10)!
    }

    var textColor: UIColor {
        return Colors.appGrayLabelColor
    }

    var valuePercentageChangeColor: UIColor {
        //TODO must have a different color when depreciate?
        return Colors.appHighlightGreen
    }

    var textValueFont: UIFont {
        return Fonts.semibold(size: 15)!
    }

    var textLabelFont: UIFont {
        return Fonts.regular(size: 10)!
    }

    var valuePercentageChangeValue: String {
        //TODO read from model
        return "+50%"
    }

    var valuePercentageChangePeriod: String {
        return R.string.localizable.aWalletContentsValuePeriodTitle()
    }

    var valueChange: String {
        //TODO read from model
        return "$17,000"
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

    var cellHeight: CGFloat {
        return 164
    }
}
