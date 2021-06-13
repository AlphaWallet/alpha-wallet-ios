// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit

class OpenSeaNonFungibleTokenViewCellViewModel {
    private let token: TokenObject
    var imageUrl: URL?
    var title: String {
        return token.name
    }

    init(config: Config, token: TokenObject, forWallet account: Wallet, assetDefinitionStore: AssetDefinitionStore, eventsDataStore: EventsDataStoreProtocol) {
        self.token = token
        //We use the contract's image and fallback to the first token ID's image if the former is not available
        if let tokenHolder = TokenAdaptor(token: token, assetDefinitionStore: assetDefinitionStore, eventsDataStore: eventsDataStore).getTokenHolders(forWallet: account).first {
            var url = tokenHolder.values["contractImageUrl"]?.stringValue ?? ""
            if url.isEmpty {
                url = tokenHolder.values["imageUrl"]?.stringValue ?? ""
            }
            self.imageUrl = URL(string: url)
        } else {
            self.imageUrl = nil
        }
    }

    var backgroundColor: UIColor {
        return GroupedTable.Color.background
    }

    var contentsBackgroundColor: UIColor {
        return Colors.appWhite
    }

    var contentsCornerRadius: CGFloat {
        return Metrics.CornerRadius.box
    }

    var titleColor: UIColor {
        return Colors.appText
    }

    var titleFont: UIFont {
        return Fonts.semibold(size: 10)
    }
}
