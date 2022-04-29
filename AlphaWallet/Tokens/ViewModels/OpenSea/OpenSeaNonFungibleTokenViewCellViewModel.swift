// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit

class OpenSeaNonFungibleTokenViewCellViewModel {
    private let token: TokenObject
    private let assetDefinitionStore: AssetDefinitionStore
    private let eventsDataStore: NonActivityEventsDataStore
    private let wallet: Wallet

    private var title: String {
        if let name = token.titleInPluralForm(withAssetDefinitionStore: assetDefinitionStore, eventsDataStore: eventsDataStore, forWallet: wallet) {
            return name
        } else {
            return token.titleInPluralForm(withAssetDefinitionStore: assetDefinitionStore)
        }
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

    init(token: TokenObject, assetDefinitionStore: AssetDefinitionStore, eventsDataStore: NonActivityEventsDataStore, wallet: Wallet) {
        self.token = token
        self.assetDefinitionStore = assetDefinitionStore
        self.eventsDataStore = eventsDataStore
        self.wallet = wallet
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
