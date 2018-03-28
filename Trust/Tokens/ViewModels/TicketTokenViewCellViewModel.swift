// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit
import BigInt

struct TicketTokenViewCellViewModel {
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
        return R.string.localizable.aWalletTickets(actualBalance.count.toString())
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

    var cellHeight: CGFloat {
        return 130
    }
}
