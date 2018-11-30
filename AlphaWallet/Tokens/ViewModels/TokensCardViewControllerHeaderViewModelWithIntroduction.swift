// Copyright © 2018 Stormbird PTE. LTD.

import UIKit
import BigInt

struct TokensCardViewControllerHeaderViewModelWithIntroduction {
    private let tokenObject: TokenObject

    init(tokenObject: TokenObject) {
        self.tokenObject = tokenObject
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

    var blockChainName: String {
        return R.string.localizable.blockchainEthereum()
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

    var tbmlIntroductionHtmlString: String {
        let xmlHandler = XMLHandler(contract: tokenObject.contract)
        return wrapWithHtmlViewport(xmlHandler.introductionHtmlString)
    }

    private func wrapWithHtmlViewport(_ html: String) -> String {
        if html.isEmpty {
            return ""
        } else {
            return """
                   <html>
                   <head>
                   <meta name="viewport" content="width=device-width, initial-scale=1, shrink-to-fit=no">
                   </head>
                   \(html)
                   </html>
                   """
        }
    }
}
