// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit

struct TokenInstanceAction {
    enum ActionType {
        case erc20Send
        case erc20Receive
        case erc875Redeem
        case erc875Sell
        case nonFungibleTransfer
        case tokenScript(contract: AlphaWallet.Address, title: String, viewHtml: String, attributes: [String: AssetAttribute], transactionFunction: FunctionOrigin?)
    }
    var name: String {
        switch type {
        case .erc20Send:
            return R.string.localizable.send()
        case .erc20Receive:
            return R.string.localizable.receive()
        case .erc875Redeem:
            return R.string.localizable.aWalletTokenRedeemButtonTitle()
        case .erc875Sell:
            return R.string.localizable.aWalletTokenSellButtonTitle()
        case .nonFungibleTransfer:
            return R.string.localizable.aWalletTokenTransferButtonTitle()
        case .tokenScript(_, let title, _, _, _):
            return title
        }
    }
    var attributes: [String: AssetAttribute] {
        switch type {
        case .erc20Send, .erc20Receive:
            return .init()
        case .erc875Redeem, .erc875Sell, .nonFungibleTransfer:
            return .init()
        case .tokenScript(_, _, _, let attributes, _):
            return attributes
        }
    }
    var transactionFunction: FunctionOrigin? {
        switch type {
        case .erc20Send, .erc20Receive:
            return nil
        case .erc875Redeem, .erc875Sell, .nonFungibleTransfer:
            return nil
        case .tokenScript(_, _, _, _, let transactionFunction):
            return transactionFunction
        }
    }
    var contract: AlphaWallet.Address? {
        switch type {
        case .erc20Send, .erc20Receive:
            return nil
        case .erc875Redeem, .erc875Sell, .nonFungibleTransfer:
            return nil
        case .tokenScript(let contract, _, _, _, _):
            return contract
        }
    }
    var hasTransactionFunction: Bool {
        return transactionFunction != nil
    }
    //TODO storing this means we can't live-reload the action view screen
    let viewHtml: String
    let type: ActionType

    init(type: ActionType) {
        self.type = type
        switch type {
        case .erc20Send, .erc20Receive:
            self.viewHtml = ""
        case .erc875Redeem:
            self.viewHtml = ""
        case .erc875Sell:
            self.viewHtml = ""
        case .nonFungibleTransfer:
            self.viewHtml = ""
        case .tokenScript(_, _, let viewHtml, _, _):
            self.viewHtml = wrapWithHtmlViewport(viewHtml)
        }
    }
}
