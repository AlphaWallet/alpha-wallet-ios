// Copyright © 2018 Stormbird PTE. LTD.

import UIKit
import BigInt

struct TokensCardViewControllerHeaderViewModel {
    private let tokenObject: TokenObject
    private let server: RPCServer
    private let assetDefinitionStore: AssetDefinitionStore

    init(tokenObject: TokenObject, server: RPCServer, assetDefinitionStore: AssetDefinitionStore) {
        self.tokenObject = tokenObject
        self.server = server
        self.assetDefinitionStore = assetDefinitionStore
    }

    var title: String {
        return "\((totalValidTokenCount)) \(tokenObject.titleInPluralForm(withAssetDefinitionStore: assetDefinitionStore))"
    }

    var blockChainNameFont: UIFont {
        return Screen.TokenCard.Font.blockChainName
    }

    var blockChainNameColor: UIColor {
        return Screen.TokenCard.Color.blockChainName
    }

    var blockChainNameBackgroundColor: UIColor {
        return server.blockChainNameColor
    }

    var blockChainTag: String {
        return "  \(server.name)     "
    }

    var blockChainNameTextAlignment: NSTextAlignment {
        return .center
    }

    var blockChainName: String {
        return server.blockChainName
    }

    var backgroundColor: UIColor {
        return Screen.TokenCard.Color.background
    }

    var contentsBackgroundColor: UIColor {
        return Screen.TokenCard.Color.background
    }

    var titleColor: UIColor {
        return Screen.TokenCard.Color.title
    }

    var subtitleColor: UIColor {
        return Screen.TokenCard.Color.subtitle
    }

    var titleFont: UIFont {
        return Screen.TokenCard.Font.title
    }

    var subtitleFont: UIFont {
        return Screen.TokenCard.Font.subtitle
    }

    var totalValidTokenCount: String {
        let validTokens = tokenObject.nonZeroBalance
        return validTokens.count.toString()
    }
}
