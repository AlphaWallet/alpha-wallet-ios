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
        let actualBalance = self.token.balance.filter { $0.balance != Constants.nullTicket }
        return actualBalance.count.toString()
    }

    var issuer: String {
        return "\(R.string.localizable.aWalletContentsIssuerTitle()): \(R.string.localizable.ticketIssuer())"
    }

    var blockChainName: String {
        return R.string.localizable.blockchainEthereum()
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
        if ScreenChecker().isNarrowScreen() {
            return Fonts.light(size: 22)!
        } else {
            return Fonts.light(size: 25)!
        }

    }

    var subtitleFont: UIFont {
        return Fonts.semibold(size: 10)!
    }

    var cellHeight: CGFloat {
        return 98
    }
}
