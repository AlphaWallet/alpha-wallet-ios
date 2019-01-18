// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit
import BigInt

struct NonFungibleTokenViewCellViewModel {
    private let token: TokenObject
    private let chainId: Int

    init(token: TokenObject, chainId: Int) {
        self.token = token
        self.chainId = chainId
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
        if chainId == 100 {
            //xdai network, can create switch statement in future if supporting many chains
            return R.string.localizable.blockchainXDAI()
        } else {
            return R.string.localizable.blockchainEthereum()
        }
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
