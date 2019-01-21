// Copyright © 2018 Stormbird PTE. LTD.

import Foundation
import UIKit

struct EnterSellTokensCardPriceQuantityViewControllerViewModel {
    let token: TokenObject
    let tokenHolder: TokenHolder
    let server: RPCServer
    var ethCost: Ether = .zero
    var dollarCost: String = ""

    var headerTitle: String {
		return R.string.localizable.aWalletTokenSellSelectQuantityTitle()
    }

    var maxValue: Int {
        return tokenHolder.tokens.count
    }

    var backgroundColor: UIColor {
        return Colors.appBackground
    }

    var buttonTitleColor: UIColor {
        return Colors.appWhite
    }

    var buttonBackgroundColor: UIColor {
        return Colors.appHighlightGreen
    }

    var buttonFont: UIFont {
        return Fonts.regular(size: 20)!
    }

    var choiceLabelColor: UIColor {
        return Colors.appGrayLabelColor
    }

    var choiceLabelFont: UIFont {
        return Fonts.regular(size: 10)!
    }

    var stepperBorderColor: UIColor {
        return Colors.appBackground
    }

    var quantityLabelText: String {
        let tokenTypeName = XMLHandler(contract: token.address.eip55String).getTokenTypeName()
		return R.string.localizable.aWalletTokenSellQuantityTitle(tokenTypeName.localizedUppercase)
    }

    var pricePerTokenLabelText: String {
        let tokenTypeName = XMLHandler(contract: token.address.eip55String).getTokenTypeName(.singular)
        return R.string.localizable.aWalletTokenSellPricePerTokenTitle(tokenTypeName.localizedUppercase)
    }

    var linkExpiryDateLabelText: String {
        return R.string.localizable.aWalletTokenSellLinkExpiryDateTitle()
    }

    var linkExpiryTimeLabelText: String {
        return R.string.localizable.aWalletTokenSellLinkExpiryTimeTitle()
    }

    var ethCostLabelLabelText: String {
        return R.string.localizable.aWalletTokenSellTotalCostTitle()
    }

    var ethCostLabelLabelFont: UIFont {
        return Fonts.light(size: 21)!
    }

    var ethCostLabelLabelColor: UIColor {
        return Colors.appText
    }

    var ethCostLabelText: String {
        return "\(ethCost.formattedDescription) \(server.symbol)"
    }

    var ethCostLabelColor: UIColor {
        return Colors.appBackground
    }

    var ethCostLabelFont: UIFont {
        return Fonts.semibold(size: 21)!
    }

    var dollarCostLabelLabelColor: UIColor {
        return Colors.appGrayLabelColor
    }

    var dollarCostLabelLabelFont: UIFont {
        return Fonts.regular(size: 10)!
    }

    var dollarCostLabelText: String {
        return "$\(dollarCost)"
    }

    var dollarCostLabelColor: UIColor {
        return Colors.darkGray
    }

    var dollarCostLabelFont: UIFont {
        return Fonts.light(size: 21)!
    }

    var dollarCostLabelBackgroundColor: UIColor {
        return UIColor(red: 236, green: 236, blue: 236)
    }

    var hideDollarCost: Bool {
        return dollarCost.trimmed.isEmpty
    }

    init(token: TokenObject, tokenHolder: TokenHolder, server: RPCServer) {
        self.token = token
        self.tokenHolder = tokenHolder
        self.server = server
    }

    var actionButtonCornerRadius: CGFloat {
        return 16
    }

    var actionButtonShadowColor: UIColor {
        return .black
    }

    var actionButtonShadowOffset: CGSize {
        return .init(width: 1, height: 2)
    }

    var actionButtonShadowOpacity: Float {
        return 0.3
    }

    var actionButtonShadowRadius: CGFloat {
        return 5
    }
}
