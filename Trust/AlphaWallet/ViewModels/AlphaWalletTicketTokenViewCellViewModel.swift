// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit
import BigInt

struct AlphaWalletTicketTokenViewCellViewModel {
    private let shortFormatter = EtherNumberFormatter.short
    private let token: TokenObject
    let ticker: CoinTicker?

    init(
        token: TokenObject,
        ticker: CoinTicker?
    ) {
        self.token = token
        self.ticker = ticker
    }

    var title: String {
        return token.title
    }

    var amount: String {
        let actualBalance = self.token.balance.filter { $0.balance != 0 }
        return actualBalance.count.toString() + " Tickets"
    }

    var issuer: String {
        return "\(R.string.localizable.aWalletContentsIssuerTitle()): Shengkai"
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
        return UIColor(red: 155, green: 155, blue: 155)
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
        //TODO read from model
        return "$51,000"
    }

    var valueName: String {
        return R.string.localizable.aWalletContentsValueDollarTitle()
    }

    var cellHeight: CGFloat {
        return 196
    }
}
