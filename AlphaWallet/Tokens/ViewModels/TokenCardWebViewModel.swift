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

    var tokenScriptHtml: String {
        let xmlHandler = XMLHandler(contract: tokenHolder.contractAddress, tokenType: tokenHolder.tokenType, assetDefinitionStore: assetDefinitionStore)
        let html: String
        let style: String
        switch tokenView {
        case .view:
            (html, style) = xmlHandler.tokenViewHtml
        case .viewIconified:
            (html, style) = xmlHandler.tokenViewIconifiedHtml
        }

        return wrapWithHtmlViewport(html: html, style: style, forTokenId: tokenId)
    }

    var hasTokenScriptHtml: Bool {
        //TODO improve performance? Because it is generated again when used
        return !tokenScriptHtml.isEmpty
    }
}
