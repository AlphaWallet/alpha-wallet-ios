// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit

struct TokenInstanceAction {
    enum ActionType {
        case erc875Redeem
        case erc875Sell
        case nonFungibleTransfer
        case tokenScript(title: String, viewHtml: String)
    }
    var name: String {
        switch type {
        case .erc875Redeem:
            return R.string.localizable.aWalletTokenRedeemButtonTitle()
        case .erc875Sell:
            return R.string.localizable.aWalletTokenSellButtonTitle()
        case .nonFungibleTransfer:
            return R.string.localizable.aWalletTokenTransferButtonTitle()
        case .tokenScript(let title, _):
            return title
        }
    }
    //TODO storing this means we can't live-reload the action view screen
    let viewHtml: String
    let type: ActionType

    init(type: ActionType) {
        self.type = type
        switch type {
        case .erc875Redeem:
            self.viewHtml = ""
        case .erc875Sell:
            self.viewHtml = ""
        case .nonFungibleTransfer:
            self.viewHtml = ""
        case .tokenScript(let title, let viewHtml):
            self.viewHtml = wrapWithHtmlViewport(viewHtml)
        }
    }
}
