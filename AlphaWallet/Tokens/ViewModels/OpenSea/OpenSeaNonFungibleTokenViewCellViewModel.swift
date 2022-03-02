// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit

class OpenSeaNonFungibleTokenViewCellViewModel {
    private let token: TokenObject
    var tokenAddress: AlphaWallet.Address {
        token.contractAddress
    }
    private var title: String {
        return token.name
    }

    private var amount: String {
        let actualBalance = token.nonZeroBalance
        return actualBalance.count.toString()
    }

    var tickersAmountAttributedString: NSAttributedString {
        return .init(string: "\(amount) \(token.symbol)", attributes: [
            .font: Fonts.regular(size: 15),
            .foregroundColor: R.color.dove()!
        ])
    }

    var tickersTitleAttributedString: NSAttributedString {
        return .init(string: title, attributes: [
            .font: Fonts.regular(size: 20),
            .foregroundColor: Colors.appText
        ])
    }
    var tokenIcon: Subscribable<TokenImage> {
        token.icon(withSize: .s750)
    }

    init(token: TokenObject) {
        self.token = token
    }

    var backgroundColor: UIColor {
        return Colors.appBackground
    }

    var contentsBackgroundColor: UIColor {
        return Colors.appWhite
    }

    var contentsCornerRadius: CGFloat {
        return Metrics.CornerRadius.nftBox
    }
}
