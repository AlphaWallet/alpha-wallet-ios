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

    var issuer: String {
        let xmlHandler = XMLHandler(contract: tokenObject.contractAddress, assetDefinitionStore: assetDefinitionStore)
        let issuer = xmlHandler.issuer
        if issuer.isEmpty {
            return ""
        } else {
            return "\(R.string.localizable.aWalletContentsIssuerTitle()): \(issuer)"
        }
    }

    var issuerSeparator: String {
        if issuer.isEmpty {
            return ""
        } else {
            return "|"
        }
    }

    var blockChainNameFont: UIFont {
        return Fonts.semibold(size: 12)!
    }

    var blockChainNameColor: UIColor {
        return Colors.appWhite
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
        return Colors.appWhite
    }

    var contentsBackgroundColor: UIColor {
        return Colors.appWhite
    }

    var titleColor: UIColor {
        return Colors.appText
    }

    var subtitleColor: UIColor {
        return Colors.appBackground
    }

    var titleFont: UIFont {
        return Fonts.light(size: 25)!
    }

    var subtitleFont: UIFont {
        return Fonts.semibold(size: 10)!
    }

    var totalValidTokenCount: String {
        let validTokens = tokenObject.nonZeroBalance
        return validTokens.count.toString()
    }
}
