//
//  TokenCardWebViewModel.swift
//  AlphaWallet
//
//  Created by Vladyslav Shepitko on 12.05.2022.
//

import UIKit
import AlphaWalletFoundation
import AlphaWalletTokenScript

struct TokenCardWebViewModel {
    let tokenHolder: TokenHolder
    let tokenId: TokenId
    let tokenView: TokenView
    let assetDefinitionStore: AssetDefinitionStore
    var contentsBackgroundColor: UIColor = Configuration.Color.Semantic.defaultViewBackground

    var tokenScriptHtml: (html: String, urlFragment: String?) {
        let xmlHandler = assetDefinitionStore.xmlHandler(forContract: tokenHolder.contractAddress, tokenType: tokenHolder.tokenType)
        let html: String
        let urlFragment: String?
        let style: String
        switch tokenView {
        case .view:
            (html, urlFragment, style) = xmlHandler.tokenViewHtml
        case .viewIconified:
            (html, urlFragment, style) = xmlHandler.tokenViewIconifiedHtml
        }

        return (html: wrapWithHtmlViewport(html: html, style: style, forTokenId: tokenId), urlFragment: urlFragment)
    }

    var hasTokenScriptHtml: Bool {
        //TODO improve performance? Because it is generated again when used
        return !tokenScriptHtml.html.isEmpty
    }
}
