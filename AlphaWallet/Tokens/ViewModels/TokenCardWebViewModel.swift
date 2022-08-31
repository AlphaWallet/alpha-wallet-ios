//
//  TokenCardWebViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 12.05.2022.
//

import UIKit
import AlphaWalletFoundation

struct TokenCardWebViewModel {
    let tokenHolder: TokenHolder
    let tokenId: TokenId
    let tokenView: TokenView
    let assetDefinitionStore: AssetDefinitionStore
    var contentsBackgroundColor: UIColor = Colors.appWhite

    var tokenScriptHtml: (html: String, hash: Int) {
        let xmlHandler = XMLHandler(contract: tokenHolder.contractAddress, tokenType: tokenHolder.tokenType, assetDefinitionStore: assetDefinitionStore)
        let html: String
        let style: String
        switch tokenView {
        case .view:
            (html, style) = xmlHandler.tokenViewHtml
        case .viewIconified:
            (html, style) = xmlHandler.tokenViewIconifiedHtml
        }
        let hash = html.hashForCachingHeight
        return (html: wrapWithHtmlViewport(html: html, style: style, forTokenHolder: tokenHolder), hash: hash)
    }

    var hasTokenScriptHtml: Bool {
        //TODO improve performance? Because it is generated again when used
        return !tokenScriptHtml.html.isEmpty
    }
}
