// Copyright © 2018 Stormbird PTE. LTD.

import UIKit
import BigInt

struct TokensCardViewControllerHeaderViewModel {
    private let tokenObject: TokenObject
    private let server: RPCServer

    init(tokenObject: TokenObject, server: RPCServer) {
        self.tokenObject = tokenObject
        self.server = server
    }

    var title: String {
        return "\((totalValidTokenCount)) \(tokenObject.title)"
    }

    var issuer: String {
        let xmlHandler = XMLHandler(contract: tokenObject.address.eip55String)
        let issuer = xmlHandler.getIssuer()
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
