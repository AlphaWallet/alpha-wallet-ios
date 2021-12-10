// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit

class OpenSeaNonFungibleTokenViewCellViewModel {
    private let token: TokenObject
    var imageUrl: URL?
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

    init(config: Config, token: TokenObject, forWallet account: Wallet, assetDefinitionStore: AssetDefinitionStore, eventsDataStore: EventsDataStoreProtocol) {
        self.token = token
        //We use the contract's image and fallback to the first token ID's image if the former is not available
        if let tokenHolder = TokenAdaptor(token: token, assetDefinitionStore: assetDefinitionStore, eventsDataStore: eventsDataStore).getTokenHolders(forWallet: account).first {
            let url = tokenHolder.values.contractImageUrlStringValue ?? ""
            if url.isEmpty {
                self.imageUrl = tokenHolder.values.imageUrlUrlValue
            } else {
                self.imageUrl = URL(string: url)
            }
        } else {
            self.imageUrl = nil
        }
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
