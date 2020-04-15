// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit

struct TokenInstanceAction {
    enum ActionType {
        case erc20Send
        case erc20Receive
        case nftRedeem
        case nftSell
        case nonFungibleTransfer
        case tokenScript(contract: AlphaWallet.Address, title: String, viewHtml: (html: String, style: String), attributes: [AttributeId: AssetAttribute], transactionFunction: FunctionOrigin?)
    }
    var name: String {
        switch type {
        case .erc20Send:
            return R.string.localizable.send()
        case .erc20Receive:
            return R.string.localizable.receive()
        case .nftRedeem:
            return R.string.localizable.aWalletTokenRedeemButtonTitle()
        case .nftSell:
            return R.string.localizable.aWalletTokenSellButtonTitle()
        case .nonFungibleTransfer:
            return R.string.localizable.aWalletTokenTransferButtonTitle()
        case .tokenScript(_, let title, _, _, _):
            return title
        }
    }
    var attributes: [AttributeId: AssetAttribute] {
        switch type {
        case .erc20Send, .erc20Receive:
            return .init()
        case .nftRedeem, .nftSell, .nonFungibleTransfer:
            return .init()
        case .tokenScript(_, _, _, let attributes, _):
            return attributes
        }
    }
    var transactionFunction: FunctionOrigin? {
        switch type {
        case .erc20Send, .erc20Receive:
            return nil
        case .nftRedeem, .nftSell, .nonFungibleTransfer:
            return nil
        case .tokenScript(_, _, _, _, let transactionFunction):
            return transactionFunction
        }
    }
    var contract: AlphaWallet.Address? {
        switch type {
        case .erc20Send, .erc20Receive:
            return nil
        case .nftRedeem, .nftSell, .nonFungibleTransfer:
            return nil
        case .tokenScript(let contract, _, _, _, _):
            return contract
        }
    }
    var hasTransactionFunction: Bool {
        return transactionFunction != nil
    }
    let type: ActionType

    //TODO we can live-reload the action view screen now if we observe for changes
    func viewHtml(forTokenHolder tokenHolder: TokenHolder) -> (html: String, hash: Int) {
        switch type {
        case .erc20Send, .erc20Receive:
            return (html: "", hash: 0)
        case .nftRedeem:
            return (html: "", hash: 0)
        case .nftSell:
            return (html: "", hash: 0)
        case .nonFungibleTransfer:
            return (html: "", hash: 0)
        case .tokenScript(_, _, (html: let html, style: let style) , _, _):
            //Just an easy way to generate a hash for style + HTML
            let hash = "\(style)\(html)".hashForCachingHeight
            return (html: wrapWithHtmlViewport(html: html, style: style, forTokenHolder: tokenHolder), hash: hash)
        }
    }
}
