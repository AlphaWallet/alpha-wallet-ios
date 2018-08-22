// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit
import BigInt

struct TokenCardViewCellViewModel {
    private let shortFormatter = EtherNumberFormatter.short
    private let token: TokenObject

    let config: Config
    let ticker: CoinTicker?

    init(
        config: Config,
        token: TokenObject,
        ticker: CoinTicker?
    ) {
        self.config = config
        self.token = token
        self.ticker = ticker
    }

    var title: String {
        return token.title
    }

    var amount: String {
        let actualBalance = token.nonZeroBalance
        return actualBalance.count.toString()
    }

    var issuer: String {
        let xmlHandler = XMLHandler(contract: token.address.eip55String)
        let issuer = xmlHandler.getIssuer()
        if issuer.isEmpty {
            return ""
        } else {
            return "\(R.string.localizable.aWalletContentsIssuerTitle()): \(issuer)"
        }
    }

    var issuerSeparator: String {
        if issuer.isEmpty {
            return ""
        } else {
            return "|"
        }
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
